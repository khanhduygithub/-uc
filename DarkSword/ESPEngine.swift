import Foundation
import Darwin

/// ESP Free Fire engine — DarkSword remake of the CrackTeam TrollStore HUD.
///
/// Pipeline (all steps reported green/red in the UI):
///   1. Kernel R/W        — "Start Darksword" must have succeeded
///   2. Root elevation    — kernel ucred copy (best effort, like TrollStore)
///   3. Game discovery    — sysctl scan for "FreeFire" (same as TrollStore)
///   4. Task-port bridge  — kernel port transplant replaces task_for_pid
///   5. Overlay window    — ESP UIWindow in this process (level 10000010)
///   6. SpringBoard host  — remote registerWindowWithContextID:atLevel:
///   7. Tick loop         — 60 Hz frame driver + audio keep-alive
///
/// Settings are persisted through the same ESPPrefs (NSUserDefaults) keys the
/// original CrackTeam build used, so every toggle lands live via
/// ESPSyncFromPrefs() without touching the C drawing code.
@MainActor
final class ESPEngine: ObservableObject {

    // MARK: - Nested types

    struct StatusSnapshot: Equatable {
        var kernelReady = false
        var rootElevated = false
        var gameFound = false
        var gameProcessAlive = false
        var portReady = false
        var overlayWindow = false
        var sbRegistered = false
        var tickLoop = false
        var keepAlive = false
        var gameRunning = false

        var pid: Int32 = -1
        var gameTaskKaddr: UInt64 = 0
        var contextID: UInt32 = 0
        var frameCount: UInt32 = 0
        var enemyCount: UInt32 = 0
    }

    // MARK: - Published state

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var status = StatusSnapshot()
    @Published private(set) var lastMessage: String = "Sẵn sàng — bấm Bật ESP sau khi đã Start Darksword và mở Free Fire"
    @Published private(set) var busy = false
    @Published var config = ESPConfig()

    enum Phase: Equatable {
        case idle
        case starting
        case running
        case stopping
        case failed(String)
    }

    var isRunning: Bool { phase == .running }

    // MARK: - Internals

    private let queue = DispatchQueue(label: "com.darksword.esp", qos: .userInitiated)
    private var refreshTimer: DispatchSourceTimer?
    private var healAttempts = 0

    // MARK: - Start / Stop

    func startESP() {
        guard !busy else { return }
        busy = true
        phase = .starting
        log("esp: ===== BẬT ESP FREE FIRE =====")

        queue.async { [weak self] in
            guard let self else { return }

            // 1. kernel bridge (includes root elevate + game find + transplant)
            let kr = esp_krw_init()
            guard kr == 0 else {
                let message = self.describeKrwFailure(kr)
                Task { @MainActor [weak self] in
                    self?.finishStart(ok: false, message: message)
                }
                return
            }

            // 2. overlay + registration through the shared SpringBoard session
            if let sessionFailure = DarkswordMechanism.acquireSessionForESP() {
                Task { @MainActor [weak self] in
                    self?.finishStart(ok: false, message: sessionFailure)
                }
                return
            }
            defer { DarkswordMechanism.releaseSessionForESP() }

            let rc = esp_host_start(true)
            guard rc == 0 else {
                Task { @MainActor [weak self] in
                    self?.finishStart(ok: false, message: "esp_host_start thất bại (\(rc)) — xem log [ESPHOST]")
                }
                return
            }

            Task { @MainActor [weak self] in
                self?.finishStart(ok: true, message: "ESP đang chạy — quay lại game, khung ESP sẽ đè lên màn hình")
            }
        }
    }

    func stopESP() {
        guard !busy else { return }
        busy = true
        phase = .stopping

        queue.async { [weak self] in
            guard let self else { return }
            esp_host_stop()
            Task { @MainActor [weak self] in
                self?.stopRefresh()
            }
            DispatchQueue.main.async {
                self.busy = false
                self.phase = .idle
                self.status = StatusSnapshot()
                self.lastMessage = "ESP đã dừng"
                log("esp: ===== ESP ĐÃ DỪNG =====")
            }
        }
    }

    private func finishStart(ok: Bool, message: String) {
        DispatchQueue.main.async {
            self.busy = false
            if ok {
                self.phase = .running
                self.startRefresh()
            } else {
                self.phase = .failed(message)
                esp_host_stop()
            }
            self.lastMessage = message
        }
    }

