//
// ObligationFormView.swift
// Written by Claude Code on 2025-11-19
// Refactored by Claude Code on 2025-11-22 - Migrated to DataStore pattern
//
// PURPOSE: Form for creating obligations
// PATTERN: @State for local form data, DataStore for operations
//
// DATA FLOW:
// 1. User edits local @State formData (ObligationFormData)
// 2. Save button calls dataStore.createObligation()
// 3. DataStore ValueObservation automatically updates list views
// 4. Errors display via .errorAlert(dataStore:) modifier
//

import Models
import Services
import SwiftUI

/// Form view for creating/editing obligations
///
/// **DECLARATIVE ARCHITECTURE** (2025-11-22):
/// - Local form state (ObligationFormData) for editing
/// - DataStore methods for persistence + automatic list updates
/// - No manual refresh needed (DataStore propagates changes)
/// - Save button pattern (explicit, validated writes)
///
/// **VALIDATION**: Handled by ObligationCoordinator → ObligationValidation
///
public struct ObligationFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataStore.self) private var dataStore

    @State private var isSaving = false

    // Form data (local state)
    @State private var formData = ObligationFormData()

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

            Section("Deadline") {
                DatePicker(
                    "Deadline",
                    selection: $formData.deadline,
                    displayedComponents: .date
                )
            }

            Section("Context") {
                TextField("Requested By (optional)", text: $formData.requestedBy)

                TextField(
                    "Consequence (optional)",
                    text: $formData.consequence,
                    axis: .vertical
                )
                .lineLimit(2...4)
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
        .navigationTitle("New Obligation")
    
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        isSaving = true
                        defer { isSaving = false }

                        do {
                            try await dataStore.createObligation(from: formData)
                            dismiss()
                        } catch {
                            // Error displayed via .errorAlert(dataStore:)
                        }
                    }
                }
                .disabled(isSaving || formData.title.isEmpty)
            }
        }
        .errorAlert(dataStore: dataStore)
        .overlay {
            if isSaving {
                ProgressView()
            }
        }
    }
}
