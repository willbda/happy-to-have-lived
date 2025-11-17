//
// ImportPreviewView.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// Preview import records with validation status and user selection.
//
// PATTERN:
// - Generic over entity type (works with any ImportRecord<T>)
// - User can toggle checkboxes to select/deselect records
// - Shows validation errors inline
// - Displays duplicate matches with "View Existing" buttons
// - Summary footer shows selection count
// - "Import Selected" triggers confirmation flow
//

import SwiftUI
import Services
import Models

struct ImportPreviewView<T: Identifiable & Sendable>: View {
    let records: [ImportRecord<T>]
    let entityTypeName: String
    let onConfirm: ([ImportRecord<T>]) async throws -> Void
    let onCancel: () -> Void

    @State private var editableRecords: [ImportRecord<T>]
    @State private var isImporting = false
    @State private var errorMessage: String?

    init(
        records: [ImportRecord<T>],
        entityTypeName: String,
        onConfirm: @escaping ([ImportRecord<T>]) async throws -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.records = records
        self.entityTypeName = entityTypeName
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self._editableRecords = State(initialValue: records)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Record list
                List {
                    ForEach($editableRecords) { $record in
                        recordRow(record: $record)
                    }
                }
                .listStyle(.plain)

                // Summary footer
                summaryFooter
            }
            .navigationTitle("Import Preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isImporting)
                }
            }
            .alert("Import Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Record Row

    @ViewBuilder
    private func recordRow(record: Binding<ImportRecord<T>>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: checkbox + title + status badge
            HStack(spacing: 12) {
                // Checkbox
                Button(action: {
                    record.wrappedValue.shouldImport.toggle()
                }) {
                    Image(systemName: record.wrappedValue.shouldImport ? "checkmark.square.fill" : "square")
                        .foregroundStyle(record.wrappedValue.shouldImport ? .blue : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(record.wrappedValue.shouldImport ? "Selected" : "Not selected")

                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle(for: record.wrappedValue))
                        .font(.body)
                        .foregroundStyle(record.wrappedValue.shouldImport ? .primary : .secondary)

                    Text("Row \(record.wrappedValue.rowNumber)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Status badge
                statusBadge(for: record.wrappedValue)
            }
            .padding(.vertical, 4)

            // Validation errors (if any)
            if !record.wrappedValue.validationErrors.isEmpty {
                validationErrorsView(errors: record.wrappedValue.validationErrors)
            }

            // Duplicate matches (if any)
            if !record.wrappedValue.duplicateMatches.isEmpty {
                duplicateMatchesView(matches: record.wrappedValue.duplicateMatches)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Status Badge

    @ViewBuilder
    private func statusBadge(for record: ImportRecord<T>) -> some View {
        let color = badgeColor(for: record.statusColor)
        let icon = badgeIcon(for: record.status)

        Label {
            Text(record.statusDescription)
                .font(.caption)
        } icon: {
            Image(systemName: icon)
        }
        .labelStyle(.iconOnly)
        .foregroundStyle(color)
        .font(.body)
        .accessibilityLabel(record.statusDescription)
    }

    private func badgeColor(for statusColor: ImportRecord<T>.StatusColor) -> Color {
        switch statusColor {
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        }
    }

    private func badgeIcon(for status: ImportStatus) -> String {
        switch status {
        case .valid:
            return "checkmark.circle.fill"
        case .duplicateID:
            return "exclamationmark.triangle.fill"
        case .semanticDuplicate:
            return "questionmark.circle.fill"
        case .validationError:
            return "xmark.circle.fill"
        case .foreignKeyMissing:
            return "link.circle.fill"
        }
    }

    // MARK: - Validation Errors View

    @ViewBuilder
    private func validationErrorsView(errors: [ValidationError]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(errors, id: \.userMessage) { error in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)

                    Text(error.userMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Duplicate Matches View

    @ViewBuilder
    private func duplicateMatchesView(matches: [DuplicateMatch]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Similar Records Found:")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(matches, id: \.id) { match in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(match.title)
                            .font(.caption)

                        Text("\(Int(match.similarity * 100))% match")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("View") {
                        // TODO: Navigate to existing record detail
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(8)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Summary Footer

    @ViewBuilder
    private var summaryFooter: some View {
        VStack(spacing: 12) {
            Divider()

            // Selection summary
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)

                Text("\(selectedCount) of \(records.count) records selected")
                    .font(.subheadline)

                Spacer()

                // Select All / Deselect All toggle
                Button(allSelected ? "Deselect All" : "Select All") {
                    toggleAllSelection()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)

            // Import button
            Button(action: confirmImport) {
                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Import Selected", systemImage: "square.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedCount == 0 || isImporting)
            .controlSize(.large)
            .padding(.horizontal)
            .accessibilityLabel("Import \(selectedCount) selected \(entityTypeName)")
        }
        .padding(.vertical)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Computed Properties

    private var selectedCount: Int {
        editableRecords.filter { $0.shouldImport }.count
    }

    private var allSelected: Bool {
        selectedCount == records.count
    }

    // MARK: - Display Title

    private func displayTitle(for record: ImportRecord<T>) -> String {
        // Use convenience extensions from ImportTypes.swift
        switch record.data {
        case let action as ActionData:
            return action.title ?? "Untitled Action"
        case let goal as GoalData:
            return goal.title ?? "Untitled Goal"
        case let value as PersonalValueData:
            return value.title
        case let period as TimePeriodData:
            return period.timePeriodTitle ?? "Term \(period.termNumber)"
        default:
            return "Record \(record.rowNumber)"
        }
    }

    // MARK: - Actions

    private func toggleAllSelection() {
        let newValue = !allSelected
        for index in editableRecords.indices {
            editableRecords[index].shouldImport = newValue
        }
    }

    private func confirmImport() {
        Task { @MainActor in
            isImporting = true
            defer { isImporting = false }

            do {
                try await onConfirm(editableRecords)
            } catch let error as ValidationError {
                errorMessage = error.userMessage
            } catch {
                errorMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Preview

#Preview("Valid Records") {
    let records: [ImportRecord<ActionData>] = [
        ImportRecord(
            id: UUID(),
            rowNumber: 2,
            data: ActionData(
                id: UUID(),
                title: "Morning Run",
                detailedDescription: "5km jog around the park",
                freeformNotes: nil,
                logTime: Date(),
                durationMinutes: 30,
                startTime: Date(),
                measurements: [],
                contributions: []
            ),
            status: .valid,
            validationErrors: [],
            duplicateMatches: [],
            shouldImport: true
        ),
        ImportRecord(
            id: UUID(),
            rowNumber: 3,
            data: ActionData(
                id: UUID(),
                title: "Daily Reading",
                detailedDescription: "Read 30 pages",
                freeformNotes: nil,
                logTime: Date(),
                durationMinutes: 45,
                startTime: Date(),
                measurements: [],
                contributions: []
            ),
            status: .valid,
            validationErrors: [],
            duplicateMatches: [],
            shouldImport: true
        )
    ]

    ImportPreviewView(
        records: records,
        entityTypeName: "Actions",
        onConfirm: { _ in },
        onCancel: {}
    )
    .frame(width: 600, height: 500)
}

#Preview("With Errors and Duplicates") {
    let records: [ImportRecord<ActionData>] = [
        ImportRecord(
            id: UUID(),
            rowNumber: 2,
            data: ActionData(
                id: UUID(),
                title: "Morning Run",
                detailedDescription: nil,
                freeformNotes: nil,
                logTime: Date(),
                durationMinutes: 30,
                startTime: Date(),
                measurements: [],
                contributions: []
            ),
            status: .duplicateID(existing: UUID()),
            validationErrors: [],
            duplicateMatches: [],
            shouldImport: false
        ),
        ImportRecord(
            id: UUID(),
            rowNumber: 3,
            data: ActionData(
                id: UUID(),
                title: "Daily Reading Session",
                detailedDescription: nil,
                freeformNotes: nil,
                logTime: Date(),
                durationMinutes: 45,
                startTime: Date(),
                measurements: [],
                contributions: []
            ),
            status: .semanticDuplicate(similarity: 0.87),
            validationErrors: [],
            duplicateMatches: [
                DuplicateMatch(
                    entityId: UUID(),
                    title: "Reading Practice",
                    similarity: 0.87,
                    entityType: .action
                )
            ],
            shouldImport: true
        ),
        ImportRecord(
            id: UUID(),
            rowNumber: 4,
            data: ActionData(
                id: UUID(),
                title: "",
                detailedDescription: nil,
                freeformNotes: nil,
                logTime: Date(),
                durationMinutes: nil,
                startTime: Date(),
                measurements: [],
                contributions: []
            ),
            status: .validationError,
            validationErrors: [
                .emptyAction("Action title is required")
            ],
            duplicateMatches: [],
            shouldImport: false
        )
    ]

    ImportPreviewView(
        records: records,
        entityTypeName: "Actions",
        onConfirm: { _ in },
        onCancel: {}
    )
    .frame(width: 600, height: 500)
}
