import SwiftUI
import UIKit

@main
struct DarkSwordApp: App {
    @StateObject private var appState = AppState()

    init() {
        setupLogCapture()
        log("app: DarkSword khởi động — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.displayMachineName)")
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("Darksword", systemImage: "bolt.shield.fill")
                    }
                ESPTab()
                    .tabItem {
                        Label("ESP FF", systemImage: "scope")
                    }
            }
            .environmentObject(appState)
        }
    }
}

/// Single-purpose state for the manual "Start Darksword" run.
/// A watchdog guarantees the UI never hangs silently: if the exploit is still
/// running past the ceiling the status flips to `timedOut` with a clear log.
final class AppState: ObservableObject {
    enum Phase: Equatable {
        case idle
        case running
        case succeeded
        case failed
        case timedOut
        case unsupported(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var exploitStatus: ExploitStatus = .notStarted

    private var watchdog: DispatchWorkItem?

    var isRunning: Bool { phase == .running }
    var isSupported: Bool {
        if case .unsupported = phase { return false }
        return true
    }

    var compatibilitySummary: (supported: Bool, detail: String) {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        if supported {
            return (true, "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) — trong phạm vi đã xác minh")
        }
        return (false, "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) — ngoài phạm vi đã xác minh")
    }

    func detectSupportIfNeeded() {
        guard case .idle = phase else { return }
        if !compatibilitySummary.supported {
            let detail = compatibilitySummary.detail
            phase = .unsupported(detail)
            exploitStatus = .unsupported(detail)
            log("app: thiết bị chưa được hỗ trợ — \(detail)")
        }
    }

    /// Manual start: only from the Start Darksword button.
    func startDarksword() {
        guard !isRunning else { return }

        guard compatibilitySummary.supported else {
            let detail = compatibilitySummary.detail
            phase = .unsupported(detail)
            exploitStatus = .unsupported(detail)
            log("app: từ chối chạy — \(detail)")
            return
        }

        if exploitStatus.isFailed {
            log("app: lần chạy trước thất bại — khuyến nghị khởi động lại app trước khi thử lại")
        }

        phase = .running
        exploitStatus = .running
        log("app: chạy darksword trên luồng nền…")

        armWatchdog()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                guard let self else { return }
                self.disarmWatchdog()
                self.kernelExploitDidFinish(ok: ok)
            }
        }
    }

    private func kernelExploitDidFinish(ok: Bool) {
        guard isRunning || phase == .timedOut else { return }
        if ok {
            phase = .succeeded
            exploitStatus = .success(method: "kexploit")
            if KernelExploit.requiresSandboxEscape {
                log("app: darksword thành công — sandbox access đã được xác minh")
            } else {
                log("app: darksword thành công — kernel access đang hoạt động")
            }
        } else {
            phase = .failed
            exploitStatus = .failed(method: "kexploit", code: -1)
            log("app: darksword thất bại — khởi động lại app trước khi thử lại")
        }
    }

    // MARK: Watchdog (anti-hang guarantee)

    private func armWatchdog() {
        disarmWatchdog()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning else { return }
            self.phase = .timedOut
            self.exploitStatus = .failed(method: "kexploit", code: -2)
            log("darksword: CẢNH BÁO — đã quá \(Int(KernelExploit.watchdogTimeout / 60)) phút mà chưa xong; có thể tiến trình bị kẹt")
            log("darksword: hãy buộc thoát app (swipe up) và chạy lại nếu nút không phản hồi")
        }
        watchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + KernelExploit.watchdogTimeout, execute: item)
    }

    private func disarmWatchdog() {
        watchdog?.cancel()
        watchdog = nil
    }
}
