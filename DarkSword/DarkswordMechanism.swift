import Foundation

/// Swift facade for the Darksword mechanism ported from Cyanide 1.3.6.
///
/// Two execution contexts:
///  1. **SpringBoard RemoteCall session** — init_remote_call("SpringBoard")
///     injects a trojan thread into SpringBoard (requires kernel R/W first,
///     i.e. "Start Darksword" must have succeeded). Everything session-based
///     (darksword_tweaks / darksword_drag / darksword_layout / rssidisplay)
///     runs inside that session.
///  2. **Kernel-only** — darksword_ota rewrites launchd's disabled.plist via
///     launchd KRW persistence; no SpringBoard session needed, but kernel
///     primitives must be active.
///
/// Session lifecycle mirrors cyanide's long-lived session: normal tweaks
/// open+close the session around one apply; the RSSI dBm readout keeps the
/// session open and re-ticks every 2 s until stopped. All entry points are
/// serialized on one serial queue (cyanide's settings_rc_lock equivalent).
///
/// Every C-level step prints [DST]/[DRAG]/[RSSI]/[OTA] lines through printf,
/// which LogTextView.h tees into the ring buffer AND stdout; stdout is
/// captured by setupLogCapture() so all progress lands in the in-app log.
enum DarkswordMechanism {

    // MARK: - Configuration

    struct Config: Equatable {
        // Session tweaks (mirror cyanide's kSettingsDS* switches)
        var disableAppLibrary = false
        var disableIconFlyIn = false
        var zeroWakeAnimation = false
        var zeroBacklightFade = false
        var doubleTapToLock = false

        // Animation speed (_UIAnimationDragCoefficient; <1 faster, >1 slower)
        var dragEnabled = false
        var dragCoefficient: Double = 0.5          // cyanide default, 0.01…2.0

        // Home grid / dock layout extras (cyanide's layout extras)
        var layoutEnabled = false
        var homeExtraLeft: Double = 0
        var homeExtraRight: Double = 0
        var homeExtraTop: Double = 0
        var homeExtraBottom: Double = 0
        var dockExtraHorizontal: Double = 0
        var homeScale: Double = 0                  // 0 = leave alone; else (0, 2]
        var dockScale: Double = 0

        // Status-bar dBm readouts (live loop, driven separately)
        var rssiShowWifi = true
        var rssiShowCell = true

        var anySessionTweakEnabled: Bool {
            disableAppLibrary || disableIconFlyIn || zeroWakeAnimation ||
            zeroBacklightFade || doubleTapToLock || dragEnabled || layoutEnabled
        }
    }

    // MARK: - Result reporting

    struct Report {
        var kernelReady = false
        var sessionOpened = false
        var sessionFailure = ""                    // non-empty when open failed
        // Per-tweak results; nil = not requested
        var disableAppLibrary: Bool?
        var disableIconFlyIn: Bool?
        var zeroWakeAnimation: Bool?
        var zeroBacklightFade: Bool?
        var doubleTapToLock: Bool?
        var dragCoefficient: Bool?
        var layout: Bool?
        var ota: Bool?

        /// Aggregated summary line for the UI/log.
        var summary: String {
            var parts: [String] = []
            func add(_ label: String, _ v: Bool?) {
                if let v { parts.append("\(label)=\(v ? "OK" : "LỖI")") }
            }
            add("appLib", disableAppLibrary)
            add("flyIn", disableIconFlyIn)
            add("wake", zeroWakeAnimation)
            add("backlight", zeroBacklightFade)
            add("dblTap", doubleTapToLock)
            add("drag", dragCoefficient)
            add("layout", layout)
            add("ota", ota)
            return parts.isEmpty ? "không có cơ chế nào được bật" : parts.joined(separator: " ")
        }

        var allRequestedSucceeded: Bool {
            let results: [Bool?] = [disableAppLibrary, disableIconFlyIn,
                                    zeroWakeAnimation, zeroBacklightFade,
                                    doubleTapToLock, dragCoefficient,
                                    layout, ota]
            return results.allSatisfy { $0 != false }
        }
    }

    // MARK: - Serialization / session state (touched only on `queue`)

    private static let queue = DispatchQueue(label: "com.darksword.mechanism", qos: .userInitiated)
    private static var sessionOpen = false
    private static var sessionUsers = 0
    private static var rssiTimer: DispatchSourceTimer?

    // MARK: - Kernel state

    /// True after "Start Darksword" established kernel R/W (or launchd holds
    /// recovered KRW from an earlier run).
    static var kernelReady: Bool {
        kernelExploitReady()
    }

