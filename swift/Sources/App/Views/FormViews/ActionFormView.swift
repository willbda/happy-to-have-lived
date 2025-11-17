//
// ActionFormView.swift
// Written by Claude Code on 2025-11-02
// Rewritten by Claude Code on 2025-11-03 to follow Apple's SwiftUI patterns
// Updated by Claude Code on 2025-11-16 - Migrated to canonical ActionData
//
// PURPOSE: Form for creating/editing Actions with measurements and goal contributions
// PATTERN: Direct Form structure following Apple's documented SwiftUI patterns
//          No wrapper components - navigation modifiers applied directly to Form
//

import Models
import Services
import SwiftUI

// MARK: - Helper Types

/// Wrapper for goal selection in MultiSelectSection
private struct GoalOption: Identifiable {
    let id: UUID
    let goal: Goal
    let title: String

    init(goal: Goal, title: String) {
        self.id = goal.id
        self.goal = goal
        self.title = title
    }
}

// MARK: - Form View

/// Form view for Action input (create + edit + quick add)
///
/// **Pattern**: Apple's direct Form approach (no FormScaffold wrapper)
/// **Modes**:
/// - Create: Default empty form
/// - Edit: Pre-filled from existing ActionData
/// - Quick Add: Pre-filled from ActionFormData (duplicate or log for goal)
///
/// **Usage**:
/// ```swift
/// // Create mode
/// NavigationStack {
///     ActionFormView()
/// }
///
/// // Edit mode
/// NavigationStack {
///     ActionFormView(actionToEdit: actionData)
/// }
///
/// // Quick Add mode (from QuickAddSection)
/// NavigationStack {
///     ActionFormView(initialData: preFilledFormData)
/// }
/// ```
public struct ActionFormView: View {
    // MARK: - Edit Mode

    let actionToEdit: ActionData?
    var isEditMode: Bool { actionToEdit != nil }
    var formTitle: String { isEditMode ? "Edit Action" : "New Action" }

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ActionFormViewModel()

    // Form fields
    @State private var title: String
    @State private var detailedDescription: String
    @State private var freeformNotes: String
    @State private var startTime: Date
    @State private var durationMinutes: Double
    @State private var measurements: [MeasurementInput]
    @State private var selectedGoalIds: Set<UUID>

    // Computed properties
    private var canSubmit: Bool {
        !title.isEmpty && !viewModel.isSaving
    }

    // MARK: - Initialization

    /// Initialize form for create, edit, or quick add mode
    ///
    /// **Modes**:
    /// - Create: No parameters (defaults)
    /// - Edit: Pass `actionToEdit` (existing action with relationships)
    /// - Quick Add: Pass `initialData` (pre-filled form data from duplicate/goal)
    ///
    /// **Usage**:
    /// ```swift
    /// // Create mode
    /// ActionFormView()
    ///
    /// // Edit mode
    /// ActionFormView(actionToEdit: existingAction)
    ///
    /// // Quick Add mode (duplicate or log for goal)
    /// ActionFormView(initialData: preFilledFormData)
    /// ```
    public init(
        actionToEdit: ActionData? = nil,
        initialData: ActionFormData? = nil
    ) {
        self.actionToEdit = actionToEdit

        if let actionToEdit = actionToEdit {
            // Edit mode - initialize from existing data
            _title = State(initialValue: actionToEdit.title ?? "")
            _detailedDescription = State(
                initialValue: actionToEdit.detailedDescription ?? "")
            _freeformNotes = State(initialValue: actionToEdit.freeformNotes ?? "")
            _startTime = State(
                initialValue: actionToEdit.startTime ?? actionToEdit.logTime)
            _durationMinutes = State(initialValue: actionToEdit.durationMinutes ?? 0)

            // Convert measurements to edit format
            let existingMeasurements = actionToEdit.measurements.map { measurement in
                MeasurementInput(
                    id: measurement.id,
                    measureId: measurement.measureId,
                    value: measurement.value
                )
            }
            _measurements = State(initialValue: existingMeasurements)

            // Convert contributions to Set<UUID>
            let existingGoalIds = Set(actionToEdit.contributions.map { $0.goalId })
            _selectedGoalIds = State(initialValue: existingGoalIds)
        } else if let initialData = initialData {
            // Quick Add mode - initialize from pre-filled form data
            _title = State(initialValue: initialData.title)
            _detailedDescription = State(initialValue: initialData.detailedDescription)
            _freeformNotes = State(initialValue: initialData.freeformNotes)
            _startTime = State(initialValue: initialData.startTime)
            _durationMinutes = State(initialValue: initialData.durationMinutes)
            _measurements = State(initialValue: initialData.measurements)
            _selectedGoalIds = State(initialValue: initialData.goalContributions)
        } else {
            // Create mode - defaults
            _title = State(initialValue: "")
            _detailedDescription = State(initialValue: "")
            _freeformNotes = State(initialValue: "")
            _startTime = State(initialValue: Date())
            _durationMinutes = State(initialValue: 0)
            _measurements = State(initialValue: [])
            _selectedGoalIds = State(initialValue: [])
        }
    }

