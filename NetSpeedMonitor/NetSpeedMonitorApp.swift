import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DockIconController.applyPreference(activate: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct NetSpeedMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var historyStore: TrafficHistoryStore
    @StateObject private var monitor: MenuBarState

    init() {
        let historyStore = TrafficHistoryStore()
        _historyStore = StateObject(wrappedValue: historyStore)
        _monitor = StateObject(wrappedValue: MenuBarState(historyStore: historyStore))
    }

    var body: some Scene {
        WindowGroup("Network Pulse", id: "dashboard") {
            DashboardRootView()
                .environmentObject(monitor)
                .environmentObject(historyStore)
        }
        .defaultSize(width: 900, height: 650)
        .commands {
            CommandMenu("Monitor") {
                Button(monitor.isPaused ? "Resume Monitoring" : "Pause Monitoring") {
                    monitor.toggleMonitoring()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Clear Session History") {
                    monitor.clearSession()
                }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])

                Divider()

                Button("Open Activity Monitor", action: AppActions.openActivityMonitor)
            }
        }

        MenuBarExtra {
            MenuContentView()
                .environmentObject(monitor)
        } label: {
            Image(nsImage: monitor.indicatorImage)
                .accessibilityLabel(monitor.accessibilityLabel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(monitor)
                .environmentObject(historyStore)
        }
    }
}
