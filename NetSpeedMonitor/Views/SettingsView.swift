import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsForm()
            .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 480, height: 290)
    }
}

struct DashboardSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.largeTitle.bold())
                Text("Configure monitoring, startup, and how Network Pulse appears.")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)

            GeneralSettingsForm()
        }
    }
}

private struct GeneralSettingsForm: View {
    @EnvironmentObject private var monitor: MenuBarState

    var body: some View {
        Form {
            Section("Monitoring") {
                Picker("Update interval", selection: $monitor.netSpeedUpdateInterval) {
                    ForEach(NetSpeedUpdateInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }

                Picker("Network interface", selection: $monitor.selectedInterface) {
                    Text("Automatic (busiest)").tag(MenuBarState.automaticInterface)
                    ForEach(monitor.availableInterfaceNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }

                Toggle("Save traffic history", isOn: $monitor.saveTrafficHistory)
                Text("Keeps attributed traffic for seven days. Turning this off retains existing history until it expires or is deleted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch Network Pulse at login", isOn: $monitor.autoLaunchEnabled)
            }

            Section("Appearance") {
                Toggle("Show Dock icon", isOn: $monitor.showDockIcon)
                Text("When hidden, open the dashboard from the Network Pulse menu-bar icon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
