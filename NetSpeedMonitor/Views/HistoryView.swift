import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var monitor: MenuBarState
    @EnvironmentObject private var historyStore: TrafficHistoryStore
    @AppStorage("HistorySelectedInterface") private var selectedInterface = ""
    @State private var range = HistoryRange.fifteenMinutes
    @State private var samples: [NetworkSample] = []
    @State private var isLoading = false
    @State private var showsDeleteConfirmation = false

    private var interfaceNames: [String] {
        var names = historyStore.interfaces.map(\.name)
        if monitor.selectedInterface != MenuBarState.automaticInterface,
           !names.contains(monitor.selectedInterface) {
            names.append(monitor.selectedInterface)
        }
        return names
    }

    private var queryID: QueryID {
        QueryID(
            interfaceName: selectedInterface,
            range: range,
            revision: historyStore.revision
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if !monitor.saveTrafficHistory {
                    Label("History saving is off. Retained history remains available until it expires.", systemImage: "pause.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if !historyStore.persistenceAvailable {
                    Label("Saved history is currently unavailable. Live monitoring is unaffected.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            TrafficLegend(isPaused: monitor.isPaused)
                            Spacer()
                            if isLoading {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("\(samples.filter { $0.sampleCount > 0 }.count) recorded intervals")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        TrafficChartView(
                            samples: samples,
                            range: range,
                            isPaused: monitor.isPaused,
                            showsDetails: true
                        )
                        .frame(minHeight: 320)
                    }
                    .padding(8)
                }

                HStack {
                    Text("Saved traffic is automatically removed after seven days.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear Session") { monitor.clearSession() }
                    Button("Delete Saved History…", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                    .disabled(historyStore.interfaces.isEmpty)
                }
            }
            .padding(24)
        }
        .onAppear(perform: ensureSelection)
        .onChange(of: interfaceNames) { _, _ in ensureSelection() }
        .task(id: queryID) { await loadHistory() }
        .confirmationDialog(
            "Delete all saved traffic history?",
            isPresented: $showsDeleteConfirmation
        ) {
            Button("Delete Saved History", role: .destructive) {
                Task {
                    await historyStore.deleteSavedHistory()
                    samples = []
                    ensureSelection()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. The current live session will not be reset.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Traffic history")
                        .font(.largeTitle.bold())
                    Text("Persistent traffic for one network interface at a time.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(HistoryRange.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 390)
            }

            Picker("Interface", selection: $selectedInterface) {
                if interfaceNames.isEmpty {
                    Text("No recorded interfaces").tag("")
                } else {
                    ForEach(interfaceNames, id: \.self) { name in
                        Text(NetworkInterfaceName.displayName(for: name)).tag(name)
                    }
                }
            }
            .frame(maxWidth: 360)
        }
    }

    private func ensureSelection() {
        guard !interfaceNames.isEmpty else {
            if historyStore.hasLoadedInterfaces {
                selectedInterface = ""
            }
            return
        }
        if interfaceNames.contains(selectedInterface) { return }
        if monitor.selectedInterface != MenuBarState.automaticInterface,
           interfaceNames.contains(monitor.selectedInterface) {
            selectedInterface = monitor.selectedInterface
        } else if let busiestRetainedInterface = historyStore.interfaces.first?.name {
            selectedInterface = busiestRetainedInterface
        } else if !historyStore.persistenceAvailable {
            selectedInterface = interfaceNames[0]
        }
    }

    private func loadHistory() async {
        guard !selectedInterface.isEmpty else {
            samples = []
            return
        }
        isLoading = true
        let points = await historyStore.history(interfaceName: selectedInterface, range: range)
        guard !Task.isCancelled else { return }
        samples = points.map { point in
            NetworkSample(
                date: point.date,
                uploadBytesPerSecond: point.uploadBytesPerSecond,
                downloadBytesPerSecond: point.downloadBytesPerSecond,
                interval: point.interval,
                uploadedBytes: point.sentBytes,
                downloadedBytes: point.receivedBytes,
                peakUploadBytesPerSecond: point.peakUploadBytesPerSecond,
                peakDownloadBytesPerSecond: point.peakDownloadBytesPerSecond,
                sampleCount: point.sampleCount
            )
        }
        isLoading = false
    }
}

private struct QueryID: Hashable {
    let interfaceName: String
    let range: HistoryRange
    let revision: Int
}
