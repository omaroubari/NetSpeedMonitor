import AppKit
import Foundation
import SwiftData

@ModelActor
actor TrafficHistoryDatabase {
    private struct AggregateKey: Hashable {
        let interfaceName: String
        let bucketStart: Date
    }

    private struct Aggregate {
        var receivedBytes: Int64 = 0
        var sentBytes: Int64 = 0
        var peakDownloadBytesPerSecond = 0.0
        var peakUploadBytesPerSecond = 0.0
        var observedDuration = 0.0
        var sampleCount = 0

        mutating func add(_ record: TrafficHistoryRecord) {
            receivedBytes += record.receivedBytes
            sentBytes += record.sentBytes
            peakDownloadBytesPerSecond = max(
                peakDownloadBytesPerSecond,
                record.peakDownloadBytesPerSecond
            )
            peakUploadBytesPerSecond = max(
                peakUploadBytesPerSecond,
                record.peakUploadBytesPerSecond
            )
            observedDuration += record.observedDuration
            sampleCount += record.sampleCount
        }
    }

    func insert(_ measurements: [TrafficMeasurement]) throws {
        guard !measurements.isEmpty else { return }

        for measurement in measurements {
            let bucketStart = Self.alignedStart(for: measurement.date, duration: 1)
            let key = Self.storageKey(
                interfaceName: measurement.interfaceName,
                resolution: .raw,
                bucketStart: bucketStart
            )
            var descriptor = FetchDescriptor<TrafficHistoryRecord>(
                predicate: #Predicate { $0.storageKey == key }
            )
            descriptor.fetchLimit = 1

            if let existing = try modelContext.fetch(descriptor).first {
                existing.receivedBytes += measurement.receivedBytes
                existing.sentBytes += measurement.sentBytes
                existing.peakDownloadBytesPerSecond = max(
                    existing.peakDownloadBytesPerSecond,
                    measurement.downloadBytesPerSecond
                )
                existing.peakUploadBytesPerSecond = max(
                    existing.peakUploadBytesPerSecond,
                    measurement.uploadBytesPerSecond
                )
                existing.observedDuration += measurement.observedDuration
                existing.sampleCount += 1
            } else {
                modelContext.insert(TrafficHistoryRecord(
                    storageKey: key,
                    bucketStart: bucketStart,
                    interfaceName: measurement.interfaceName,
                    resolution: .raw,
                    receivedBytes: measurement.receivedBytes,
                    sentBytes: measurement.sentBytes,
                    peakDownloadBytesPerSecond: measurement.downloadBytesPerSecond,
                    peakUploadBytesPerSecond: measurement.uploadBytesPerSecond,
                    observedDuration: measurement.observedDuration,
                    sampleCount: 1
                ))
            }
        }

        try modelContext.save()
    }

    func compact(now: Date) throws {
        let rawCutoff = now.addingTimeInterval(-60 * 60)
        let hourlyCutoff = now.addingTimeInterval(-24 * 60 * 60)
        let retentionCutoff = now.addingTimeInterval(-7 * 24 * 60 * 60)

        try rollUp(
            source: .raw,
            olderThan: rawCutoff,
            target: .oneHour,
            targetDuration: TrafficHistoryResolution.oneHour.duration
        )
        try rollUp(
            source: .oneHour,
            olderThan: hourlyCutoff,
            target: .threeHours,
            targetDuration: TrafficHistoryResolution.threeHours.duration
        )

        let expiryCandidates = try modelContext.fetch(FetchDescriptor<TrafficHistoryRecord>(
            predicate: #Predicate { $0.bucketStart < retentionCutoff }
        ))
        for record in expiryCandidates {
            let interval = record.resolution.duration
            if record.bucketStart.addingTimeInterval(interval) <= retentionCutoff {
                modelContext.delete(record)
            }
        }
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    func history(
        interfaceName: String,
        range: HistoryRange,
        now: Date
    ) throws -> [TrafficHistoryPoint] {
        try compact(now: now)

        let cutoff = now.addingTimeInterval(-range.duration)
        let earliestOverlappingBucket = cutoff.addingTimeInterval(
            -TrafficHistoryResolution.threeHours.duration
        )
        let records = try modelContext.fetch(FetchDescriptor<TrafficHistoryRecord>(
            predicate: #Predicate {
                $0.interfaceName == interfaceName && $0.bucketStart >= earliestOverlappingBucket
            }
        ))
        .filter {
            $0.bucketStart.addingTimeInterval($0.resolution.duration) > cutoff
        }
        let recordsByKey = Dictionary(uniqueKeysWithValues: records.map {
            (Self.storageKey(
                interfaceName: $0.interfaceName,
                resolution: $0.resolution,
                bucketStart: $0.bucketStart
            ), $0)
        })

        var points: [TrafficHistoryPoint] = []
        let rawStart = max(cutoff, now.addingTimeInterval(-60 * 60))
        appendPoints(
            to: &points,
            interfaceName: interfaceName,
            resolution: .raw,
            start: rawStart,
            end: now,
            recordsByKey: recordsByKey
        )

        if range.duration > 60 * 60 {
            let hourlyStart = max(cutoff, now.addingTimeInterval(-24 * 60 * 60))
            let hourlyEnd = min(now.addingTimeInterval(-60 * 60), now)
            appendPoints(
                to: &points,
                interfaceName: interfaceName,
                resolution: .oneHour,
                start: hourlyStart,
                end: hourlyEnd,
                recordsByKey: recordsByKey
            )
        }

        if range.duration > 24 * 60 * 60 {
            appendPoints(
                to: &points,
                interfaceName: interfaceName,
                resolution: .threeHours,
                start: cutoff,
                end: now.addingTimeInterval(-24 * 60 * 60),
                recordsByKey: recordsByKey
            )
        }

        return points.sorted { $0.date < $1.date }
    }

    func interfaces(now: Date) throws -> [TrafficHistoryInterface] {
        let cutoff = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let earliestOverlappingBucket = cutoff.addingTimeInterval(
            -TrafficHistoryResolution.threeHours.duration
        )
        let recentCutoff = now.addingTimeInterval(-60 * 60)
        let records = try modelContext.fetch(FetchDescriptor<TrafficHistoryRecord>(
            predicate: #Predicate { $0.bucketStart >= earliestOverlappingBucket }
        ))
        .filter {
            $0.bucketStart.addingTimeInterval($0.resolution.duration) > cutoff
        }

        var latestActivity: [String: Date] = [:]
        var recentBytes: [String: Int64] = [:]
        for record in records {
            latestActivity[record.interfaceName] = max(
                latestActivity[record.interfaceName] ?? .distantPast,
                record.bucketStart
            )
            if record.bucketStart >= recentCutoff {
                recentBytes[record.interfaceName, default: 0] +=
                    record.receivedBytes + record.sentBytes
            }
        }

        return latestActivity.map { name, latest in
            TrafficHistoryInterface(
                name: name,
                latestActivity: latest,
                recentTransferredBytes: recentBytes[name, default: 0]
            )
        }
        .sorted {
            if $0.recentTransferredBytes != $1.recentTransferredBytes {
                return $0.recentTransferredBytes > $1.recentTransferredBytes
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func deleteAll() throws {
        try modelContext.delete(model: TrafficHistoryRecord.self)
        try modelContext.save()
    }

    private func rollUp(
        source: TrafficHistoryResolution,
        olderThan cutoff: Date,
        target: TrafficHistoryResolution,
        targetDuration: TimeInterval
    ) throws {
        let sourceRawValue = source.rawValue
        let sourceRecords = try modelContext.fetch(FetchDescriptor<TrafficHistoryRecord>(
            predicate: #Predicate {
                $0.resolutionRawValue == sourceRawValue && $0.bucketStart < cutoff
            }
        ))
        guard !sourceRecords.isEmpty else { return }

        var aggregates: [AggregateKey: Aggregate] = [:]
        for record in sourceRecords {
            let key = AggregateKey(
                interfaceName: record.interfaceName,
                bucketStart: Self.alignedStart(for: record.bucketStart, duration: targetDuration)
            )
            aggregates[key, default: Aggregate()].add(record)
        }

        for (aggregateKey, aggregate) in aggregates {
            let key = Self.storageKey(
                interfaceName: aggregateKey.interfaceName,
                resolution: target,
                bucketStart: aggregateKey.bucketStart
            )
            var descriptor = FetchDescriptor<TrafficHistoryRecord>(
                predicate: #Predicate { $0.storageKey == key }
            )
            descriptor.fetchLimit = 1

            if let existing = try modelContext.fetch(descriptor).first {
                existing.receivedBytes += aggregate.receivedBytes
                existing.sentBytes += aggregate.sentBytes
                existing.peakDownloadBytesPerSecond = max(
                    existing.peakDownloadBytesPerSecond,
                    aggregate.peakDownloadBytesPerSecond
                )
                existing.peakUploadBytesPerSecond = max(
                    existing.peakUploadBytesPerSecond,
                    aggregate.peakUploadBytesPerSecond
                )
                existing.observedDuration += aggregate.observedDuration
                existing.sampleCount += aggregate.sampleCount
            } else {
                modelContext.insert(TrafficHistoryRecord(
                    storageKey: key,
                    bucketStart: aggregateKey.bucketStart,
                    interfaceName: aggregateKey.interfaceName,
                    resolution: target,
                    receivedBytes: aggregate.receivedBytes,
                    sentBytes: aggregate.sentBytes,
                    peakDownloadBytesPerSecond: aggregate.peakDownloadBytesPerSecond,
                    peakUploadBytesPerSecond: aggregate.peakUploadBytesPerSecond,
                    observedDuration: aggregate.observedDuration,
                    sampleCount: aggregate.sampleCount
                ))
            }
        }

        for record in sourceRecords {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    private func appendPoints(
        to points: inout [TrafficHistoryPoint],
        interfaceName: String,
        resolution: TrafficHistoryResolution,
        start: Date,
        end: Date,
        recordsByKey: [String: TrafficHistoryRecord]
    ) {
        guard start < end else { return }
        let interval = resolution.duration
        var cursor = Self.alignedStart(for: start, duration: interval)

        while cursor < end {
            let key = Self.storageKey(
                interfaceName: interfaceName,
                resolution: resolution,
                bucketStart: cursor
            )
            if let record = recordsByKey[key] {
                points.append(TrafficHistoryPoint(
                    date: cursor,
                    interval: resolution == .raw
                        ? max(record.observedDuration, 1)
                        : interval,
                    receivedBytes: record.receivedBytes,
                    sentBytes: record.sentBytes,
                    peakDownloadBytesPerSecond: record.peakDownloadBytesPerSecond,
                    peakUploadBytesPerSecond: record.peakUploadBytesPerSecond,
                    sampleCount: record.sampleCount
                ))
            } else {
                points.append(TrafficHistoryPoint(
                    date: cursor,
                    interval: interval,
                    receivedBytes: 0,
                    sentBytes: 0,
                    peakDownloadBytesPerSecond: 0,
                    peakUploadBytesPerSecond: 0,
                    sampleCount: 0
                ))
            }
            cursor = cursor.addingTimeInterval(interval)
        }
    }

    private static func alignedStart(for date: Date, duration: TimeInterval) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / duration) * duration)
    }

    private static func storageKey(
        interfaceName: String,
        resolution: TrafficHistoryResolution,
        bucketStart: Date
    ) -> String {
        "\(resolution.rawValue)|\(interfaceName)|\(Int64(bucketStart.timeIntervalSince1970))"
    }
}

@MainActor
final class TrafficHistoryStore: ObservableObject {
    @Published private(set) var interfaces: [TrafficHistoryInterface] = []
    @Published private(set) var hasLoadedInterfaces = false
    @Published private(set) var revision = 0
    @Published private(set) var persistenceAvailable = true

    private let database: TrafficHistoryDatabase?
    private var pendingMeasurements: [TrafficMeasurement] = []
    private var flushTimer: Timer?
    private var compactionTimer: Timer?
    private var terminationObserver: NSObjectProtocol?
    private var savingEnabled = true

    init() {
        do {
            let container = try ModelContainer(for: TrafficHistoryRecord.self)
            database = TrafficHistoryDatabase(modelContainer: container)
        } catch {
            database = nil
            persistenceAvailable = false
            hasLoadedInterfaces = true
            logger.error("Could not open traffic history store: \(error.localizedDescription)")
        }

        let flushTimer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.flush() }
        }
        RunLoop.main.add(flushTimer, forMode: .common)
        self.flushTimer = flushTimer

        let compactionTimer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.compactAndRefresh() }
        }
        RunLoop.main.add(compactionTimer, forMode: .common)
        self.compactionTimer = compactionTimer

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.flush() }
        }

        Task { await compactAndRefresh() }
    }

    deinit {
        flushTimer?.invalidate()
        compactionTimer?.invalidate()
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }

    func setSavingEnabled(_ enabled: Bool) {
        if savingEnabled, !enabled {
            flush()
        }
        savingEnabled = enabled
    }

    func record(_ readings: [InterfaceReading], at date: Date) {
        guard savingEnabled, database != nil else { return }

        pendingMeasurements.append(contentsOf: readings.compactMap { reading in
            let receivedBytes = max(reading.receivedBytes, 0)
            let sentBytes = max(reading.sentBytes, 0)
            guard receivedBytes > 0 || sentBytes > 0 else { return nil }
            return TrafficMeasurement(
                date: date,
                interfaceName: reading.name,
                receivedBytes: receivedBytes,
                sentBytes: sentBytes,
                downloadBytesPerSecond: reading.speeds.download.bytesPerSecond,
                uploadBytesPerSecond: reading.speeds.upload.bytesPerSecond,
                observedDuration: max(reading.sampleDuration, 0)
            )
        })
    }

    func history(interfaceName: String, range: HistoryRange) async -> [TrafficHistoryPoint] {
        await flushPending()
        guard let database else { return [] }
        do {
            return try await database.history(
                interfaceName: interfaceName,
                range: range,
                now: Date()
            )
        } catch {
            handle(error, operation: "load history")
            return []
        }
    }

    func deleteSavedHistory() async {
        pendingMeasurements.removeAll()
        guard let database else { return }
        do {
            try await database.deleteAll()
            interfaces = []
            hasLoadedInterfaces = true
            revision += 1
        } catch {
            handle(error, operation: "delete history")
        }
    }

    func flush() {
        Task { await flushPending() }
    }

    private func flushPending() async {
        guard let database, !pendingMeasurements.isEmpty else { return }
        let measurements = pendingMeasurements
        pendingMeasurements.removeAll(keepingCapacity: true)
        do {
            try await database.insert(measurements)
            await refreshInterfaces()
            revision += 1
        } catch {
            handle(error, operation: "save history")
        }
    }

    private func compactAndRefresh() async {
        guard let database else { return }
        do {
            try await database.compact(now: Date())
            await refreshInterfaces()
            revision += 1
        } catch {
            handle(error, operation: "compact history")
        }
    }

    private func refreshInterfaces() async {
        guard let database else { return }
        do {
            interfaces = try await database.interfaces(now: Date())
            hasLoadedInterfaces = true
        } catch {
            hasLoadedInterfaces = true
            handle(error, operation: "load history interfaces")
        }
    }

    private func handle(_ error: Error, operation: String) {
        persistenceAvailable = false
        logger.error("Could not \(operation): \(error.localizedDescription)")
    }
}
