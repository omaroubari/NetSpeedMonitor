import AppKit
import OSLog

let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.elegracer.NetSpeedMonitor",
    category: "network-monitor"
)

enum AppActions {
    static func openActivityMonitor() {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.ActivityMonitor"
        ) else {
            logger.warning("Activity Monitor could not be found")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            if let error {
                logger.warning("Could not open Activity Monitor: \(error.localizedDescription)")
            }
        }
    }
}

enum NetworkValueFormatter {
    static func bytes(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(max(value, 0)), countStyle: .file)
    }

    static func rate(_ value: Double) -> String {
        NetworkSpeed(bytesPerSecond: value).formatted
    }
}
