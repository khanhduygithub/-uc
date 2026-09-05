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

    /// Shared engine: AppState chains it right after "Start Darksword" and
    /// the ESP tab observes the same instance — one pipeline for the app.
    static let shared = ESPEngine()

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
    @Published private(set) var lastMessage: String = "Sẵn sàng — ESP tự khởi chạy khi Start Darksword thành công, hãy mở Free Fire để ESP ghim mục tiêu"
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

    /// Auto-start bookkeeping (touched on `queue` / main thread).
    private var autoStartPending = false
    private var autoStartAttempts = 0
    private var autoStartDeadline = Date.distantFuture
    /// Bumped on every autoStartAfterKernel(); in-flight attempt chains with
    /// an older generation exit silently (prevents double pipelines when the
    /// user presses Start Darksword again).
    private var autoStartGeneration = 0
    /// How long auto-start keeps waiting for Free Fire before giving up.
    private static let autoStartWaitLimit: TimeInterval = 180
    /// Bounded retries for kernel-bridge failures — never an infinite loop:
    /// every retry touches the kernel, and a dead primitive must stay dead
    /// (panic safety).
    private static let autoStartMaxAttempts = 5

    // MARK: - Auto start (one-button flow)

    /// "Start Darksword" is the ONLY button. AppState calls this right after
    /// the kernel exploit succeeds; the ESP pipeline then runs by itself:
    /// it waits for Free Fire to appear (the user may open the game later),
    /// builds the kernel bridge, the overlay and the SpringBoard registration
    /// with no further press. There is no separate Bật ESP button anymore —
    /// the ESP tab is status-only (xanh/đỏ).
    func autoStartAfterKernel() {
        applyConfig()
        autoStartPending = true
        autoStartAttempts = 0
        autoStartGeneration += 1
        autoStartDeadline = Date().addingTimeInterval(Self.autoStartWaitLimit)
        busy = true
        phase = .starting
        log("esp: ===== TỰ ĐỘNG KHỞI CHẠY ESP (sau Start Darksword) =====")
        lastMessage = "ESP tự khởi chạy — đang chờ Free Fire…"
        attemptAutoStart(delay: 1.0, generation: autoStartGeneration)
    }

    private func attemptAutoStart(delay: TimeInterval, generation: Int) {
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            // A newer Start Darksword run owns the pipeline now — step aside.
            guard self.autoStartPending, self.autoStartGeneration == generation else { return }

            guard Date() < self.autoStartDeadline else {
                self.autoStartPending = false
                Task { @MainActor [weak self] in
                    self?.finishStart(ok: false, message:
                        "hết thời gian chờ Free Fire (\(Int(Self.autoStartWaitLimit))s) — mở game rồi bấm Start Darksword để chạy lại toàn bộ luồng")
                }
                return
            }

            // Free Fire must exist BEFORE the kernel bridge is built so the
            // port transplant targets a stable process. Sysctl-only probe —
            // safe in every state, never touches the kernel.
            if !esp_krw_game_process_exists_sysctl() {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.phase = .starting
                    self.lastMessage = "ESP sẵn sàng — đang chờ Free Fire khởi động…"
                }
                self.attemptAutoStart(delay: 2.0, generation: generation)
                return
            }

            let kr = esp_krw_init()
            guard kr == 0 else {
                if kr == -3 {
                    // game vanished between the probe and the bridge build —
                    // go back to waiting instead of failing
                    self.attemptAutoStart(delay: 2.0, generation: generation)
                    return
                }
                self.autoStartAttempts += 1
                if self.autoStartAttempts < Self.autoStartMaxAttempts {
                    log("esp: dựng kernel bridge chưa xong (esp_krw_init=\(kr)) — thử lại sau 3 s (lần \(self.autoStartAttempts)/\(Self.autoStartMaxAttempts))")
                    self.attemptAutoStart(delay: 3.0, generation: generation)
                    return
                }
                self.autoStartPending = false
                let message = self.describeKrwFailure(kr)
                Task { @MainActor [weak self] in
                    self?.finishStart(ok: false, message: message)
                }
                return
            }

            // 2. overlay + registration through the shared SpringBoard session.
            // Bounded retry: a transient bootstrap failure (e.g. a thread that
            // needed a beat after the hijack dance) must not kill the whole
            // one-button chain — but never loop forever against the kernel.
            var sessionFailure = DarkswordMechanism.acquireSessionForESP()
            if sessionFailure != nil {
                for attempt in 2...3 {
                    log("esp: \(sessionFailure!) — thử mở lại session sau 2 s (lần \(attempt)/3)…")
                    Thread.sleep(forTimeInterval: 2.0)
                    sessionFailure = DarkswordMechanism.acquireSessionForESP()
                    if sessionFailure == nil { break }
                }
            }
            if let failure = sessionFailure {
                self.autoStartPending = false
                Task { @MainActor [weak self] in
                    self?.finishStart(ok: false, message: failure)
                }
                return
            }
            defer { DarkswordMechanism.releaseSessionForESP() }

            let rc = esp_host_start(true)
            guard rc == 0 else {
                self.autoStartPending = false
                Task { @MainActor [weak self] in
                    self?.finishStart(ok: false, message: "esp_host_start thất bại (\(rc)) — xem log [ESPHOST]")
                }
                return
            }

            self.autoStartPending = false
            Task { @MainActor [weak self] in
                self?.finishStart(ok: true, message: "ESP đang chạy — quay lại game, khung ESP sẽ đè lên màn hình")
            }
        }
    }

    func stopESP() {
        guard !busy else { return }
        autoStartPending = false
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
                self.lastMessage = "ESP đã dừng — bấm Start Darksword để chạy lại toàn bộ luồng"
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
        case -1: return "kernel R/W chưa hoạt động — Start Darksword phải thành công trước (khởi động lại app rồi chạy lại nếu vừa thất bại)"
        case -3: return "không thấy tiến trình FreeFire — hãy mở game, ESP tự ghim khi game xuất hiện"
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
                        ? "Kernel R/W hoạt động — ESP tự khởi chạy, mở Free Fire nếu chưa mở"
                        : "Chưa có kernel R/W — bấm Start Darksword, ESP sẽ tự khởi chạy khi thành công"
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

    /// Launch Free Fire through SpringBoard. Runs alongside a pending
    /// auto-start on purpose — the waiting ESP pipeline picks the game up as
    /// soon as it appears (never touches `busy`, which belongs to the
    /// start/stop pipeline).
    func launchGame() {
        if busy && !autoStartPending { return }
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
