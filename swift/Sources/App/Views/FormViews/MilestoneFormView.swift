//
// MilestoneFormView.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Form for creating milestones
// PATTERN: @State for local form data, ViewModel for save/update
//

import Models
import Services
import SwiftUI

/// Form view for creating/editing milestones
///
/// **PATTERN**: SwiftUI Form with @State for data binding
/// **VIEWMODEL**: MilestoneFormViewModel handles save/update
/// **VALIDATION**: Handled by MilestoneCoordinator → MilestoneValidation
///
public struct MilestoneFormView: View {
    @State private var viewModel = MilestoneFormViewModel()
    @Environment(\.dismiss) private var dismiss

    // Form data (local state)
    @State private var formData = MilestoneFormData()

    public init() {}

    public var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $formData.title)

                TextField(
                    "Description",
                    text: $formData.detailedDescription,
                    axis: .vertical
                )
                .lineLimit(3...6)

                TextField(
                    "Notes",
                    text: $formData.freeformNotes,
                    axis: .vertical
                )
                .lineLimit(3...6)
            }

            Section("Target") {
                DatePicker(
                    "Target Date",
                    selection: $formData.targetDate,
                    displayedComponents: .date
                )
            }

            Section("Priority") {
                Stepper(
                    "Importance: \(formData.expectationImportance)",
                    value: $formData.expectationImportance,
                    in: 1...10
                )

                Stepper(
                    "Urgency: \(formData.expectationUrgency)",
                    value: $formData.expectationUrgency,
                    in: 1...10
                )
            }
        }
        .navigationTitle("New Milestone")

        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        do {
                            _ = try await viewModel.save(from: formData)
                            dismiss()
                        } catch {
                            // Error handled in viewModel
                        }
                    }
                }
                .disabled(viewModel.isSaving || formData.title.isEmpty)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.hasError)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .overlay {
            if viewModel.isSaving {
                ProgressView()
            }
        }
    }
}
