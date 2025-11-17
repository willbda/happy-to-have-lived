//
// PersonalValuesFormView.swift
// Written by Claude Code on 2025-11-01
// Rewritten by Claude Code on 2025-11-03 to follow Apple's SwiftUI patterns
//
// PURPOSE: Form view for PersonalValue creation and editing
// PATTERN: Direct Form structure following Apple's documented SwiftUI patterns
//          No wrapper components - navigation modifiers applied directly to Form
//

import Models
import Services
import SwiftUI

/// Form view for PersonalValue creation and editing
///
/// PATTERN: Apple's direct Form approach
/// - Form directly inside NavigationStack
/// - Navigation modifiers applied to Form itself
/// - Edit mode support via optional valueToEdit parameter
///
/// **Usage**:
/// ```swift
/// // Create mode
/// NavigationStack {
///     PersonalValuesFormView()
/// }
///
/// // Edit mode
/// NavigationStack {
///     PersonalValuesFormView(valueToEdit: existingValue)
/// }
/// ```
public struct PersonalValuesFormView: View {
    // MARK: - Edit Mode

    let valueToEdit: PersonalValueData?
    var isEditMode: Bool { valueToEdit != nil }
    var formTitle: String { isEditMode ? "Edit Value" : "New Value" }

    // MARK: - State

    @State private var viewModel = PersonalValuesFormViewModel()
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var title: String
    @State private var selectedLevel: ValueLevel
    @State private var priority: Int
    @State private var description: String
    @State private var notes: String
    @State private var lifeDomain: String
    @State private var alignmentGuidance: String

    // Computed properties
    private var canSubmit: Bool {
        !title.isEmpty && !viewModel.isSaving
    }

    // MARK: - Initialization

    public init(valueToEdit: PersonalValueData? = nil) {
        self.valueToEdit = valueToEdit

        if let value = valueToEdit {
            // Edit mode - initialize from existing data
            _title = State(initialValue: value.title)
            _selectedLevel = State(initialValue: ValueLevel(rawValue: value.valueLevel) ?? .general)
            _priority = State(initialValue: value.priority)
            _description = State(initialValue: value.detailedDescription ?? "")
            _notes = State(initialValue: value.freeformNotes ?? "")
            _lifeDomain = State(initialValue: value.lifeDomain ?? "")
            _alignmentGuidance = State(initialValue: value.alignmentGuidance ?? "")
        } else {
            // Create mode - defaults
            _title = State(initialValue: "")
            _selectedLevel = State(initialValue: .general)
            _priority = State(initialValue: 50)
            _description = State(initialValue: "")
            _notes = State(initialValue: "")
            _lifeDomain = State(initialValue: "")
            _alignmentGuidance = State(initialValue: "")
        }
    }

    // MARK: - Body

    public var body: some View {
        Form {
            DocumentableFields(
                title: $title,
                detailedDescription: $description,
                freeformNotes: $notes
            )

            // DESIGN: Title-case section headers (iOS 18+ pattern)
            Section("Value Properties") {
                Picker("Level", selection: $selectedLevel) {
                    ForEach(ValueLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .accessibilityLabel("Value level") // ACCESSIBILITY: VoiceOver support
                .accessibilityHint("Select the importance level of this value")

                Stepper("Priority: \(priority)", value: $priority, in: 1...100)
                    .accessibilityLabel("Priority") // ACCESSIBILITY: VoiceOver support
                    .accessibilityValue("\(priority) out of 100")
            }

            // DESIGN: Clear section naming for context
            Section("Context") {
                TextField("Life Domain", text: $lifeDomain)
                    .accessibilityLabel("Life domain") // ACCESSIBILITY: VoiceOver support
                    .accessibilityHint("Optional: The area of life this value relates to")

                TextField("Alignment Guidance", text: $alignmentGuidance, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityLabel("Alignment guidance") // ACCESSIBILITY: VoiceOver support
                    .accessibilityHint("Optional: How to align actions with this value")
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(formTitle)
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

    // MARK: - Actions

    /// Builds FormData from current @State variables.
    ///
    /// PATTERN: buildFormData() helper (establishes pattern for template)
    /// This reduces duplication and makes ViewModel calls cleaner.
    private func buildFormData() -> PersonalValueFormData {
        return PersonalValueFormData(
            title: title,
            detailedDescription: description.isEmpty ? nil : description,
            freeformNotes: notes.isEmpty ? nil : notes,
            valueLevel: selectedLevel,
            priority: priority,
            lifeDomain: lifeDomain.isEmpty ? nil : lifeDomain,
            alignmentGuidance: alignmentGuidance.isEmpty ? nil : alignmentGuidance
        )
    }

    private func handleSubmit() {
        Task {
            do {
                let formData = buildFormData()

                if let valueToEdit = valueToEdit {
                    // Update existing value
                    _ = try await viewModel.update(valueData: valueToEdit, from: formData)
                } else {
                    // Create new value (using formData instead of individual parameters)
                    _ = try await viewModel.save(from: formData)
                }

                dismiss()
            } catch {
                // Error already set in viewModel.errorMessage and displayed in form
            }
        }
    }
}


