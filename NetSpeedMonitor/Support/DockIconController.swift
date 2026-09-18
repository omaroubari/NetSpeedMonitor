import AppKit

@MainActor
enum DockIconController {
    static let preferenceKey = "ShowDockIcon"

    static func applyPreference(activate: Bool = false) {
        let shouldShow = UserDefaults.standard.bool(forKey: preferenceKey)
        let policy: NSApplication.ActivationPolicy = shouldShow ? .regular : .accessory
        NSApp.setActivationPolicy(policy)

        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
