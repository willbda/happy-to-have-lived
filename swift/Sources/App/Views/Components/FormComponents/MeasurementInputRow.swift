//
// MeasurementInputRow.swift
// Written by Claude Code on 2025-11-03
//
// PURPOSE: Reusable row component for measure + value entry
//
// SOLVES: Alignment issue in ActionFormView where picker pushes TextField far right
// PATTERN: Full-width picker, then value field with proper spacing
// USAGE: Actions (measurements), Goals (targets), any form with metric input
//
// DESIGN:
// - Measure picker: Full width, not cramped in HStack
// - Value field: Aligned left like other fields (not forced right)
// - Unit display: Shows selected measure's unit next to value
// - Remove button: Consistent placement and styling
// - Spacing: Proper padding matches other form sections
//
// EXAMPLE:
// MeasurementInputRow(
//     measureId: $measurement.measureId,
//     value: $measurement.value,
//     availableMeasures: viewModel.availableMeasures,
//     onRemove: { removeMeasurement(id: measurement.id) }
// )

import SwiftUI
import Models
import Services
import SQLiteData

public struct MeasurementInputRow: View {
    @Binding var measureId: UUID?
    @Binding var value: Double
    let availableMeasures: [MeasureData]
    let onRemove: () -> Void
    let onMeasureCreated: (() async -> Void)?

    @Environment(DataStore.self) private var dataStore

    @State private var showingCreateMeasure = false
    @State private var newMeasureUnit = ""
    @State private var newMeasureTitle = ""
    @State private var newMeasureType = "distance"
    @State private var isCreating = false

    public init(
        measureId: Binding<UUID?>,
        value: Binding<Double>,
        availableMeasures: [MeasureData],
        onRemove: @escaping () -> Void,
        onMeasureCreated: (() async -> Void)? = nil
    ) {
        self._measureId = measureId
        self._value = value
        self.availableMeasures = availableMeasures
        self.onRemove = onRemove
        self.onMeasureCreated = onMeasureCreated
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {  // Modern spacing (was 8)
            // Full-width Picker (not cramped in HStack)
            Picker("Measure", selection: $measureId) {
                Text("Select measure").tag(nil as UUID?)

                if availableMeasures.isEmpty {
                    Text("Loading measures...")
                        .foregroundStyle(.secondary)
                        .tag(nil as UUID?)
                }

                ForEach(availableMeasures, id: \.id) { measure in
                    Text(measure.unit).tag(measure.id as UUID?)
                }

                // If current selection doesn't exist in available measures, add placeholder
                if let selectedId = measureId,
                   !availableMeasures.contains(where: { $0.id == selectedId }) {
                    Text("(Deleted measure)")
                        .foregroundStyle(.secondary)
                        .tag(selectedId as UUID?)
                }
            }

            // Value field with unit label (proper spacing, not cramped)
            HStack {
                Text("Value")
                    .foregroundStyle(.secondary)

                Spacer()  // Push TextField to the right side

                TextField("0", value: $value, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)  // Consistent width

                if let selectedMeasure = availableMeasures.first(where: { $0.id == measureId }) {
                    Text(selectedMeasure.unit)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 60, alignment: .leading)  // Reserve space for unit
                }
            }

            // Create new measure button
            if availableMeasures.isEmpty || measureId == nil {
                Button {
                    showingCreateMeasure = true
                } label: {
                    Label("Create New Measure", systemImage: "plus.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.borderless)
            }

            // Remove button (consistent placement)
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 12)  // Modern spacing for better touch targets
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
    /// **Pattern**: Uses DataStore.createMeasure() for centralized database access
    /// **Architecture**: UI → DataStore → MeasureCoordinator → Database
    /// **Idempotent**: Returns existing measure if duplicate found (no error thrown)
    /// **Error Handling**: User-friendly ValidationError messages
    ///
    /// **Why DataStore?**
    /// - Views (SwiftUI structs) can't use @Dependency property wrapper
    /// - @Dependency only works on stored properties in classes
    /// - DataStore provides single source of truth for database access
    /// - ValueObservation automatically updates measures array
    private func createMeasure() async {
        isCreating = true
        defer { isCreating = false }

        // Capture @MainActor properties
        let unit = newMeasureUnit
        let title = newMeasureTitle.isEmpty ? newMeasureUnit.capitalized : newMeasureTitle
        let type = newMeasureType

        do {
            // Use DataStore for database access (correct pattern for Views)
            let measure = try await dataStore.createMeasure(
                unit: unit,
                measureType: type,
                title: title
            )

            // Update UI to select newly created measure
            measureId = measure.id

            // Notify parent (ValueObservation already updated DataStore.measures)
            await onMeasureCreated?()

            // Dismiss sheet
            showingCreateMeasure = false

            // Reset form
            newMeasureUnit = ""
            newMeasureTitle = ""
            newMeasureType = "distance"

            print("✅ Created measure: \(measure.unit) (\(measure.id))")

        } catch {
            print("❌ Failed to create measure: \(error)")
            // Error handling: In production, show alert to user
            // For now, error prints to console and sheet stays open
        }
    }
}

// MARK: - Preview

#Preview("With Selection") {
    Form {
        Section {
            MeasurementInputRow(
                measureId: .constant(UUID()),
                value: .constant(5.2),
                availableMeasures: [
                    MeasureData(
                        id: UUID(),
                        title: "Distance",
                        detailedDescription: nil,
                        freeformNotes: nil,
                        logTime: Date(),
                        unit: "km",
                        measureType: "distance",
                        canonicalUnit: nil,
                        conversionFactor: nil
                    ),
                    MeasureData(
                        id: UUID(),
                        title: "Time",
                        detailedDescription: nil,
                        freeformNotes: nil,
                        logTime: Date(),
                        unit: "minutes",
                        measureType: "time",
                        canonicalUnit: nil,
                        conversionFactor: nil
                    ),
                    MeasureData(
                        id: UUID(),
                        title: "Occasions",
                        detailedDescription: nil,
                        freeformNotes: nil,
                        logTime: Date(),
                        unit: "occasions",
                        measureType: "count",
                        canonicalUnit: nil,
                        conversionFactor: nil
                    )
                ],
                onRemove: { print("Removed") },
                onMeasureCreated: { print("Measure created - refresh") }
            )
        }
    }
}

#Preview("Empty - Shows Create Button") {
    Form {
        Section {
            MeasurementInputRow(
                measureId: .constant(nil),
                value: .constant(0),
                availableMeasures: [
                    MeasureData(
                        id: UUID(),
                        title: "Distance",
                        detailedDescription: nil,
                        freeformNotes: nil,
                        logTime: Date(),
                        unit: "km",
                        measureType: "distance",
                        canonicalUnit: nil,
                        conversionFactor: nil
                    )
                ],
                onRemove: { print("Removed") },
                onMeasureCreated: { print("Measure created - refresh") }
            )
        }
    }
}
