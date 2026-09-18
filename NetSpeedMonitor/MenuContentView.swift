import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var monitor: MenuBarState
    @Environment(\.openWindow) private var openWindow
    @State private var isPauseButtonHovered = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Network Pulse")
                        .font(.headline)
                    Spacer()
                    Button {
                        monitor.toggleMonitoring()
                    } label: {
                        Image(systemName: monitor.isPaused ? "play.fill" : "pause.fill")
                            .frame(width: 24, height: 24)
                            .background {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(
                                        isPauseButtonHovered
                                            ? Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
                                            : Color.clear
                                    )
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isPauseButtonHovered = $0 }
                    .help(monitor.isPaused ? "Resume monitoring" : "Pause monitoring")
                }

                HStack(spacing: 10) {
                    MenuSpeedValue(title: "Download", speed: monitor.speeds.download, color: .blue)
                    Divider().frame(height: 34)
                    MenuSpeedValue(title: "Upload", speed: monitor.speeds.upload, color: .mint)
                }

                TrafficChartView(
                    samples: monitor.samples(in: .fiveMinutes),
                    range: .fiveMinutes,
                    isPaused: monitor.isPaused,
                    compact: true
                )
                    .frame(height: 68)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Divider()

            VStack(spacing: 2) {
                Button {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Text("Open Dashboard")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuActionRow()

                SettingsLink {
                    Text("Settings")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuActionRow()

                Button(action: AppActions.openActivityMonitor) {
                    Text("Open Activity Monitor")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuActionRow()

                Divider()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit Network Pulse")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuActionRow()
            }
            .padding(8)
        }
        .frame(width: 300)
    }
}

private struct MenuActionRowModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        isHovered
                            ? Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
                            : Color.clear
                    )
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

private extension View {
    func menuActionRow() -> some View {
        modifier(MenuActionRowModifier())
    }
}

private struct MenuSpeedValue: View {
    let title: String
    let speed: NetworkSpeed
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(speed.formatted)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
