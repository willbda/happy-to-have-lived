//
// ImportResultView.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// Display import operation results with success/failure breakdown.
//
// PATTERN:
// - Shows summary message with counts (imported, skipped, failed)
// - Color-coded status indicators (green = success, yellow = partial, red = failure)
// - Expandable error details for failed records
// - "Done" button to dismiss
//

import SwiftUI
import Services

struct ImportResultView: View {
    let result: ImportResult
    let entityTypeName: String
    let onDismiss: () -> Void

    @State private var showErrorDetails = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Status icon
                statusIcon
                    .font(.system(size: 60))
                    .padding(.top, 32)

                // Summary message
                Text(result.summaryMessage)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Statistics
                statistics
                    .padding(.horizontal)

                // Error details (if any)
                if !result.failed.isEmpty {
                    errorDetailsSection
                        .padding(.horizontal)
                }

                Spacer()

                // Done button
                Button(action: onDismiss) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Import Complete")
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        if result.isFullSuccess {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if result.isPartialSuccess {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        } else {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    // MARK: - Statistics

    @ViewBuilder
    private var statistics: some View {
        VStack(spacing: 16) {
            statisticRow(
                icon: "checkmark.circle.fill",
                color: .green,
                label: "Imported",
                value: "\(result.imported)"
            )

            if result.skipped > 0 {
                statisticRow(
                    icon: "minus.circle.fill",
                    color: .orange,
                    label: "Skipped",
                    value: "\(result.skipped)"
                )
            }

            if !result.failed.isEmpty {
                statisticRow(
                    icon: "xmark.circle.fill",
                    color: .red,
                    label: "Failed",
                    value: "\(result.failed.count)"
                )
            }

            Divider()

            statisticRow(
                icon: "doc.text.fill",
                color: .secondary,
                label: "Total Records",
                value: "\(result.totalRecords)"
            )
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func statisticRow(
        icon: String,
        color: Color,
        label: String,
        value: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 24)

            Text(label)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.body.bold())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Error Details Section

    @ViewBuilder
    private var errorDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toggle button
            Button(action: { showErrorDetails.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: showErrorDetails ? "chevron.down" : "chevron.right")
                        .font(.caption)

                    Text("Error Details")
                        .font(.headline)

                    Spacer()

                    Text("\(result.failed.count) errors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)

            // Expandable error list
            if showErrorDetails {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(result.failed, id: \.rowNumber) { failure in
                            errorRow(rowNumber: failure.rowNumber, error: failure.error)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 200)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private func errorRow(rowNumber: Int, error: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Row \(rowNumber)")
                .font(.caption.bold())
                .foregroundStyle(.red)
                .frame(width: 60, alignment: .leading)

            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(8)
        .background(Color.red.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview("Full Success") {
    ImportResultView(
        result: ImportResult(
            totalRecords: 15,
            imported: 15,
            skipped: 0,
            failed: []
        ),
        entityTypeName: "Actions",
        onDismiss: {}
    )
    .frame(width: 600, height: 500)
}

#Preview("Partial Success") {
    ImportResultView(
        result: ImportResult(
            totalRecords: 20,
            imported: 15,
            skipped: 3,
            failed: [
                (rowNumber: 5, error: "Action title is required"),
                (rowNumber: 12, error: "Invalid measure ID: measure not found")
            ]
        ),
        entityTypeName: "Goals",
        onDismiss: {}
    )
    .frame(width: 600, height: 500)
}

#Preview("Complete Failure") {
    ImportResultView(
        result: ImportResult(
            totalRecords: 10,
            imported: 0,
            skipped: 0,
            failed: [
                (rowNumber: 2, error: "Missing required field: title"),
                (rowNumber: 3, error: "Invalid date format"),
                (rowNumber: 4, error: "Duplicate ID detected"),
                (rowNumber: 5, error: "Foreign key constraint failed"),
                (rowNumber: 6, error: "Validation error: urgency must be 1-10")
            ]
        ),
        entityTypeName: "Personal Values",
        onDismiss: {}
    )
    .frame(width: 600, height: 500)
}