    /// Pure formatter — safe to call from any queue (marked nonisolated so the
    /// background start pipeline can build the failure message before hopping
    /// to the main actor).
    private nonisolated func describeKrwFailure(_ code: Int32) -> String {
        switch code {
        case -1: return "kernel R/W chưa hoạt động — bấm Start Darksword ở tab Darksword trước"
        case -3: return "không thấy tiến trình FreeFire — hãy mở game rồi bật ESP lại"
        case -2, -4, -5: return "không đọc được proc/task của game qua kernel (\(code))"
        case -6: return "port transplant thất bại (\(code)) — xem log [ESPKRW]"
        default: return "esp_krw_init lỗi \(code)"
        }
    }

    // MARK: - Status refresh + auto-heal (2 s)

    /// Read-only pipeline probe — collects a StatusSnapshot without touching
    /// the start pipeline. Only userspace-safe sources: global flags, getuid,
    /// sysctl process scan and esphost atomic reads. The kernel-fallback game
    /// probe is used only when kernel R/W is already up (same precondition
    /// esp_krw_init enforces); otherwise the sysctl-only variant is used, so
    /// this is safe even before Start Darksword ever ran.
    nonisolated private func collectStatusSnapshot() -> StatusSnapshot {
        var st = ESPHostStatus()
        esp_host_get_status(&st)
        let kernelUp = kexploit_krw_ready() || krw_persistence_is_recovered()
        let gameAlive = kernelUp ? esp_krw_game_process_exists()
                                 : esp_krw_game_process_exists_sysctl()
        return StatusSnapshot(
            kernelReady: kernelUp,
            rootElevated: getuid() == 0,
            gameFound: esp_krw_game_pid() > 0,
            gameProcessAlive: gameAlive,
            portReady: esp_krw_ready(),
            overlayWindow: st.overlayWindow,
            sbRegistered: st.sbRegistered,
            tickLoop: st.tickLoop,
            keepAlive: st.keepAlive,
            gameRunning: st.gameRunning,
            pid: esp_krw_game_pid(),
            gameTaskKaddr: esp_krw_game_task_kaddr(),
            contextID: st.registeredContextID,
            frameCount: st.frameCount,
            enemyCount: st.lastEnemyCount
        )
    }

    /// One-shot status refresh for the ESP tab appearance: paints the real
    /// kernel-pipeline state (green/red rows) the moment the tab opens —
    /// BEFORE the user presses Bật ESP. Previously the rows stayed on their
    /// all-red initial snapshot until the 2 s timer started after a successful
    /// start, which made the panel look like the kernel had been reset.
    /// No side effects: never starts, heals, writes or touches the kernel.
    func refreshStatusOnce() {
        queue.async { [weak self] in
            guard let self else { return }
            let snapshot = self.collectStatusSnapshot()
            DispatchQueue.main.async {
                self.status = snapshot
                if self.phase == .idle {
                    self.lastMessage = snapshot.kernelReady
                        ? "Kernel R/W đang hoạt động — bấm Bật ESP sau khi đã mở Free Fire"
                        : "Chưa có kernel R/W — bấm Start Darksword ở tab Darksword trước"
                }
            }
        }
    }

