//
// GoalFormView.swift
// Written by Claude Code on 2025-11-03
// Rewritten by Claude Code on 2025-11-03 to follow Apple's SwiftUI patterns
// Updated by Claude Code on 2025-11-16 - Migrated to canonical GoalData
// Refactored by Claude Code on 2025-11-19 - Consolidated state with @Observable GoalFormModel
// Refactored by Claude Code on 2025-11-20 - Uses DataStore + unified error alerts
//
// PURPOSE: Form for creating/editing Goals with full relationship support
// PATTERN: GoalFormModel (@Observable) + DataStore (operations) + View+ErrorAlert (errors)
//
// DATA FLOW:
// 1. User edits local @State model (GoalFormModel)
// 2. Save button calls dataStore.createGoal() or dataStore.updateGoal()
// 3. DataStore ValueObservation automatically updates list views
// 4. Errors display via .errorAlert(dataStore:) modifier
//

import Dependencies
import Models
import Services
import SQLiteData
import SwiftUI

/// Form view for Goal input (create + edit)
///
/// **DECLARATIVE ARCHITECTURE** (2025-11-20):
/// - Local form state (GoalFormModel) for editing
/// - DataStore methods for persistence + automatic list updates
/// - No manual refresh needed (DataStore propagates changes)
/// - Save button pattern (explicit, validated writes)
///
/// COMPLEXITY: Most complex form in app
/// - Expectation fields (title, description, importance, urgency)
/// - Goal fields (dates, action plan, term length)
/// - Metric targets (repeating section)
/// - Value alignments (multi-select)
/// - Optional term assignment
public struct GoalFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataStore.self) private var dataStore

    @State private var isSaving = false

    // MARK: - Form Model (Single Source of Truth!)

    @State private var model: GoalFormModel

    // Available data for pickers (not part of form state)
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @State private var availableMeasures: [Measure] = []
    @State private var availableValues: [PersonalValue] = []
    @State private var availableTerms: [TimePeriodData] = []

    // MARK: - Edit Mode Support

    private let goalToEdit: GoalData?

    private var isEditMode: Bool {
        goalToEdit != nil
    }

    private var formTitle: String {
        isEditMode ? "Edit Goal" : "New Goal"
    }

    // MARK: - Initialization

    public init(goalToEdit: GoalData? = nil) {
        self.goalToEdit = goalToEdit

        // Initialize model based on mode
        if let goal = goalToEdit {
            _model = State(initialValue: GoalFormModel(from: goal))
        } else {
            _model = State(initialValue: GoalFormModel())
        }
    }

    // MARK: - Body

    private var canSubmit: Bool {
        !isSaving && model.canSubmit
    }

    public var body: some View {
        Form {
            // Basic information
            DocumentableFields(
                title: $model.title,  // ✅ Bind to model
                detailedDescription: $model.detailedDescription,
                freeformNotes: $model.freeformNotes
            )

            // Importance & Urgency
            Section("Priority") {
                Stepper("Importance: \(model.importance)", value: $model.importance, in: 1...10)
                Stepper("Urgency: \(model.urgency)", value: $model.urgency, in: 1...10)
            }

            // Goal-specific fields
            Section("Timeline") {
                DatePicker("Start Date", selection: $model.startDate, displayedComponents: .date)
                DatePicker("Target Date", selection: $model.targetDate, displayedComponents: .date)
                Stepper("Expected Length: \(model.expectedTermLength) weeks", value: $model.expectedTermLength, in: 1...52)
            }

            Section("Action Plan") {
                TextField("How will you achieve this?", text: $model.actionPlan, axis: .vertical)
                    .lineLimit(3...6)
            }

            // Metric targets
            Section("Measurable Targets") {
                ForEach($model.measureTargets) { $target in
                    MetricTargetRow(
                        availableMeasures: availableMeasures,
                        target: $target,
                        onRemove: {
                            model.removeMeasureTarget(id: target.id)
                        },
                        onMeasureCreated: {
                            await loadAvailableData()
                        }
                    )
                }

                Button {
                    model.addMeasureTarget()
                } label: {
                    Label("Add Metric Target", systemImage: "plus.circle.fill")
                }
            }

            // Value alignments - NO MORE onChange handler!
            Section("Value Alignment") {
                ForEach(availableValues) { value in
                    // ✅ Bind to computed property (no manual sync needed!)
                    Toggle(isOn: Binding(
                        get: { model.selectedValueIds.contains(value.id) },
                        set: { _ in model.toggleValue(value.id) }
                    )) {
                        Text(value.title ?? "Untitled Value")
                    }
                }

                // Alignment strength sliders
                ForEach($model.valueAlignments) { $alignment in
                    if let value = availableValues.first(where: { $0.id == alignment.valueId }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(value.title ?? "Value") alignment strength: \(alignment.alignmentStrength)/10")
                                .font(.subheadline)
                            Slider(value: Binding(
                                get: { Double(alignment.alignmentStrength) },
                                set: { alignment.alignmentStrength = Int($0) }
                            ), in: 1...10, step: 1)
                        }
                    }
                }
            }

            // Term assignment
            if !availableTerms.isEmpty {
                Section("Term Assignment (Optional)") {
                    Picker("Assign to Term", selection: $model.selectedTermId) {
                        Text("No term").tag(nil as UUID?)
                        ForEach(availableTerms) { termData in
                            Text("Term \(termData.termNumber)")
                                .tag(termData.id as UUID?)
                        }
                    }
                }
            }
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
                Button(isEditMode ? "Update" : "Save") {
                    handleSubmit()
                }
                .disabled(!canSubmit)
            }
        }
        .task {
            await loadAvailableData()
        }
    }

    // MARK: - Data Loading

    private func loadAvailableData() async {
        do {
            // Launch all three queries in parallel
            async let measures = database.read { db in
                try Measure.order(by: \.unit).fetchAll(db)
            }
            async let values = database.read { db in
                try PersonalValue.order { $0.priority.desc() }.fetchAll(db)
            }

            let repository = TimePeriodRepository(database: database)
            async let terms = repository.fetchAll()

            (availableMeasures, availableValues, availableTerms) = try await (measures, values, terms)
        } catch {
            print("Error loading form data: \(error)")
        }
    }

    // MARK: - Actions

    private func handleSubmit() {
        Task {
            isSaving = true
            defer { isSaving = false }

            do {
                // Assemble form data
                let formData = GoalFormData(
                    title: model.title,
                    detailedDescription: model.detailedDescription,
                    freeformNotes: model.freeformNotes,
                    expectationImportance: model.importance,
                    expectationUrgency: model.urgency,
                    startDate: model.startDate,
                    targetDate: model.targetDate,
                    actionPlan: model.actionPlan.isEmpty ? nil : model.actionPlan,
                    expectedTermLength: model.expectedTermLength,
                    measureTargets: model.measureTargets,
                    valueAlignments: model.valueAlignments,
                    termId: model.selectedTermId
                )

                if let goalData = goalToEdit {
                    // Update existing goal
                    _ = try await dataStore.updateGoal(
                        id: goalData.id,
                        from: formData,
                        existing: goalData
                    )
                } else {
                    // Create new goal
                    _ = try await dataStore.createGoal(from: formData)
                }

                // Success! DataStore automatically updated the list
                // Form closes, list view sees new data immediately
                dismiss()
            } catch {
                // Error displayed automatically via dataStore.errorMessage
                print("❌ GoalFormView: Save failed - \(error)")
            }
        }
    }
}
