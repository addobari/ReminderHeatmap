import SwiftUI

struct NewReminderView: View {
    @ObservedObject var manager: ReminderManager
    var prefilledTitle: String = ""
    var prefilledListIdentifier: String? = nil
    /// When set, the sheet operates in edit mode against this reminder.
    var editing: ReminderManager.EditableReminder? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var listID: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Self.defaultDueDate()
    @State private var recurrence: ReminderManager.RecurrenceOption = .none
    @State private var saving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var confirmDelete: Bool = false
    @FocusState private var titleFocused: Bool

    private var isEditMode: Bool { editing != nil }

    private var availableLists: [ReminderListInfo] {
        manager.availableLists
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !listID.isEmpty
        && !saving
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text(isEditMode ? "Edit reminder" : "New reminder")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 14)

            Divider().opacity(0.4)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Title
                    field(label: "TITLE") {
                        TextField("e.g. Drink water", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .focused($titleFocused)
                            .onSubmit { if canSave { Task { await save() } } }
                    }

                    // List picker
                    field(label: "LIST") {
                        if availableLists.isEmpty {
                            Text("No lists available")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("", selection: $listID) {
                                ForEach(availableLists) { list in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(ListColorPalette.color(for: list.colorIndex))
                                            .frame(width: 8, height: 8)
                                        Text(list.title)
                                    }
                                    .tag(list.identifier)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }

                    // Due date
                    field(label: "DUE") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $hasDueDate) {
                                Text(hasDueDate ? "Has a due date" : "No due date")
                                    .font(.system(size: 13))
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)

                            if hasDueDate {
                                DatePicker(
                                    "",
                                    selection: $dueDate,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                            }
                        }
                    }

                    // Repeat
                    field(label: "REPEAT") {
                        Picker("", selection: $recurrence) {
                            ForEach(ReminderManager.RecurrenceOption.allCases) { opt in
                                Text(opt.label).tag(opt)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    // Notes
                    field(label: "NOTES") {
                        TextEditor(text: $notes)
                            .font(.system(size: 13))
                            .frame(minHeight: 60)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(HeatmapTheme.cardBackground(for: colorScheme))
                            )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }

            Divider().opacity(0.4)

            HStack {
                if isEditMode {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
                Spacer()
                Button(isEditMode ? "Save changes" : "Save") {
                    Task { await save() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
        .frame(width: 440, height: 580)
        .onAppear {
            if let editing {
                title = editing.title
                listID = editing.calendarIdentifier
                hasDueDate = editing.dueDate != nil
                if let d = editing.dueDate { dueDate = d }
                recurrence = editing.recurrence
                notes = editing.notes
            } else {
                title = prefilledTitle
                if listID.isEmpty {
                    listID = prefilledListIdentifier
                        ?? availableLists.first?.identifier
                        ?? ""
                }
            }
            DispatchQueue.main.async { titleFocused = true }
        }
        .alert("Delete this reminder?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await delete() }
            }
        } message: {
            Text("This will remove it from Apple Reminders everywhere it syncs. This action can't be undone.")
        }
    }

    @ViewBuilder
    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func save() async {
        saving = true
        errorMessage = nil
        let ok: Bool
        if let editing {
            let updated = ReminderManager.EditableReminder(
                id: editing.id,
                title: title,
                calendarIdentifier: listID,
                dueDate: hasDueDate ? dueDate : nil,
                recurrence: recurrence,
                notes: notes
            )
            ok = await manager.updateReminder(updated)
        } else {
            ok = await manager.createReminder(
                title: title,
                calendarIdentifier: listID,
                dueDate: hasDueDate ? dueDate : nil,
                recurrence: recurrence,
                notes: notes.isEmpty ? nil : notes
            )
        }
        saving = false
        if ok {
            dismiss()
        } else {
            errorMessage = isEditMode
                ? "Couldn't save changes. The reminder may have been deleted or the list isn't writable."
                : "Couldn't save the reminder. Check that the list is writable."
        }
    }

    private func delete() async {
        guard let editing else { return }
        saving = true
        errorMessage = nil
        let ok = await manager.deleteReminder(reminderID: editing.id)
        saving = false
        if ok {
            dismiss()
        } else {
            errorMessage = "Couldn't delete the reminder."
        }
    }

    private static func defaultDueDate() -> Date {
        let cal = Calendar.current
        let now = Date()
        // Default to 9am tomorrow.
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now) else { return now }
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}