    private func startRefresh() {
        stopRefresh()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 2.0)
        timer.setEventHandler { [weak self] in
            guard let self else { return }

            // Auto-heal: game restarted -> rebuild the transplanted port.
            // The overlay window/registration survives, only the kernel
            // bridge needs a rebuild.
            if esp_host_active(), !esp_krw_ready(), esp_krw_game_process_exists() {
                self.healAttempts += 1
                log("esp: game mới phát hiện — dựng lại kernel bridge (lần \(self.healAttempts))…")
                if esp_krw_reinit() == 0 {
                    esphost_on_game_relaunched()
                }
            } else if esp_krw_ready() {
                self.healAttempts = 0
            }

            let snapshot = self.collectStatusSnapshot()
            DispatchQueue.main.async {
                self.status = snapshot
                if snapshot.sbRegistered && snapshot.portReady && self.phase == .running {
                    self.lastMessage = self.liveMessage(snapshot)
                }
            }
        }
        timer.resume()
        refreshTimer = timer
    }

    private func stopRefresh() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }

    private func liveMessage(_ s: StatusSnapshot) -> String {
        if !s.gameProcessAlive { return "ESP chờ game — FreeFire chưa chạy, overlay vẫn giữ" }
        if !s.portReady { return "ESP chờ game mới — đang dựng lại kernel bridge…" }
        return "ESP hoạt động — pid \(s.pid), \(s.enemyCount) địch, \(s.frameCount) frame"
    }

    // MARK: - Launch game

    func launchGame() {
        guard !busy else { return }
        busy = true
        queue.async { [weak self] in
            guard let self else { return }
            var message: String
            if let sessionFailure = DarkswordMechanism.acquireSessionForESP() {
                message = sessionFailure
            } else {
                defer { DarkswordMechanism.releaseSessionForESP() }
                let rc = esp_host_launch_game()
                message = rc == 0
                    ? "đã gửi lệnh mở Free Fire qua SpringBoard"
                    : "mở game thất bại (\(rc)) — SpringBoard không có đường dẫn phù hợp"
            }
            DispatchQueue.main.async {
                self.busy = false
                self.lastMessage = message
                log("esp: \(message)")
            }
        }
    }

    // MARK: - Settings sync (ESPPrefs keys = CrackTeam runtime keys)

    /// Pushes the whole config into ESPPrefs and reloads the C-side flags.
    func applyConfig() {
        let c = config
        queue.async {
            ESPPrefsSetBool("Box", c.box)
            ESPPrefsSetBool("Count", c.enemyCount)
            ESPPrefsSetBool("Name", c.name)
            ESPPrefsSetBool("Health", c.health)
            ESPPrefsSetBool("Dis", c.distance)
            ESPPrefsSetBool("Line", c.snapline)
            ESPPrefsSetBool("Bone", c.bone)
            ESPPrefsSetBool("EspBot", c.showBots)
            ESPPrefsSetBool("ShowFov", c.showFov)

            ESPPrefsSetBool("Aimbot", c.aimbot)
            ESPPrefsSetBool("AimIgnoreBot", c.aimIgnoreBots)
            ESPPrefsSetBool("AimIgnoreKnock", c.aimIgnoreKnocked)
            ESPPrefsSetBool("AimCheckVisible", c.aimCheckVisible)
            ESPPrefsSetBool("AimRage", c.aimRage)
            ESPPrefsSetFloat("Fov", Float(c.aimFov))
            ESPPrefsSetFloat("Distance", Float(c.aimDistance))
            ESPPrefsSetFloat("AimSpeed", Float(c.aimSpeed * 100.0))
            ESPPrefsSetFloat("TriggerMode", Float(c.triggerMode.rawValue))
            ESPPrefsSetFloat("AimPos", Float(c.aimPosition.rawValue))
            ESPPrefsSetFloat("AimTargetMode", Float(c.aimTargetMode.rawValue))

            ESPPrefsSetBool("camcao", c.highCamera)
            ESPPrefsSetFloat("Campc", Float(c.highCameraValue))

            ESPPrefsSync()
            esphost_reload_esp_prefs()
        }
    }
}

// MARK: - Config

/// Mirrors the CrackTeam ESPPrefs keys (NSUserDefaults).
struct ESPConfig: Equatable {
    // Visual ESP
    var box = true
    var enemyCount = true
    var name = true
    var health = true
    var distance = true
    var snapline = false
    var bone = false
    var showBots = false
    var showFov = true

    // Aimbot
    var aimbot = false
    var aimIgnoreBots = false
    var aimIgnoreKnocked = false
    var aimCheckVisible = false
    var aimRage = false
    var aimFov: Double = 150
    var aimDistance: Double = 200
    var aimSpeed: Double = 1.0        // 0.01…1.0
    var triggerMode: TriggerMode = .always
    var aimPosition: AimPosition = .head
    var aimTargetMode: TargetMode = .fovDistance

    // Camera
    var highCamera = false
    var highCameraValue: Double = 1.0 // 1…100

    enum TriggerMode: Int, CaseIterable, Identifiable {
        case always = 0, whenFiring = 1, whenScoping = 2, firingOrScoping = 3
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .always: return "Luôn bật"
            case .whenFiring: return "Khi bắn"
            case .whenScoping: return "Khi ngắm"
            case .firingOrScoping: return "Bắn hoặc ngắm"
            }
        }
    }

    enum AimPosition: Int, CaseIterable, Identifiable {
        case head = 0, neck = 1, chest = 2
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .head: return "Đầu"
            case .neck: return "Cổ"
            case .chest: return "Ngực"
            }
        }
    }

    enum TargetMode: Int, CaseIterable, Identifiable {
        case fovDistance = 0, healthFirst = 1, distanceFirst = 2
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .fovDistance: return "FOV + khoảng cách"
            case .healthFirst: return "Máu thấp trước"
            case .distanceFirst: return "Gần nhất"
            }
        }
    }
}
