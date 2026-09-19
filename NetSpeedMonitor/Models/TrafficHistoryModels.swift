import Foundation
import SwiftData

enum TrafficHistoryResolution: Int, Codable, Sendable {
    case raw = 0
    case oneHour = 1
    case threeHours = 2

    var duration: TimeInterval {
        switch self {
        case .raw: 1
        case .oneHour: 60 * 60
        case .threeHours: 3 * 60 * 60
        }
    }
}

@Model
final class TrafficHistoryRecord {
    @Attribute(.unique) var storageKey: String
    var bucketStart: Date
    var interfaceName: String
    var resolutionRawValue: Int
    var receivedBytes: Int64
    var sentBytes: Int64
    var peakDownloadBytesPerSecond: Double
    var peakUploadBytesPerSecond: Double
    var observedDuration: Double
    var sampleCount: Int

    init(
        storageKey: String,
        bucketStart: Date,
        interfaceName: String,
        resolution: TrafficHistoryResolution,
        receivedBytes: Int64,
        sentBytes: Int64,
        peakDownloadBytesPerSecond: Double,
        peakUploadBytesPerSecond: Double,
        observedDuration: Double,
        sampleCount: Int
    ) {
        self.storageKey = storageKey
        self.bucketStart = bucketStart
        self.interfaceName = interfaceName
        self.resolutionRawValue = resolution.rawValue
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.peakDownloadBytesPerSecond = peakDownloadBytesPerSecond
        self.peakUploadBytesPerSecond = peakUploadBytesPerSecond
        self.observedDuration = observedDuration
        self.sampleCount = sampleCount
    }

    var resolution: TrafficHistoryResolution {
        TrafficHistoryResolution(rawValue: resolutionRawValue) ?? .raw
    }
}

struct TrafficMeasurement: Sendable {
    let date: Date
    let interfaceName: String
    let receivedBytes: Int64
    let sentBytes: Int64
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
    let observedDuration: TimeInterval
}

struct TrafficHistoryPoint: Identifiable, Equatable, Sendable {
    let date: Date
    let interval: TimeInterval
    let receivedBytes: Int64
    let sentBytes: Int64
    let peakDownloadBytesPerSecond: Double
    let peakUploadBytesPerSecond: Double
    let sampleCount: Int

    var id: Date { date }
    var downloadBytesPerSecond: Double {
        interval > 0 ? Double(receivedBytes) / interval : 0
    }
    var uploadBytesPerSecond: Double {
        interval > 0 ? Double(sentBytes) / interval : 0
    }
}

struct TrafficHistoryInterface: Identifiable, Equatable, Sendable {
    let name: String
    let latestActivity: Date
    let recentTransferredBytes: Int64

    var id: String { name }
    var displayName: String { NetworkInterfaceName.displayName(for: name) }
}

enum NetworkInterfaceName {
    static func displayName(for name: String) -> String {
        if name.hasPrefix("utun") {
            return "VPN / Tunnel (\(name))"
        }
        if name.hasPrefix("en") {
            return "Network (\(name))"
        }
        if name.hasPrefix("bridge") {
            return "Bridge (\(name))"
        }
        if name.hasPrefix("awdl") || name.hasPrefix("llw") {
            return "Apple peer-to-peer (\(name))"
        }
        return name
    }
}

