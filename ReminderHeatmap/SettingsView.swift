import SwiftUI

struct SettingsView: View {
    @AppStorage("dailyGoal") private var dailyGoal: Int = 5
    @AppStorage("streakFreezeEnabled") private var streakFreezeEnabled: Bool = true
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title3.bold())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Form {
                Section("Goals") {
                    Stepper(value: $dailyGoal, in: 1...20) {
                        HStack {
                            Text("Daily goal")
                            Spacer()
                            Text("\(dailyGoal) tasks")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Section {
                    Toggle(isOn: $streakFreezeEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Streak freeze")
                            Text("Allow 1 skip day without breaking your streak")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Streaks")
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        NSWorkspace.shared.open(URL(string: "https://github.com/addobari/ReminderHeatmap")!)
                    } label: {
                        HStack {
                            Text("GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 380, height: 420)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
