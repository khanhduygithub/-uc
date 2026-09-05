import SwiftUI

/// ESP Free Fire tab — DarkSword remake of the CrackTeam mod menu.
///
/// The floating HUD menu from the TrollStore build is gone by design: every
/// customization lives here, and the health of each pipeline stage is shown
/// as a green/red (xanh/đỏ) live notification.
struct ESPTab: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var esp = ESPEngine()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                statusCard
                controlCard
                displaySection
                aimbotSection
                cameraSection
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            esp.applyConfig()
            // Paint the real kernel-pipeline state immediately — the status
            // rows must reflect Start Darksword's result BEFORE the user
            // presses Bật ESP (previously they stayed all-red until the
            // post-start 2 s timer kicked in, looking like a kernel reset).
            esp.refreshStatusOnce()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.green.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text("ESP Free Fire")
                    .font(.title3.weight(.bold))
                Text("Remake CrackTeam (TrollStore) → DarkSword kernel")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: Green/red status notifications

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trạng thái")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            statusRow("Kernel R/W (Start Darksword)", esp.status.kernelReady)
            statusRow("Root qua kernel (như TrollStore)", esp.status.rootElevated)
            statusRow("Tìm thấy FreeFire\(esp.status.pid > 0 ? " · pid \(esp.status.pid)" : "")", esp.status.gameFound)
            statusRow("Cầu task-port kernel", esp.status.portReady)
            statusRow("Cửa sổ ESP (đè lên game)", esp.status.overlayWindow)
            statusRow("Đăng ký SpringBoard\(esp.status.contextID > 0 ? " · ctx \(esp.status.contextID)" : "")", esp.status.sbRegistered)
            statusRow("Vòng lặp vẽ 60Hz\(esp.status.tickLoop ? " · \(esp.status.frameCount) frame" : "")", esp.status.tickLoop)
            statusRow("Chống suspend khi vào nền", esp.status.keepAlive)
            statusRow("Game đang chạy\(esp.status.enemyCount > 0 ? " · \(esp.status.enemyCount) địch" : "")", esp.status.gameRunning || esp.status.gameProcessAlive)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private func statusRow(_ title: String, _ ok: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ok ? Color.green : Color.red)
                .frame(width: 10, height: 10)
                .shadow(color: ok ? Color.green.opacity(0.6) : Color.red.opacity(0.6), radius: 3)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(ok ? "HOẠT ĐỘNG" : "CHƯA")
                .font(.caption.weight(.bold))
                .foregroundStyle(ok ? Color.green : Color.red)
        }
    }

    // MARK: Control card

    private var controlCard: some View {
        VStack(spacing: 10) {
            Button {
                if esp.isRunning { esp.stopESP() } else { esp.startESP() }
            } label: {
                HStack(spacing: 8) {
                    if esp.busy {
                        ProgressView().tint(.white)
                        Text("Đang xử lý…").fontWeight(.semibold)
                    } else if esp.isRunning {
                        Image(systemName: "stop.fill")
                        Text("Dừng ESP").fontWeight(.semibold)
                    } else {
                        Image(systemName: "play.fill")
                        Text("Bật ESP").fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(esp.busy ? Color.gray : (esp.isRunning ? Color.red : Color.green)))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(esp.busy || (!esp.isRunning && !kernelAvailable))

            Button {
                esp.launchGame()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                    Text("Mở Free Fire").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14)))
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(esp.busy || !kernelAvailable)

            Text(esp.lastMessage)
                .font(.caption)
                .foregroundStyle(messageColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if case .failed(let reason) = esp.phase {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !kernelAvailable {
                Text("Cần chạy Start Darksword (tab Darksword) để có kernel R/W trước khi bật ESP.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .cardBackground()
    }

    private var kernelAvailable: Bool {
        esp.status.kernelReady || appState.phase == .succeeded
    }

    private var messageColor: Color {
        if case .failed = esp.phase { return .red }
        return esp.isRunning ? .green : .secondary
    }

    // MARK: Display customization

    private var displaySection: some View {
        section("Hiển thị") {
            toggle("Khung box", $esp.config.box)
            toggle("Tên", $esp.config.name)
            toggle("Thanh máu", $esp.config.health)
            toggle("Khoảng cách", $esp.config.distance)
            toggle("Đường snapline", $esp.config.snapline)
            toggle("Xương (bone)", $esp.config.bone)
            toggle("Đếm địch trên màn hình", $esp.config.enemyCount)
            toggle("Vẽ cả bot", $esp.config.showBots)
            toggle("Vòng FOV aimbot", $esp.config.showFov)
        }
    }

    // MARK: Aimbot customization

    private var aimbotSection: some View {
        section("Aimbot") {
            toggle("Bật aimbot", $esp.config.aimbot)

            if esp.config.aimbot {
                Picker("Kích hoạt", selection: $esp.config.triggerMode) {
                    ForEach(ESPConfig.TriggerMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .font(.caption)

                Picker("Vị trí ngắm", selection: $esp.config.aimPosition) {
                    ForEach(ESPConfig.AimPosition.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .font(.caption)

                Picker("Ưu tiên mục tiêu", selection: $esp.config.aimTargetMode) {
                    ForEach(ESPConfig.TargetMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .font(.caption)

                slider("FOV", value: $esp.config.aimFov, range: 10...500, format: "%.0f")
                slider("Khoảng cách tối đa", value: $esp.config.aimDistance, range: 10...400, format: "%.0f m")
                slider("Tốc độ", value: $esp.config.aimSpeed, range: 0.01...1.0, format: "%.2f")

                toggle("Bỏ qua bot", $esp.config.aimIgnoreBots)
                toggle("Bỏ qua địch đã gục", $esp.config.aimIgnoreKnocked)
                toggle("Chỉ aim khi thấy (visible)", $esp.config.aimCheckVisible)
                toggle("Rage (bám ngay lập tức)", $esp.config.aimRage)
            }
        }
    }

    // MARK: Camera customization

    private var cameraSection: some View {
        section("Camera") {
            toggle("Camera cao (góc nhìn xa)", $esp.config.highCamera)
            if esp.config.highCamera {
                slider("Độ cao", value: $esp.config.highCameraValue, range: 1...100, format: "%.0f")
            }
        }
    }

    // MARK: Helpers

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
        .onChange(of: esp.config) { _ in esp.applyConfig() }
    }

    private func toggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(title, isOn: binding)
            .font(.subheadline)
            .tint(Color.green)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .tint(Color.green)
        }
    }
}

// MARK: - Card style shared with the main tab

extension View {
    @ViewBuilder
    func cardBackground() -> some View {
        background(
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
