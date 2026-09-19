import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class MenuBarState: ObservableObject {
    static let automaticInterface = "automatic"

    @AppStorage("AutoLaunchEnabled") var autoLaunchEnabled = false {
        didSet { updateAutoLaunchStatus() }
    }
    @AppStorage(DockIconController.preferenceKey) var showDockIcon = false {
        didSet { DockIconController.applyPreference() }
    }
    @AppStorage("NetSpeedUpdateInterval") var netSpeedUpdateInterval = NetSpeedUpdateInterval.oneSecond {
        didSet { restartTimer() }
    }
    @AppStorage("SaveTrafficHistory") var saveTrafficHistory = true {
        didSet { historyStore.setSavingEnabled(saveTrafficHistory) }
    }
    @AppStorage("SelectedInterface") var selectedInterface = automaticInterface {
        didSet {
            hasReceivedBaseline = false
            lastSampleDate = nil
            status = .warmingUp
            netTrafficStat.reset()
        }
    }

    @Published private(set) var speeds = NetworkSpeeds.zero
    @Published private(set) var samples: [NetworkSample] = []
    @Published private(set) var interfaceReadings: [InterfaceReading] = []
    @Published private(set) var status = MonitorStatus.warmingUp
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var sessionUploadedBytes = 0.0
    @Published private(set) var sessionDownloadedBytes = 0.0
    @Published private(set) var peakUpload = NetworkSpeed.zero
    @Published private(set) var peakDownload = NetworkSpeed.zero
    @Published private(set) var sessionStarted = Date()
    @Published private(set) var indicatorImage = MenuBarIconGenerator.generateIcon(
        speeds: .zero,
        uploadActivity: 0,
        downloadActivity: 0
    )

    var isPaused: Bool { status == .paused }
    var accessibilityLabel: String {
        "Upload \(speeds.upload.accessibilityText), download \(speeds.download.accessibilityText)"
    }
    var availableInterfaceNames: [String] { interfaceReadings.map(\.name) }

    private var timer: Timer?
    private var activityAnimationTimer: Timer?
    private let netTrafficStat = NetTrafficStatReceiver()
    private let historyStore: TrafficHistoryStore
    private var displayedUploadActivity = 0.0
    private var displayedDownloadActivity = 0.0
    private var hasReceivedBaseline = false
    private var lastSampleDate: Date?

    init(historyStore: TrafficHistoryStore) {
        self.historyStore = historyStore
        historyStore.setSavingEnabled(saveTrafficHistory)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.autoLaunchEnabled = self.currentAutoLaunchStatus()
            self.startTimer()
        }
    }

    deinit {
        timer?.invalidate()
        activityAnimationTimer?.invalidate()
    }

    func toggleMonitoring() {
        isPaused ? resume() : pause()
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        status = .paused
    }

    func resume() {
        status = .warmingUp
        hasReceivedBaseline = false
        lastSampleDate = nil
        netTrafficStat.reset()
        startTimer()
    }

    func clearSession() {
        samples.removeAll()
        sessionUploadedBytes = 0
        sessionDownloadedBytes = 0
        peakUpload = .zero
        peakDownload = .zero
        sessionStarted = Date()
    }

    func samples(in range: HistoryRange) -> [NetworkSample] {
        let cutoff = Date().addingTimeInterval(-range.duration)
        return samples.filter { $0.date >= cutoff }
    }

    private func startTimer() {
        timer?.invalidate()
        sampleNetwork()
        let timer = Timer(timeInterval: TimeInterval(netSpeedUpdateInterval.rawValue), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleNetwork() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        logger.info("Network monitor started")
    }

    private func restartTimer() {
        guard status != .paused else { return }
        hasReceivedBaseline = false
        lastSampleDate = nil
        netTrafficStat.reset()
        status = .warmingUp
        startTimer()
    }

    private func sampleNetwork() {
        guard let map = netTrafficStat.getNetTrafficStatMap() else {
            status = .unavailable
            return
        }

        let readings: [InterfaceReading] = map.compactMap { key, value in
            guard let name = key as? String, let stat = value as? NetTrafficStatOC else { return nil }
            return InterfaceReading(
                name: name,
                speeds: NetworkSpeeds(
                    upload: NetworkSpeed(bytesPerSecond: stat.obytes_per_sec.doubleValue),
                    download: NetworkSpeed(bytesPerSecond: stat.ibytes_per_sec.doubleValue)
                ),
                receivedBytes: Int64(stat.delta_ibytes),
                sentBytes: Int64(stat.delta_obytes),
                sampleDuration: stat.delta_ts_sec.doubleValue
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        interfaceReadings = readings
        if selectedInterface != Self.automaticInterface,
           !readings.contains(where: { $0.name == selectedInterface }) {
            selectedInterface = Self.automaticInterface
        }

        let nextSpeeds: NetworkSpeeds
        if let selected = readings.first(where: { $0.name == selectedInterface }) {
            nextSpeeds = selected.speeds
        } else {
            nextSpeeds = NetworkSpeeds(
                upload: NetworkSpeed(bytesPerSecond: readings.map(\.speeds.upload.bytesPerSecond).max() ?? 0),
                download: NetworkSpeed(bytesPerSecond: readings.map(\.speeds.download.bytesPerSecond).max() ?? 0)
            )
        }

        speeds = nextSpeeds
        lastUpdated = Date()
        if let lastUpdated {
            historyStore.record(readings, at: lastUpdated)
        }
        if hasReceivedBaseline {
            status = .monitoring
            record(nextSpeeds)
        } else {
            hasReceivedBaseline = true
            lastSampleDate = lastUpdated
            status = .warmingUp
        }
        animateActivityMeters()
    }

    private func record(_ speeds: NetworkSpeeds) {
        let now = Date()
        samples.append(NetworkSample(
            date: now,
            uploadBytesPerSecond: speeds.upload.bytesPerSecond,
            downloadBytesPerSecond: speeds.download.bytesPerSecond
        ))
        samples.removeAll { now.timeIntervalSince($0.date) > HistoryRange.oneHour.duration }

        let expectedInterval = Double(netSpeedUpdateInterval.rawValue)
        let seconds = min(now.timeIntervalSince(lastSampleDate ?? now), expectedInterval * 2)
        lastSampleDate = now
        sessionUploadedBytes += speeds.upload.bytesPerSecond * seconds
        sessionDownloadedBytes += speeds.download.bytesPerSecond * seconds
        if speeds.upload.bytesPerSecond > peakUpload.bytesPerSecond { peakUpload = speeds.upload }
        if speeds.download.bytesPerSecond > peakDownload.bytesPerSecond { peakDownload = speeds.download }
    }

    private func currentAutoLaunchStatus() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func updateAutoLaunchStatus() {
        let service = SMAppService.mainApp
        do {
            if autoLaunchEnabled, service.status != .enabled {
                try service.register()
            } else if !autoLaunchEnabled, service.status == .enabled {
                try service.unregister()
            }
        } catch {
            logger.warning("Could not update launch-at-login: \(error.localizedDescription)")
            autoLaunchEnabled = currentAutoLaunchStatus()
        }
    }

    private func animateActivityMeters() {
        activityAnimationTimer?.invalidate()
        let targetUpload = speeds.upload.activityLevel
        let targetDownload = speeds.download.activityLevel
        let startUpload = displayedUploadActivity
        let startDownload = displayedDownloadActivity

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            displayedUploadActivity = targetUpload
            displayedDownloadActivity = targetDownload
            updateIndicatorImage()
            return
        }

        let startTime = Date()
        let animationTimer = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                let progress = min(Date().timeIntervalSince(startTime) / 0.3, 1)
                let eased = 1 - pow(1 - progress, 3)
                self.displayedUploadActivity = startUpload + (targetUpload - startUpload) * eased
                self.displayedDownloadActivity = startDownload + (targetDownload - startDownload) * eased
                self.updateIndicatorImage()
                if progress >= 1 {
                    timer.invalidate()
                    self.activityAnimationTimer = nil
                }
            }
        }
        activityAnimationTimer = animationTimer
        RunLoop.main.add(animationTimer, forMode: .common)
    }

    private func updateIndicatorImage() {
        indicatorImage = MenuBarIconGenerator.generateIcon(
            speeds: speeds,
            uploadActivity: displayedUploadActivity,
            downloadActivity: displayedDownloadActivity
        )
    }
}
