import SwiftUI

struct MilestoneCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let trackerSummaries: [TrackerSummary]
    var existingMilestone: Milestone?
    var onSave: (Milestone) -> Void
    var onDelete: (() -> Void)?

    @State private var name: String = ""
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var why: String = ""
    @State private var selectedReminders: Set<String> = [] // LinkedReminder.id values
    @State private var showDeleteConfirm = false

    init(trackerSummaries: [TrackerSummary], existing: Milestone? = nil, onSave: @escaping (Milestone) -> Void, onDelete: (() -> Void)? = nil) {
        self.trackerSummaries = trackerSummaries
        self.existingMilestone = existing
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existingMilestone == nil ? "New Goal" : "Edit Goal")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
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
                Section {
                    TextField("Goal name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.body.weight(.medium))

                    DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                } header: {
                    Text("WHAT")
                        .font(HeatmapTheme.sectionTitle)
                        .tracking(0.5)
                }

                Section {
                    TextField("Why does this matter to you?", text: $why, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2...4)
                } header: {
                    Text("WHY")
                        .font(HeatmapTheme.sectionTitle)
                        .tracking(0.5)
                } footer: {
                    Text("The second-order impact — what this unlocks for you")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Section {
                    if trackerSummaries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No recurring reminders found")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                            Text("Create a repeating reminder in Apple Reminders, then come back here to link it.")
                                .font(.caption)
                                .foregroundStyle(.quaternary)
                            Button {
                                NSWorkspace.shared.open(URL(string: "x-apple-reminderkit://")!)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.forward.app")
                                        .font(.caption)
                                    Text("Open Reminders")
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        ForEach(trackerSummaries) { summary in
                            let linkId = summary.calendarIdentifier + ":" + summary.reminderTitle
                            let isSelected = selectedReminders.contains(linkId)
                            Button {
                                if isSelected {
                                    selectedReminders.remove(linkId)
                                } else {
                                    selectedReminders.insert(linkId)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isSelected ? HeatmapTheme.accentGreen(for: colorScheme) : .secondary)
                                        .font(.body)
                                    Circle()
                                        .fill(ListColorPalette.color(for: summary.calendarColorIndex))
                                        .frame(width: 7, height: 7)
                                    Text(summary.reminderTitle)
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(summary.calendarTitle)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HStack {
                        Text("LINKED HABITS")
                            .font(HeatmapTheme.sectionTitle)
                            .tracking(0.5)
                        if !selectedReminders.isEmpty {
                            Text("(\(selectedReminders.count))")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                    }
                } footer: {
                    Text("Which recurring reminders feed into this goal?")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if existingMilestone != nil, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Goal")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            // Save button
            Button {
                let linked = trackerSummaries
                    .filter { selectedReminders.contains($0.calendarIdentifier + ":" + $0.reminderTitle) }
                    .map { Milestone.LinkedReminder(
                        calendarIdentifier: $0.calendarIdentifier,
                        reminderTitle: $0.reminderTitle,
                        calendarTitle: $0.calendarTitle
                    )}

                let milestone = Milestone(
                    id: existingMilestone?.id ?? UUID(),
                    name: name,
                    targetDate: targetDate,
                    why: why,
                    linkedReminders: linked,
                    reflection: existingMilestone?.reflection,
                    createdAt: existingMilestone?.createdAt ?? Date()
                )
                onSave(milestone)
                dismiss()
            } label: {
                Text(existingMilestone == nil ? "Create Goal" : "Save")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(name.isEmpty ? Color.gray : HeatmapTheme.accentGreen(for: colorScheme), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(name.isEmpty)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 420, height: 540)
        .onAppear {
            if let m = existingMilestone {
                name = m.name
                targetDate = m.targetDate
                why = m.why
                selectedReminders = Set(m.linkedReminders.map(\.id))
            }
        }
        .alert("Delete this goal?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