    static func kernelExploitReady() -> Bool {
        kexploit_krw_ready() || krw_persistence_is_recovered()
    }

    // MARK: - Session-based apply (SpringBoard)

    /// Opens the SpringBoard RemoteCall session (unless the RSSI loop already
    /// holds one), applies every enabled session tweak, closes the session
    /// when the RSSI loop is not keeping it alive. Blocking — runs on `queue`.
    static func applySessionTweaks(_ config: Config,
                                   _ completion: @escaping (Report) -> Void) {
        queue.async {
            var report = Report()
            report.kernelReady = kernelReady

            guard config.anySessionTweakEnabled else {
                log("mechanism: không có cơ chế session nào được bật — bỏ qua")
                completion(report)
                return
            }

            guard kernelReady else {
                log("mechanism: CHƯA có kernel R/W — hãy bấm Start Darksword trước khi áp dụng cơ chế")
                report.sessionFailure = "kernel R/W chưa hoạt động — chạy Start Darksword trước"
                completion(report)
                return
            }

            guard acquireSession(&report) else {
                completion(report)
                return
            }

            // Begin a persistent chain log (Documents/chain-*.log, visible in
            // Files app). All printf output from the tweaks is tee'd there.
            log_session_begin()
            defer { log_session_end() }

            // Order mirrors cyanide SettingsViewController.settings_apply_dark_tweaks…
            if config.disableAppLibrary {
                report.disableAppLibrary = darksword_tweak_disable_app_library_in_session()
            }
            if config.disableIconFlyIn {
                report.disableIconFlyIn = darksword_tweak_disable_icon_fly_in_in_session()
            }
            if config.zeroWakeAnimation {
                report.zeroWakeAnimation = darksword_tweak_zero_wake_animation_in_session()
            }
            if config.zeroBacklightFade {
                report.zeroBacklightFade = darksword_tweak_zero_backlight_fade_in_session()
            }
            if config.doubleTapToLock {
                report.doubleTapToLock = darksword_tweak_double_tap_to_lock_in_session()
            }
            if config.dragEnabled {
                let c = max(0.01, min(2.0, config.dragCoefficient))
                report.dragCoefficient = darksword_drag_coefficient_apply(c)
            }
            if config.layoutEnabled {
                report.layout = darksword_layout_apply_in_session(
                    config.homeExtraLeft,
                    config.homeExtraRight,
                    config.homeExtraTop,
                    config.homeExtraBottom,
                    config.dockExtraHorizontal,
                    config.homeScale,
                    config.dockScale
                )
            }

            let ok = report.allRequestedSucceeded
            log("mechanism: \(ok ? "HOÀN TẤT" : "HOÀN TẤT VỚI LỖI") — \(report.summary)")

            // Shared session: released for whoever still holds it (RSSI loop,
            // ESP overlay). Closed automatically when the last user leaves.
            releaseSession()
            completion(report)
        }
    }

    // MARK: - Live RSSI loop (session stays open, re-ticks every 2 s)

