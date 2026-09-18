import Foundation

enum NetSpeedUpdateInterval: Int, CaseIterable, Identifiable {
    case oneSecond = 1
    case twoSeconds = 2
    case fiveSeconds = 5
    case tenSeconds = 10
    case thirtySeconds = 30

    var id: Int { rawValue }
    var displayName: String { "\(rawValue)s" }
}

enum HistoryRange: Int, CaseIterable, Identifiable {
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case oneHour = 60

    var id: Int { rawValue }
    var displayName: String {
        switch self {
        case .fiveMinutes: "5 min"
        case .fifteenMinutes: "15 min"
        case .oneHour: "1 hour"
        }
    }

    var duration: TimeInterval { TimeInterval(rawValue * 60) }
}

enum MonitorStatus: Equatable {
    case warmingUp
    case monitoring
    case paused
    case unavailable

    var title: String {
        switch self {
        case .warmingUp: "Starting"
        case .monitoring: "Live"
        case .paused: "Paused"
        case .unavailable: "Unavailable"
        }
    }

    var systemImage: String {
        switch self {
        case .warmingUp: "ellipsis"
        case .monitoring: "circle.fill"
        case .paused: "pause.circle.fill"
        case .unavailable: "exclamationmark.triangle.fill"
        }
    }
}

struct NetworkSpeed: Equatable {
    let bytesPerSecond: Double

    static let zero = NetworkSpeed(bytesPerSecond: 0)

    var value: Double { Self.scaled(bytesPerSecond).value }
    var unit: String { Self.scaled(bytesPerSecond).unit }

    var displayValue: String {
        switch value {
        case ..<10: String(format: "%.2f", value)
        case ..<100: String(format: "%.1f", value)
        default: String(format: "%.0f", value)
        }
    }

    var formatted: String { "\(displayValue) \(unit)/s" }

    var activityLevel: Double {
        guard bytesPerSecond >= 1_024 else { return 0 }
        return min(max((log10(bytesPerSecond) - 3) / 5, 0), 1)
    }

    var accessibilityText: String { "\(displayValue) \(unit) per second" }

    private static func scaled(_ bytes: Double) -> (value: Double, unit: String) {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = max(bytes, 0)
        var unitIndex = 0
        while value >= 1_024, unitIndex < units.count - 1 {
            value /= 1_024
            unitIndex += 1
        }
        return (value, units[unitIndex])
    }
}

struct NetworkSpeeds: Equatable {
    let upload: NetworkSpeed
    let download: NetworkSpeed

    static let zero = NetworkSpeeds(upload: .zero, download: .zero)
}

struct NetworkSample: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let uploadBytesPerSecond: Double
    let downloadBytesPerSecond: Double
}

struct InterfaceReading: Identifiable, Equatable {
    let name: String
    let speeds: NetworkSpeeds
    var id: String { name }
}
