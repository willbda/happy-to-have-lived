//
// TermFormView.swift
// Written by Claude Code on 2025-11-02
// Rewritten by Claude Code on 2025-11-03 to follow Apple's SwiftUI patterns
// Updated by Claude Code on 2025-11-16 - Migrated to canonical TimePeriodData
// Refactored by Claude Code on 2025-11-20 - Uses DataStore + unified error alerts
//
// PURPOSE: User-friendly form for creating/editing Terms (10-week planning periods)
// PATTERN: Local @State fields + DataStore (operations) + View+ErrorAlert (errors)
//
// DATA FLOW:
// 1. User edits local @State fields (termNumber, dates, theme)
// 2. Save button calls dataStore.createTerm()
// 3. DataStore ValueObservation automatically updates list views
// 4. Errors display via .errorAlert(dataStore:) modifier
//

import Models
import Services
import SwiftUI

/// Form for creating or editing a Term (10-week planning period).
///
/// ARCHITECTURE DECISION: Type-Specific View + Generic ViewModel
/// - View is user-friendly (says "Term", not "Time Period")
/// - Wraps TimePeriodFormViewModel with pre-configured specialization = .term(number)
/// - User never sees "Time Period" or "Specialization" in UI
/// - Supports both create (termToEdit = nil) and edit (termToEdit != nil) modes
///
/// PATTERN: Apple's direct Form approach
/// - Form directly inside NavigationStack
/// - Navigation modifiers applied to Form itself
/// - Toolbar buttons defined inline
public struct TermFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataStore.self) private var dataStore

    @State private var isSaving = false

    // MARK: - Edit Mode Support

    /// Term being edited (nil = create mode, not nil = edit mode)
    private let termToEdit: TimePeriodData?

    /// Suggested next term number (from TermsListView's data)
    /// Used only in create mode to auto-increment from existing terms
    private let suggestedTermNumber: Int?

    /// Whether in create or edit mode
    private var isEditMode: Bool {
        termToEdit != nil
    }

    /// Form title based on mode
    private var formTitle: String {
        isEditMode ? "Edit Term" : "New Term"
    }

    // Term-specific fields
    @State private var termNumber: Int
    @State private var startDate: Date
    @State private var targetDate: Date
    @State private var theme: String
    @State private var reflection: String
    @State private var status: TermStatus

    // Generic TimePeriod fields
    @State private var title: String
    @State private var description: String
    @State private var notes: String

    // Computed properties
    private var canSubmit: Bool {
        !isSaving
    }

    // MARK: - Initialization

    /// Initialize form for create or edit mode
    /// - Parameters:
    ///   - termToEdit: Existing term to edit (nil = create mode)
    ///   - suggestedTermNumber: Next term number from TermsListView (create mode only)
    public init(
        termToEdit: TimePeriodData? = nil,
        suggestedTermNumber: Int? = nil
    ) {
        self.termToEdit = termToEdit
        self.suggestedTermNumber = suggestedTermNumber

        // Initialize state from termToEdit or defaults
        if let term = termToEdit {
            // Edit mode - populate from existing term
            _termNumber = State(initialValue: term.termNumber)
            _startDate = State(initialValue: term.startDate)
            _targetDate = State(initialValue: term.endDate)
            _theme = State(initialValue: term.theme ?? "")
            _reflection = State(initialValue: term.reflection ?? "")
            _status = State(initialValue: term.termStatus ?? .planned)
            _title = State(initialValue: term.timePeriodTitle ?? "")
            _description = State(initialValue: "")  // Not included in flat structure
            _notes = State(initialValue: "")
        } else {
            // Create mode - use suggested number or default to 1
            _termNumber = State(initialValue: suggestedTermNumber ?? 1)
            _startDate = State(initialValue: Date())
            _targetDate = State(
                initialValue: Calendar.current.date(byAdding: .weekOfYear, value: 10, to: Date())
                    ?? Date())
            _theme = State(initialValue: "")
            _reflection = State(initialValue: "")
            _status = State(initialValue: .planned)
            _title = State(initialValue: "")
            _description = State(initialValue: "")
            _notes = State(initialValue: "")
        }
    }

    public var body: some View {
        Form {
            Section("Term Details") {
                Stepper("Term Number: \(termNumber)", value: $termNumber, in: 1...52)
                    .accessibilityLabel("Term number")

                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)

                DatePicker("End Date", selection: $targetDate, displayedComponents: .date)
            }

            Section {
                TextField("Focus area for this term", text: $theme, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("Theme")
            } footer: {
                Text(
                    "Optional: What's the main focus? (e.g., \"Health & Fitness\", \"Career Growth\")"
                )
                .font(.caption)
            }

            // Reflection section (edit mode only)
            if isEditMode {
                Section {
                    TextField("Post-term reflection", text: $reflection, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Reflection")
                } footer: {
                    Text("What did you learn? What would you do differently?")
                        .font(.caption)
                }

                Section {
                    Picker("Status", selection: $status) {
                        ForEach(TermStatus.allCases, id: \.self) { status in
                            Text(status.description).tag(status)
                        }
                    }
                } header: {
                    Text("Status")
                }
            }

            DocumentableFields(
                title: $title,
                detailedDescription: $description,
                freeformNotes: $notes
            )
        }
        .formStyle(.grouped)
        .navigationTitle(formTitle)
        .errorAlert(dataStore: dataStore)  // ✅ Unified error handling
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    handleSubmit()
                }
                .disabled(!canSubmit)
            }
        }
    }

    private func handleSubmit() {
        Task {
            isSaving = true
            defer { isSaving = false }

            do {
                // Assemble form data
                let formData = TimePeriodFormData(
                    title: title.isEmpty ? nil : title,
                    detailedDescription: description.isEmpty ? nil : description,
                    freeformNotes: notes.isEmpty ? nil : notes,
                    startDate: startDate,
                    targetDate: targetDate,
                    specialization: .term(number: termNumber),
                    theme: theme.isEmpty ? nil : theme,
                    reflection: reflection.isEmpty ? nil : reflection,
                    status: isEditMode ? status : nil
                )

                // Create or update term via DataStore
                if let existing = termToEdit {
                    _ = try await dataStore.updateTerm(
                        id: existing.id,
                        from: formData,
                        existing: existing
                    )
                } else {
                    _ = try await dataStore.createTerm(from: formData)
                }

                // Success! DataStore ValueObservation will update list automatically
                dismiss()
            } catch {
                // Error displayed automatically via .errorAlert(dataStore:)
                print("❌ TermFormView: Save failed - \(error)")
            }
        }
    }
}

