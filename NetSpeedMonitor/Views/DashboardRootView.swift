import SwiftUI

private enum DashboardSection: String, CaseIterable, Identifiable {
    case overview
    case history
    case interfaces
    case settings

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .overview: "gauge.with.dots.needle.67percent"
        case .history: "chart.xyaxis.line"
        case .interfaces: "network"
        case .settings: "gearshape"
        }
    }
}

struct DashboardRootView: View {
    @EnvironmentObject private var monitor: MenuBarState
    @SceneStorage("dashboardSelection") private var selection = DashboardSection.overview

    var body: some View {
        NavigationSplitView {
            List(DashboardSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("Network Pulse")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            Group {
                switch selection {
                case .overview: OverviewView()
                case .history: HistoryView()
                case .interfaces: InterfacesView()
                case .settings: DashboardSettingsView()
                }
            }
            .environmentObject(monitor)
            .navigationTitle(selection.title)
        }
        .frame(minWidth: 760, minHeight: 540)
        .toolbar {
            ToolbarItemGroup {
                StatusLabel(status: monitor.status)
                Button(monitor.isPaused ? "Resume" : "Pause") {
                    monitor.toggleMonitoring()
                }
                .labelStyle(.iconOnly)
                .help(monitor.isPaused ? "Resume monitoring" : "Pause monitoring")
            }
        }
    }
}

private struct OverviewView: View {
    @EnvironmentObject private var monitor: MenuBarState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network activity")
                        .font(.largeTitle.bold())
                    Text("A live view of traffic across your selected network interface.")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    SpeedCard(
                        title: "Download",
                        speed: monitor.speeds.download,
                        systemImage: "arrow.down",
                        tint: .blue
                    )
                    SpeedCard(
                        title: "Upload",
                        speed: monitor.speeds.upload,
                        systemImage: "arrow.up",
                        tint: .mint
                    )
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Recent traffic", systemImage: "waveform.path.ecg")
                                .font(.headline)
                            Spacer()
                            TrafficLegend(isPaused: monitor.isPaused)
                        }
                        TrafficChartView(
                            samples: monitor.samples(in: .fiveMinutes),
                            range: .fiveMinutes,
                            isPaused: monitor.isPaused,
                            compact: true
                        )
                            .frame(height: 190)
                    }
                    .padding(8)
                }

                HStack(spacing: 12) {
                    SummaryCard(title: "Downloaded", value: NetworkValueFormatter.bytes(monitor.sessionDownloadedBytes))
                    SummaryCard(title: "Uploaded", value: NetworkValueFormatter.bytes(monitor.sessionUploadedBytes))
                    SummaryCard(title: "Peak down", value: monitor.peakDownload.formatted)
                    SummaryCard(title: "Peak up", value: monitor.peakUpload.formatted)
                }
            }
            .padding(24)
        }
    }
}

private struct HistoryView: View {
    @EnvironmentObject private var monitor: MenuBarState
    @State private var range = HistoryRange.fifteenMinutes

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Traffic history")
                            .font(.largeTitle.bold())
                        Text("In-memory activity for the current session.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Range", selection: $range) {
                        ForEach(HistoryRange.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            TrafficLegend(isPaused: monitor.isPaused)
                            Spacer()
                            Text("\(monitor.samples(in: range).count) samples")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        TrafficChartView(
                            samples: monitor.samples(in: range),
                            range: range,
                            isPaused: monitor.isPaused
                        )
                            .frame(minHeight: 320)
                    }
                    .padding(8)
                }

                HStack {
                    Text("Session started \(monitor.sessionStarted, format: .dateTime.hour().minute())")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear History", role: .destructive) { monitor.clearSession() }
                }
            }
            .padding(24)
        }
    }
}

private struct InterfacesView: View {
    @EnvironmentObject private var monitor: MenuBarState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Network interfaces")
                    .font(.largeTitle.bold())
                Text("Choose one interface, or let Network Pulse use the busiest path automatically.")
                    .foregroundStyle(.secondary)
            }

            Picker("Monitored interface", selection: $monitor.selectedInterface) {
                Text("Automatic (busiest)").tag(MenuBarState.automaticInterface)
                ForEach(monitor.availableInterfaceNames, id: \.self) { Text($0).tag($0) }
            }
            .frame(maxWidth: 360)

            Table(monitor.interfaceReadings) {
                TableColumn("Interface", value: \.name)
                TableColumn("Download") { Text($0.speeds.download.formatted).monospacedDigit() }
                TableColumn("Upload") { Text($0.speeds.upload.formatted).monospacedDigit() }
            }
        }
        .padding(24)
    }
}

private struct SpeedCard: View {
    let title: String
    let speed: NetworkSpeed
    let systemImage: String
    let tint: Color

    var body: some View {
        GroupBox {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2.bold())
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.secondary)
                    Text(speed.formatted)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit().lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct StatusLabel: View {
    let status: MonitorStatus

    var body: some View {
        Label(status.title, systemImage: status.systemImage)
            .foregroundStyle(status == .monitoring ? .green : .secondary)
            .help("Monitor status: \(status.title)")
    }
}

struct TrafficLegend: View {
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Label("Download", systemImage: "circle.fill")
                .foregroundStyle(isPaused ? .yellow : .blue)
            Label("Upload", systemImage: "circle.fill")
                .foregroundStyle(isPaused ? .yellow.opacity(0.72) : .mint)
        }
        .font(.caption)
    }
}
