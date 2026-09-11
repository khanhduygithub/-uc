import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var appLog = AppLog.shared
    @StateObject private var mechanism = MechanismState()

    var body: some View {
        VStack(spacing: 14) {
            header
            deviceCard
            MechanismPanel(mechanism: mechanism, appState: appState)
            LogFrame()
            startFrame
        }
        .padding(16)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
        .onAppear { appState.detectSupportIfNeeded() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            appIconView
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("DarkSword")
                    .font(.title3.weight(.bold))
                Text("Kernel exploit · kexploit_opa334")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "bolt.shield.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let icon = bundleAppIcon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    // App icon set does not always resolve via UIImage(named:); read the
    // generated CFBundleIconFiles entry first, then fall back by name.
    private var bundleAppIcon: UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primary["CFBundleIconFiles"] as? [String],
           let name = iconFiles.last,
           let image = UIImage(named: name) {
            return image
        }
        return UIImage(named: "AppIcon")
    }

    // MARK: Device card

    private var deviceCard: some View {
        let compat = appState.compatibilitySummary
        return VStack(spacing: 10) {
            HStack {
                Text("Thiết bị")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            row(label: "Máy", value: AppInfo.displayMachineName)
            row(label: "Hệ điều hành", value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
            HStack(alignment: .center) {
                Text("Tương thích")
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(compat.supported ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(compat.supported ? "Hỗ trợ" : "Không hỗ trợ")
                        .foregroundStyle(compat.supported ? Color.green : Color.red)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }
            Text(compat.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }

    // MARK: Start frame (soft rounded card at the bottom)

    private var startFrame: some View {
        VStack(spacing: 10) {
            Button(action: { appState.startDarksword() }) {
                HStack(spacing: 8) {
                    if appState.isRunning {
                        ProgressView()
                            .tint(.white)
                        Text("Đang chạy…")
                            .fontWeight(.semibold)
                    } else {
                        Image(systemName: "play.fill")
                        Text("Start Darksword")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(appState.isRunning ? Color.gray : Color.accentColor)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(startDisabled)
            .accessibilityLabel("Start Darksword")

            Text(statusText)
                .font(.caption)
                .foregroundStyle(statusColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var startDisabled: Bool {
        // Sau timeout luồng cũ vẫn còn trong nền — khóa nút để tránh 2 lần
        // chạy darksword đè lên nhau; khởi động lại app để chạy lại.
        appState.isRunning || appState.phase == .timedOut
    }

    private var statusText: String {
        switch appState.phase {
        case .idle:
            return "Sẵn sàng — bấm Start Darksword để bắt đầu"
        case .running:
            return "Darksword đang chạy theo từng bước, tiến trình hiển thị trong khung nhật ký"
        case .succeeded:
            return "Hoàn tất — quyền truy cập kernel/sandbox đang hoạt động"
        case .failed:
            return "Thất bại — nên khởi động lại app rồi thử lại"
        case .timedOut:
            return "Quá thời gian chờ — buộc thoát app (swipe up) rồi mở lại để chạy tiếp"
        case .unsupported(let detail):
            return "Không hỗ trợ: \(detail)"
        }
    }

    private var statusColor: Color {
        switch appState.phase {
        case .idle: return .secondary
        case .running: return .blue
        case .succeeded: return .green
        case .failed, .timedOut: return .red
        case .unsupported: return .orange
        }
    }
}

// MARK: - Darksword mechanism panel (ported from Cyanide)

/// Collapsible card exposing every Darksword mechanism brought over from
/// Cyanide: SpringBoard session tweaks (App Library, icon fly-in, wake
/// animation, backlight fade, double-tap lock, drag coefficient, home/dock
/// layout, RSSI dBm) plus the kernel-level OTA kill switch.
private struct MechanismPanel: View {
    @ObservedObject var mechanism: MechanismState
    @EnvironmentObject private var appState: AppState
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $expanded) {
                panelBody
                    .padding(.top, 10)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                    Text("Cơ chế Darksword")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("từ Cyanide")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Panel body

    private var panelBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            sessionToggles
            dragSection
            layoutSection
            rssiSection
            otaSection
            applySection
        }
    }

    private var sessionToggles: some View {
        VStack(spacing: 8) {
            toggleRow("Ẩn App Library", binding: $mechanism.config.disableAppLibrary)
            toggleRow("Tắt hiệu ứng bay của icon", binding: $mechanism.config.disableIconFlyIn)
            toggleRow("Xoá animation đánh thức", binding: $mechanism.config.zeroWakeAnimation)
            toggleRow("Xoá fade độ sáng màn hình", binding: $mechanism.config.zeroBacklightFade)
            toggleRow("Double-tap để khoá máy", binding: $mechanism.config.doubleTapToLock)
        }
    }

    private var dragSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            toggleRow("Tốc độ animation SpringBoard", binding: $mechanism.config.dragEnabled)
            if mechanism.config.dragEnabled {
                HStack {
                    Slider(value: $mechanism.config.dragCoefficient, in: 0.01...2.0, step: 0.01)
                    Text(String(format: "%.2f×", mechanism.config.dragCoefficient))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
                Text("< 1.0 = nhanh hơn, > 1.0 = chậm hơn (mặc định Cyanide: 0.50)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            toggleRow("Giãn cách / tỷ lệ home & dock", binding: $mechanism.config.layoutEnabled)
            if mechanism.config.layoutEnabled {
                sliderRow("Lề trái home", value: $mechanism.config.homeExtraLeft, range: 0...60)
                sliderRow("Lề phải home", value: $mechanism.config.homeExtraRight, range: 0...60)
                sliderRow("Lề trên home", value: $mechanism.config.homeExtraTop, range: 0...60)
                sliderRow("Lề dưới home", value: $mechanism.config.homeExtraBottom, range: 0...80)
                sliderRow("Lề ngang dock", value: $mechanism.config.dockExtraHorizontal, range: 0...60)
                percentRow("Tỷ lệ icon home", value: $mechanism.config.homeScale)
                percentRow("Tỷ lệ icon dock", value: $mechanism.config.dockScale)
            }
        }
    }

    private var rssiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            toggleRow("Hiện WiFi", binding: wifiBinding)
            toggleRow("Hiện cellular", binding: cellBinding)
            HStack(spacing: 10) {
                Button {
                    if mechanism.rssiActive {
                        mechanism.stopRSSI()
                    } else {
                        mechanism.startRSSI(kernelBusy: appState.isRunning)
                    }
                } label: {
                    HStack(spacing: 6) {
                        if mechanism.rssiBusy {
                            ProgressView().tint(.white)
                            Text("Đang chuyển…")
                        } else {
                            Image(systemName: mechanism.rssiActive ? "stop.circle.fill" : "dot.radiowaves.left.and.right")
                            Text(mechanism.rssiActive ? "Dừng RSSI" : "Bật RSSI trực tiếp (2s/tick)")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(mechanism.rssiActive ? Color.red.opacity(0.14) : Color.accentColor.opacity(0.14))
                    )
                    .foregroundStyle(mechanism.rssiActive ? Color.red : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(mechanism.rssiBusy || appState.isRunning)
            }
            Text("Giữ session SpringBoard mở và cập nhật dBm mỗi 2 giây — tắt để nhả session.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var wifiBinding: Binding<Bool> {
        Binding(get: { mechanism.config.rssiShowWifi },
                set: { mechanism.setRSSIPrefs(wifi: $0, cell: mechanism.config.rssiShowCell) })
    }

    private var cellBinding: Binding<Bool> {
        Binding(get: { mechanism.config.rssiShowCell },
                set: { mechanism.setRSSIPrefs(wifi: mechanism.config.rssiShowWifi, cell: $0) })
    }

    private var otaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OTA Updates (cấp kernel — không cần session)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button {
                    mechanism.applyOTA(true, kernelBusy: appState.isRunning)
                } label: {
                    Text("Chặn OTA")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.red.opacity(0.14)))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .disabled(!mechanism.canApply || appState.isRunning)

                Button {
                    mechanism.applyOTA(false, kernelBusy: appState.isRunning)
                } label: {
                    Text("Bật lại OTA")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accentColor.opacity(0.14)))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(!mechanism.canApply || appState.isRunning)
            }
        }
    }

    private var applySection: some View {
        VStack(spacing: 8) {
            Button {
                mechanism.applySessionTweaks(kernelBusy: appState.isRunning)
            } label: {
                HStack(spacing: 8) {
                    if mechanism.isRunning {
                        ProgressView().tint(.white)
                        Text("Đang áp dụng…").fontWeight(.semibold)
                    } else {
                        Image(systemName: "wand.and.rays")
                        Text("Áp dụng lên SpringBoard").fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(applyDisabled ? Color.gray : Color.accentColor)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(applyDisabled)

            if let summary = mechanism.lastSummary {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.caption)
                    Text(summary)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(mechanism.lastSuccess == true ? Color.green : Color.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !DarkswordMechanism.kernelReady {
                Text("Cần chạy Start Darksword (kernel R/W) trước khi áp dụng cơ chế.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var applyDisabled: Bool {
        mechanism.isRunning || appState.isRunning || !mechanism.config.anySessionTweakEnabled
    }

    private var iconName: String {
        mechanism.lastSuccess == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    // MARK: Row helpers

    private func toggleRow(_ title: String, binding: Binding<Bool>) -> some View {
        Toggle(title, isOn: binding)
            .font(.subheadline)
            .tint(Color.accentColor)
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("+\(Int(value.wrappedValue))pt")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1)
        }
    }

    private func percentRow(_ title: String, value: Binding<Double>) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(value.wrappedValue > 0
                     ? String(format: "%.0f%%", value.wrappedValue * 100)
                     : "mặc định")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0.5...1.5, step: 0.05)
        }
    }
}

// MARK: - Log frame (main console)

private struct LogFrame: View {
    @ObservedObject var appLog = AppLog.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "apple.terminal")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Nhật ký Darksword")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = appLog.entries.joined(separator: "\n")
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.footnote)
                }
                .disabled(appLog.entries.isEmpty)
                .accessibilityLabel("Sao chép nhật ký")

                Button {
                    appLog.clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.footnote)
                }
                .disabled(appLog.entries.isEmpty)
                .accessibilityLabel("Xoá nhật ký")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if appLog.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("Chưa có log — tiến trình darksword sẽ hiện ở đây")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(appLog.entries.enumerated()), id: \.offset) { index, entry in
                                VStack(spacing: 0) {
                                    Text(entry)
                                        .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 7)
                                    if index < appLog.entries.count - 1 {
                                        Divider()
                                    }
                                }
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: appLog.entries.count) { count in
                        guard count > 0 else { return }
                        if reduceMotion {
                            proxy.scrollTo(count - 1, anchor: .bottom)
                        } else {
                            withAnimation(.easeOut(duration: 0.18)) {
                                proxy.scrollTo(count - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
