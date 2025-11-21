//
// ActionFormView.swift
// Written by Claude Code on 2025-11-02
// Rewritten by Claude Code on 2025-11-03 to follow Apple's SwiftUI patterns
// Updated by Claude Code on 2025-11-16 - Migrated to canonical ActionData
// Refactored by Claude Code on 2025-11-20 - Uses DataStore + unified error alerts
//
// PURPOSE: Form for creating/editing Actions with measurements and goal contributions
// PATTERN: Local @State fields + DataStore (operations) + View+ErrorAlert (errors)
//
// DATA FLOW:
// 1. User edits local @State fields (title, measurements, goalContributions)
// 2. Save button calls dataStore.createAction()
// 3. DataStore ValueObservation automatically updates list views
// 4. Errors display via .errorAlert(dataStore:) modifier
//

import Dependencies
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
    @Environment(DataStore.self) private var dataStore

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @State private var isSaving = false

    // Form fields
    @State private var title: String
    @State private var detailedDescription: String
    @State private var freeformNotes: String
    @State private var startTime: Date
    @State private var durationMinutes: Double
    @State private var measurements: [MeasurementInput]
    @State private var selectedGoalIds: Set<UUID>

    // Available data for pickers
    @State private var availableMeasures: [Measure] = []
    @State private var availableGoals: [(Goal, String)] = []  // (goal, title)

    // Computed properties
    private var canSubmit: Bool {
        !title.isEmpty && !isSaving
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
                    availableMeasures: availableMeasures,
                    onRemove: { removeMeasurement(id: measurement.id) }
                )
            }

            MultiSelectSection(
                items: availableGoals.map { GoalOption(goal: $0.0, title: $0.1) },
                title: "Goal Contributions",
                itemLabel: { $0.title },
                selectedIds: $selectedGoalIds
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
        .task {
            await loadAvailableData()

            // Validate measurements after loading available measures
            // Filter out any measurements referencing deleted measures
            let validMeasureIds = Set(availableMeasures.map { $0.id })
            measurements.removeAll { measurement in
                guard let measureId = measurement.measureId else { return false }
                return !validMeasureIds.contains(measureId)
            }

            // Validate goal contributions - remove deleted goals
            let validGoalIds = Set(availableGoals.map { $0.0.id })
            selectedGoalIds = selectedGoalIds.filter { validGoalIds.contains($0) }
        }
    }

    // MARK: - Data Loading

    private func loadAvailableData() async {
        do {
            // Launch both queries in parallel
            async let measures = database.read { db in
                try Measure.order(by: \.unit).fetchAll(db)
            }
            async let goalsWithExpectations = database.read { db in
                try Goal.join(Expectation.all) { $0.expectationId.eq($1.id) }
                    .fetchAll(db)
            }

            availableMeasures = try await measures

            // Map joined results to (Goal, String) tuples
            let joined = try await goalsWithExpectations
            availableGoals = joined.map { (goal: $0.0, title: $0.1.title ?? "Untitled") }
        } catch {
            print("Error loading form data: \(error)")
        }
    }

    // MARK: - Actions

    /// Handle form submission (create or update)
    private func handleSubmit() {
        Task {
            isSaving = true
            defer { isSaving = false }

            do {
                // Assemble form data
                let formData = ActionFormData(
                    title: title,
                    detailedDescription: detailedDescription,
                    freeformNotes: freeformNotes,
                    durationMinutes: durationMinutes,
                    startTime: startTime,
                    measurements: measurements,
                    goalContributions: selectedGoalIds
                )

                // TODO: Add update support when DataStore.updateAction() is implemented
                if actionToEdit != nil {
                    // Update not yet implemented - create new for now
                    print("⚠️ Update not yet supported, creating new action")
                }

                // Create action via DataStore
                _ = try await dataStore.createAction(from: formData)

                // Success! DataStore ValueObservation will update list automatically
                dismiss()
            } catch {
                // Error displayed automatically via .errorAlert(dataStore:)
                print("❌ ActionFormView: Save failed - \(error)")
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
