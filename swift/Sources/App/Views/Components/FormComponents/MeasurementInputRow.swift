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

public struct MeasurementInputRow: View {
    @Binding var measureId: UUID?
    @Binding var value: Double
    let availableMeasures: [Measure]
    let onRemove: () -> Void

    public init(
        measureId: Binding<UUID?>,
        value: Binding<Double>,
        availableMeasures: [Measure],
        onRemove: @escaping () -> Void
    ) {
        self._measureId = measureId
        self._value = value
        self.availableMeasures = availableMeasures
        self.onRemove = onRemove
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

            // Remove button (consistent placement)
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 12)  // Modern spacing for better touch targets
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
                    Measure(unit: "km", measureType: "distance", title: "Distance"),
                    Measure(unit: "minutes", measureType: "time", title: "Time"),
                    Measure(unit: "occasions", measureType: "count", title: "Occasions")
                ],
                onRemove: { print("Removed") }
            )
        }
    }
}

#Preview("Empty") {
    Form {
        Section {
            MeasurementInputRow(
                measureId: .constant(nil),
                value: .constant(0),
                availableMeasures: [
                    Measure(unit: "km", measureType: "distance", title: "Distance")
                ],
                onRemove: { print("Removed") }
            )
        }
    }
}