    /// Starts the RSSI loop: opens the session if needed, then re-applies the
    /// dBm labels every 2 s. `provider` is consulted on each tick so the
    /// WiFi/cellular switches take effect live. Blocking — runs on `queue`.
    static func startRSSILoop(provider: @escaping () -> (Bool, Bool),
                              _ completion: @escaping (Bool, String) -> Void) {
        queue.async {
            guard rssiTimer == nil else {
                completion(true, "RSSI đã đang chạy")
                return
            }
            guard kernelReady else {
                log("mechanism: CHƯA có kernel R/W — hãy bấm Start Darksword trước khi bật RSSI")
                completion(false, "kernel R/W chưa hoạt động — chạy Start Darksword trước")
                return
            }

            var report = Report()
            guard acquireSession(&report) else {
                completion(false, report.sessionFailure)
                return
            }

            log_session_begin()
            defer { log_session_end() }

            let (wifi, cell) = provider()
            log("mechanism: bật RSSI trực tiếp (wifi=\(wifi ? 1 : 0) cell=\(cell ? 1 : 0))…")
            guard rssidisplay_apply_in_session(wifi, cell) else {
                log("mechanism: RSSI tick đầu thất bại — nhả session")
                releaseSession()
                completion(false, "RSSI tick đầu thất bại — xem log [RSSI]")
                return
            }

            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + 2.0, repeating: 2.0)
            let box = ProviderBox(provider)
            timer.setEventHandler { [box] in
                let provider = box.provider
                let (w, c) = provider()
                _ = rssidisplay_apply_in_session(w, c)
            }
            timer.resume()
            rssiTimer = timer
            log("mechanism: RSSI loop đang chạy — nhãn dBm được cập nhật mỗi 2 giây")
            completion(true, "RSSI trực tiếp đang chạy (tick 2 giây)")
        }
    }

    /// Stops the RSSI loop, removes the remote labels, closes the session.
    static func stopRSSILoop(_ completion: @escaping (Bool, String) -> Void) {
        queue.async {
            guard let timer = rssiTimer else {
                completion(true, "RSSI không chạy")
                return
            }
            timer.cancel()
            rssiTimer = nil
            log_session_begin()
            defer { log_session_end() }
            _ = rssidisplay_stop_in_session()
            rssidisplay_forget_remote_state()
            releaseSession()
            log("mechanism: RSSI đã dừng — nhãn dBm được gỡ, session đã đóng")
            completion(true, "RSSI đã dừng")
        }
    }

    private final class ProviderBox {
        let provider: () -> (Bool, Bool)
        init(_ provider: @escaping () -> (Bool, Bool)) { self.provider = provider }
    }

    /// Thread-safe holder for the live RSSI WiFi/cellular switches. The UI
    /// (main actor) writes, the mechanism queue reads on every tick.
    final class RSSIPreferenceBox: @unchecked Sendable {
        private let lock = NSLock()
        private var wifi = true
        private var cell = true
        func set(wifi: Bool, cell: Bool) {
            lock.lock(); defer { lock.unlock() }
            self.wifi = wifi; self.cell = cell
        }
        func get() -> (Bool, Bool) {
            lock.lock(); defer { lock.unlock() }
            return (wifi, cell)
        }
    }

    // MARK: - Kernel-level OTA

    /// OTA disable/enable — kernel R/W only, no SpringBoard session.
    /// Blocking — runs on `queue`.
    static func applyOTA(_ disable: Bool, _ completion: @escaping (Report) -> Void) {
        queue.async {
            var report = Report()
            report.kernelReady = kernelReady

            guard kernelReady else {
                log("mechanism: CHƯA có kernel R/W — hãy bấm Start Darksword trước khi đổi OTA")
                report.sessionFailure = "kernel R/W chưa hoạt động — chạy Start Darksword trước"
                completion(report)
                return
            }

            log_session_begin()
            defer { log_session_end() }

            log("mechanism: \(disable ? "đang CHẶN" : "đang BẬT LẠI") OTA updates…")
            let ok = darksword_ota_set_disabled(disable)
            report.ota = ok
            log("mechanism: OTA \(disable ? "disable" : "enable") \(ok ? "OK" : "THẤT BẠI") — xem log [OTA] để biết chi tiết")
            if ok {
                log("mechanism: cần respring/reboot để thay đổi OTA có hiệu lực")
            }
            completion(report)
        }
    }

    // MARK: - Session helpers (queue-only, reference-counted)

    /// Acquires the shared SpringBoard session (opens it for the first user).
    /// The RSSI loop, the tweak applier and the ESP overlay registration all
    /// share one RemoteCall session through this counter.
    private static func acquireSession(_ report: inout Report) -> Bool {
        if sessionOpen {
            sessionUsers += 1
            report.sessionOpened = true
            log("mechanism: dùng lại session SpringBoard đang mở (pid=\(remote_call_current_pid()), users=\(sessionUsers))")
            return true
        }

        log("mechanism: mở RemoteCall session vào SpringBoard…")
        let rc = init_remote_call("SpringBoard", false)
        guard rc == 0 else {
            let failure = remote_call_last_init_failure()
            let desc = String(cString: remote_call_init_failure_description(failure))
            let pid = remote_call_last_init_failure_pid()
            log("mechanism: THẤT BẠI — init_remote_call trả về \(rc) (\(desc), pid=\(pid))")
            report.sessionFailure = "mở session thất bại: \(desc)"
            return false
        }
        sessionOpen = true
        sessionUsers = 1
        report.sessionOpened = true
        log("mechanism: session SpringBoard đã sẵn sàng (pid=\(remote_call_current_pid()))")
        return true
    }

    private static func releaseSession() {
        guard sessionOpen, sessionUsers > 0 else { return }
        sessionUsers -= 1
        if sessionUsers == 0 {
            closeSession()
        } else {
            log("mechanism: session vẫn mở — còn \(sessionUsers) người dùng (RSSI/ESP)")
        }
    }

    private static func closeSession() {
        guard sessionOpen else { return }
        let destroyed = destroy_remote_call()
        sessionOpen = false
        sessionUsers = 0
        if destroyed != 0 {
            log("mechanism: session đóng với mã \(destroyed) — trạng thái local đã được dọn")
        } else {
            log("mechanism: session SpringBoard đã đóng")
        }
    }

    // MARK: - Shared session API for the ESP overlay

    /// Opens (or reuses) the shared SpringBoard session for ESP registration.
    /// Returns nil on success, or a failure description. Safe to call from
    /// any queue (synchronizes on the mechanism queue).
    static func acquireSessionForESP() -> String? {
        var failure: String? = nil
        queue.sync {
            if sessionOpen {
                sessionUsers += 1
                return
            }
            let rc = init_remote_call("SpringBoard", false)
            guard rc == 0 else {
                let failureInfo = remote_call_last_init_failure()
                let desc = String(cString: remote_call_init_failure_description(failureInfo))
                failure = "mở session SpringBoard thất bại: \(desc)"
                log("esp: \(failure!)")
                return
            }
            sessionOpen = true
            sessionUsers = 1
            log("esp: session SpringBoard đã mở (pid=\(remote_call_current_pid()))")
        }
        return failure
    }

    /// Balances `acquireSessionForESP`. Closes the session when the last
    /// user (RSSI loop / tweak apply / ESP) releases it.
    static func releaseSessionForESP() {
        queue.sync {
            releaseSession()
        }
    }
}

