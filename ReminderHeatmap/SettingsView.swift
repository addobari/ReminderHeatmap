import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: ReminderManager

    @AppStorage("dailyGoal") private var dailyGoal: Int = 5
    @AppStorage("streakFreezeEnabled") private var streakFreezeEnabled: Bool = true
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    @AppStorage("trackerSortMode") private var trackerSortModeRaw: String = TrackerSortMode.count.rawValue
    @AppStorage(ExcludedListsStore.key) private var excludedListIDsCSV: String = ""

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

                Section {
                    Picker("Sort trackers", selection: $trackerSortModeRaw) {
                        ForEach(TrackerSortMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.icon).tag(mode.rawValue)
                        }
                    }
                } header: {
                    Text("Trackers")
                }

                Section {
                    if manager.availableLists.isEmpty {
                        Text("No reminder lists found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(manager.availableLists) { list in
                            Toggle(isOn: includeBinding(for: list.identifier)) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(ListColorPalette.color(for: list.colorIndex))
                                        .frame(width: 8, height: 8)
                                    Text(list.title)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Included Lists")
                } footer: {
                    Text("Turn a list off to exclude it from the heatmap, trackers, and stats.")
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
        .frame(width: 420, height: 560)
        .task {
            // Make sure we have a fresh list of reminder lists when Settings opens.
            if manager.availableLists.isEmpty {
                manager.availableLists = await HeatmapData.shared.availableLists()
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    // MARK: - List include/exclude binding

    private func includeBinding(for identifier: String) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                !currentExcludedSet().contains(identifier)
            },
            set: { include in
                var set = currentExcludedSet()
                if include {
                    set.remove(identifier)
                } else {
                    set.insert(identifier)
                }
                excludedListIDsCSV = set.sorted().joined(separator: ",")
                // Trigger a refresh so the rest of the app reflects the change.
                manager.markNeedsRefresh()
                Task { await manager.refreshIfNeeded() }
            }
        )
    }

    private func currentExcludedSet() -> Set<String> {
        Set(excludedListIDsCSV.split(separator: ",").map { String($0) }.filter { !$0.isEmpty })
    }
}
