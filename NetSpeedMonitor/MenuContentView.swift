import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var monitor: MenuBarState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Network Pulse")
                            .font(.headline)
                        StatusLabel(status: monitor.status)
                            .font(.caption)
                    }
                    Spacer()
                    Button {
                        monitor.toggleMonitoring()
                    } label: {
                        Image(systemName: monitor.isPaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.borderless)
                    .help(monitor.isPaused ? "Resume monitoring" : "Pause monitoring")
                }

                HStack(spacing: 12) {
                    MenuSpeedValue(title: "Download", speed: monitor.speeds.download, color: .blue)
                    Divider().frame(height: 42)
                    MenuSpeedValue(title: "Upload", speed: monitor.speeds.upload, color: .mint)
                }

                TrafficChartView(samples: monitor.samples(in: .fiveMinutes), compact: true)
                    .frame(height: 82)
            }
            .padding(16)

            Divider()

            VStack(spacing: 8) {
                Button {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Open Dashboard", systemImage: "rectangle.3.group")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: AppActions.openActivityMonitor) {
                    Label("Open Activity Monitor", systemImage: "waveform.path.ecg")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                Button("Quit Network Pulse") { NSApplication.shared.terminate(nil) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .frame(width: 320)
    }
}

private struct MenuSpeedValue: View {
    let title: String
    let speed: NetworkSpeed
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(speed.formatted)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