// MARK: - UI state

/// Observable state backing the mechanism panel on the main screen.
/// Serialization mirrors cyanide: one mechanism action at a time.
@MainActor
final class MechanismState: ObservableObject {
    @Published var config = DarkswordMechanism.Config()
    @Published private(set) var isRunning = false
    @Published private(set) var rssiActive = false
    @Published private(set) var rssiBusy = false
    @Published private(set) var lastSummary: String?
    @Published private(set) var lastSuccess: Bool?

    /// Shared with the mechanism queue for live RSSI switch updates.
    private let rssiPrefs = DarkswordMechanism.RSSIPreferenceBox()

    var canApply: Bool { !isRunning }
    var mechanismBusy: Bool { isRunning || rssiBusy }

    /// Toggle writes go through here so the live RSSI loop picks them up
    /// on its next tick without restarting the session.
    func setRSSIPrefs(wifi: Bool, cell: Bool) {
        config.rssiShowWifi = wifi
        config.rssiShowCell = cell
        rssiPrefs.set(wifi: wifi, cell: cell)
    }

    func applySessionTweaks(kernelBusy: Bool) {
        guard canApply, !kernelBusy, config.anySessionTweakEnabled else { return }
        isRunning = true
        let snapshot = config
        DarkswordMechanism.applySessionTweaks(snapshot) { [weak self] report in
            DispatchQueue.main.async {
                self?.finish(report.sessionOpened && report.allRequestedSucceeded,
                             report.summary,
                             report.sessionFailure)
            }
        }
    }

    func startRSSI(kernelBusy: Bool) {
        guard !rssiBusy, !kernelBusy else { return }
        rssiBusy = true
        rssiPrefs.set(wifi: config.rssiShowWifi, cell: config.rssiShowCell)
        DarkswordMechanism.startRSSILoop(provider: { [weak prefs = rssiPrefs] in
            prefs?.get() ?? (true, true)
        }, { [weak self] ok, message in
            DispatchQueue.main.async {
                guard let self else { return }
                self.rssiBusy = false
                self.rssiActive = ok
                self.lastSuccess = ok
                self.lastSummary = message
            }
        })
    }

    func stopRSSI() {
        guard !rssiBusy else { return }
        rssiBusy = true
        DarkswordMechanism.stopRSSILoop { [weak self] ok, message in
            DispatchQueue.main.async {
                guard let self else { return }
                self.rssiBusy = false
                self.rssiActive = false
                self.lastSuccess = ok
                self.lastSummary = message
            }
        }
    }

    func applyOTA(_ disable: Bool, kernelBusy: Bool) {
        guard canApply, !kernelBusy else { return }
        isRunning = true
        DarkswordMechanism.applyOTA(disable) { [weak self] report in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRunning = false
                self.lastSuccess = report.ota == true
                self.lastSummary = report.sessionFailure.isEmpty
                    ? "OTA \(disable ? "chặn" : "bật lại")"
                    : report.sessionFailure
            }
        }
    }

    private func finish(_ ok: Bool, _ summary: String, _ failure: String) {
        isRunning = false
        lastSuccess = ok
        lastSummary = failure.isEmpty ? summary : failure
    }
}
