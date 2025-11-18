//
// MetricTargetRow.swift
// Written by Claude Code on 2025-11-03
// Updated by Claude Code on 2025-11-06 (platform compatibility fixes)
//
// PURPOSE: Row view for metric target input (like MeasurementInputRow)
// USAGE: Used in RepeatingSection<MetricTargetRow> in GoalFormView
// PATTERN: Picker for measure + TextField for target value + optional notes
//
// PLATFORM NOTES:
// - iOS: Full support with keyboard-specific modifiers (autocapitalization)
// - macOS: Full support (keyboard modifiers not needed)
// - visionOS: Full support (spatial keyboard)
// - Platform guards: navigationBarTitleDisplayMode (iOS-only navigation API)
//

import Dependencies
import Models
import Services
import SQLiteData
import SwiftUI

/// Row component for metric target input
///
/// Used in goal forms to specify measurable targets.
/// Example: "120 km" or "30 runs"
///
/// PATTERN: Similar to MeasurementInputRow but with notes field
public struct MetricTargetRow: View {
    let availableMeasures: [Measure]
    @Binding var target: ExpectationMeasureFormData
    let onRemove: () -> Void
    let onMeasureCreated: (() async -> Void)?

    @State private var showingCreateMeasure = false
    @State private var newMeasureUnit = ""
    @State private var newMeasureTitle = ""
    @State private var newMeasureType = "distance"
    @State private var isCreating = false

    public init(
        availableMeasures: [Measure],
        target: Binding<ExpectationMeasureFormData>,
        onRemove: @escaping () -> Void = {},
        onMeasureCreated: (() async -> Void)? = nil
    ) {
        self.availableMeasures = availableMeasures
        self._target = target
        self.onRemove = onRemove
        self.onMeasureCreated = onMeasureCreated
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full-width Picker for measure selection
            Picker("Metric", selection: $target.measureId) {
                Text("Select metric").tag(nil as UUID?)

                if availableMeasures.isEmpty {
                    Text("Loading measures...")
                        .foregroundStyle(.secondary)
                        .tag(nil as UUID?)
                }

                ForEach(availableMeasures, id: \.id) { measure in
                    HStack {
                        Text(measure.title ?? measure.unit)
                        Spacer()
                        Text(measure.unit)
                            .foregroundStyle(.secondary)
                    }
                    .tag(measure.id as UUID?)
                }

                // If current selection doesn't exist in available measures, add placeholder
                if let selectedId = target.measureId,
                   !availableMeasures.contains(where: { $0.id == selectedId }) {
                    Text("(Deleted measure)")
                        .foregroundStyle(.secondary)
                        .tag(selectedId as UUID?)
                }
            }

            // Target value field with unit label
            HStack {
                Text("Target")
                    .foregroundStyle(.secondary)

                Spacer()

                TextField("0", value: $target.targetValue, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)

                if let selectedMeasure = availableMeasures.first(where: { $0.id == target.measureId }) {
                    Text(selectedMeasure.unit)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 60, alignment: .leading)
                }
            }

            // Optional notes field for target rationale
            TextField("Target notes (optional)", text: Binding(
                get: { target.notes ?? "" },
                set: { target.notes = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.footnote)

            // Create new measure button
            if availableMeasures.isEmpty || target.measureId == nil {
                Button {
                    showingCreateMeasure = true
                } label: {
                    Label("Create New Measure", systemImage: "plus.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.borderless)
            }

            // Remove button
            Button(role: .destructive, action: onRemove) {
                Label("Remove target", systemImage: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingCreateMeasure) {
            NavigationStack {
                createMeasureForm
            }
        }
    }

    // MARK: - Create Measure Form

    private var createMeasureForm: some View {
        Form {
            Section("Measure Details") {
                TextField("Unit (e.g., km, hours, sessions)", text: $newMeasureUnit)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)  // iOS: Disable caps for unit names (km, hours)
                    #endif

                TextField("Title (e.g., Distance in kilometers)", text: $newMeasureTitle)

                Picker("Type", selection: $newMeasureType) {
                    Text("Distance").tag("distance")
                    Text("Time").tag("time")
                    Text("Count").tag("count")
                    Text("Energy").tag("energy")
                    Text("Other").tag("other")
                }
            }

            Section {
                Text("Examples:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("• Unit: km, Title: Distance in kilometers, Type: distance")
                    .font(.caption2)
                Text("• Unit: hours, Title: Duration in hours, Type: time")
                    .font(.caption2)
                Text("• Unit: sessions, Title: Number of sessions, Type: count")
                    .font(.caption2)
            }
        }
        .navigationTitle("New Measure")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    showingCreateMeasure = false
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await createMeasure()
                    }
                }
                .disabled(newMeasureUnit.isEmpty || isCreating)
            }
        }
    }

    /// Create a new measure and add it to the database
    ///
    /// **Refactored 2025-11-17**: Now uses MeasureCoordinator.getOrCreate()
    /// instead of direct database writes for proper duplicate prevention.
    ///
    /// **Coordinator Composition**: UI calls coordinator (not direct writes)
    /// - Idempotent: getOrCreate() returns existing measure if duplicate found
    /// - Validation: Two-phase validation via coordinator
    /// - Error Handling: User-friendly ValidationError messages
    private func createMeasure() async {
        isCreating = true
        defer { isCreating = false }

        // Capture @MainActor properties
        let unit = newMeasureUnit
        let title = newMeasureTitle.isEmpty ? newMeasureUnit.capitalized : newMeasureTitle
        let type = newMeasureType

        do {
            @Dependency(\.defaultDatabase) var database

            // ✅ USE COORDINATOR (not direct database write)
            // This is idempotent - returns existing measure if duplicate found
            let coordinator = MeasureCoordinator(database: database)
            let newMeasure = try await coordinator.getOrCreate(
                unit: unit,
                measureType: type,
                title: title
            )

            // Back on MainActor context - safe to update @State properties
            target.measureId = newMeasure.id

            // Notify parent to refresh available measures
            await onMeasureCreated?()

            showingCreateMeasure = false
            print("✅ Created/retrieved measure: \(newMeasure.unit)")
        } catch let error as ValidationError {
            // User-friendly validation errors
            print("❌ MetricTargetRow ValidationError: \(error.userMessage)")
            // TODO: Display errorMessage in UI (add @State var errorMessage: String?)
        } catch {
            print("❌ Failed to create measure: \(error)")
        }
    }
}

// MARK: - Preview

#Preview("With Target") {
    Form {
        Section("Metric Targets") {
            MetricTargetRow(
                availableMeasures: [
                    Measure(unit: "km", measureType: "distance", title: "Distance (km)"),
                    Measure(unit: "minutes", measureType: "time", title: "Duration (minutes)"),
                    Measure(unit: "occasions", measureType: "count", title: "Sessions")
                ],
                target: .constant(ExpectationMeasureFormData(
                    measureId: UUID(),
                    targetValue: 120,
                    notes: "Based on 10% weekly increase"
                )),
                onRemove: { print("Removed") }
            )
        }
    }
}

#Preview("Empty") {
    Form {
        Section("Metric Targets") {
            MetricTargetRow(
                availableMeasures: [
                    Measure(unit: "km", measureType: "distance", title: "Distance")
                ],
                target: .constant(ExpectationMeasureFormData()),
                onRemove: { print("Removed") }
            )
        }
    }
}