    // MARK: - Body

    public var body: some View {
        Form {
            DocumentableFields(
                title: $title,
                detailedDescription: $detailedDescription,
                freeformNotes: $freeformNotes
            )

            TimingSection(
                startTime: $startTime,
                durationMinutes: $durationMinutes
            )

            RepeatingSection(
                title: "Measurements",
                items: measurements,
                addButtonLabel: "Add Measurement",
                footer: "Track distance, time, count, or other metrics for this action",
                onAdd: addMeasurement
            ) { measurement in
                MeasurementInputRow(
                    measureId: bindingForMeasurement(measurement.id).measureId,
                    value: bindingForMeasurement(measurement.id).value,
                    availableMeasures: viewModel.availableMeasures,
                    onRemove: { removeMeasurement(id: measurement.id) }
                )
            }

            MultiSelectSection(
                items: viewModel.availableGoals.map { GoalOption(goal: $0.0, title: $0.1) },
                title: "Goal Contributions",
                itemLabel: { $0.title },
                selectedIds: $selectedGoalIds
            )

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
        .task {
            await viewModel.loadOptions()

            // Validate measurements after loading available measures
            // Filter out any measurements referencing deleted measures
            let validMeasureIds = Set(viewModel.availableMeasures.map { $0.id })
            measurements.removeAll { measurement in
                guard let measureId = measurement.measureId else { return false }
                return !validMeasureIds.contains(measureId)
            }

            // Validate goal contributions - remove deleted goals
            let validGoalIds = Set(viewModel.availableGoals.map { $0.0.id })
            selectedGoalIds = selectedGoalIds.filter { validGoalIds.contains($0) }
        }
    }

    // MARK: - Helpers

    /// Handle form submission (create or update)
    private func handleSubmit() {
        Task {
            do {
                // Convert measurements to tuple format for ViewModel
                let measurementTuples: [(UUID, Double)] = measurements.compactMap { measurement in
                    guard let measureId = measurement.measureId, measurement.value > 0 else {
                        return nil
                    }
                    return (measureId, measurement.value)
                }

                if let actionToEdit = actionToEdit {
                    // Update existing action
                    _ = try await viewModel.update(
                        actionData: actionToEdit,
                        title: title,
                        description: detailedDescription,
                        notes: freeformNotes,
                        durationMinutes: durationMinutes,
                        startTime: startTime,
                        measurements: measurementTuples,
                        goalContributions: selectedGoalIds
                    )
                } else {
                    // Create new action
                    _ = try await viewModel.save(
                        title: title,
                        description: detailedDescription,
                        notes: freeformNotes,
                        durationMinutes: durationMinutes,
                        startTime: startTime,
                        measurements: measurementTuples,
                        goalContributions: selectedGoalIds
                    )
                }
                dismiss()
            } catch {
                // Error handled by viewModel.errorMessage
            }
        }
    }

    /// Add a new empty measurement
    private func addMeasurement() {
        measurements.append(MeasurementInput(id: UUID(), measureId: nil, value: 0))
    }

    /// Remove a measurement by ID
    private func removeMeasurement(id: UUID) {
        measurements.removeAll { $0.id == id }
    }

    /// Create bindings for measurement fields
    ///
    /// Returns a tuple of bindings for (measureId, value) for the given measurement ID
    private func bindingForMeasurement(_ id: UUID) -> (measureId: Binding<UUID?>, value: Binding<Double>) {
        guard let index = measurements.firstIndex(where: { $0.id == id }) else {
            // Fallback for missing measurement (shouldn't happen in practice)
            return (
                measureId: .constant(nil),
                value: .constant(0)
            )
        }

        return (
            measureId: Binding(
                get: { measurements[index].measureId },
                set: { measurements[index].measureId = $0 }
            ),
            value: Binding(
                get: { measurements[index].value },
                set: { measurements[index].value = $0 }
            )
        )
    }
}

// MARK: - Previews

#Preview("New Action") {
    NavigationStack {
        ActionFormView()
    }
}

#Preview("Edit Action") {
    NavigationStack {
        ActionFormView(
            actionToEdit: ActionData(
                id: UUID(),
                title: "Morning run",
                detailedDescription: "Great weather",
                freeformNotes: nil,
                logTime: Date(),
                durationMinutes: 28,
                startTime: Date(),
                measurements: [
                    ActionData.Measurement(
                        id: UUID(),
                        measureId: UUID(),
                        measureTitle: "Distance",
                        measureUnit: "km",
                        measureType: "distance",
                        value: 5.2,
                        createdAt: Date()
                    )
                ],
                contributions: []
            )
        )
    }
}
