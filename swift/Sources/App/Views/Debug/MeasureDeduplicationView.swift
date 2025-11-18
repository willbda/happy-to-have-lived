//
// MeasureDeduplicationView.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE: In-app UI for merging duplicate measures
// USAGE: Debug/Admin view for one-off historical cleanup
//
// PATTERN: List of duplicate groups with merge actions
// - Shows canonical measure (to keep)
// - Shows duplicates (to merge)
// - Preview button (dry run)
// - Merge button (atomic transaction)
//
// SAFETY:
// - Requires explicit user confirmation
// - Shows detailed preview before merge
// - All operations atomic (all-or-nothing)
// - Uses MeasureDeduplicationCoordinator
//

import Dependencies
import Models
import Services
import SwiftUI

@MainActor
@Observable
final class MeasureDeduplicationViewModel {
    // State
    var duplicateGroups: [DuplicateGroup] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var successMessage: String?

    // Dependencies
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    private lazy var coordinator: MeasureDeduplicationCoordinator = {
        MeasureDeduplicationCoordinator(database: database)
    }()

    func loadDuplicates() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            duplicateGroups = try await coordinator.findAllDuplicates()

            if duplicateGroups.isEmpty {
                successMessage = "✅ No duplicates found! Database is clean."
            }
        } catch {
            errorMessage = "Failed to load duplicates: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func previewMerge(group: DuplicateGroup) async -> MeasureMergeResult? {
        do {
            return try await coordinator.previewMerge(group: group)
        } catch {
            errorMessage = "Preview failed: \(error.localizedDescription)"
            return nil
        }
    }

    func merge(group: DuplicateGroup) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let result = try await coordinator.merge(group: group)
            successMessage = "✅ " + result.summary

            // Reload to reflect changes
            await loadDuplicates()
        } catch {
            errorMessage = "Merge failed: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

public struct MeasureDeduplicationView: View {
    @State private var viewModel = MeasureDeduplicationViewModel()
    @State private var selectedGroup: DuplicateGroup?
    @State private var showingPreview = false
    @State private var previewResult: MeasureMergeResult?

    public init() {}

    public var body: some View {
        List {
            // Header section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Measure Deduplication")
                        .font(.headline)
                    Text("One-off utility for merging duplicate measures created before coordinator refactor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let successMessage = viewModel.successMessage {
                        Text(successMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            // Duplicate groups
            if viewModel.isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Loading duplicates...")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if viewModel.duplicateGroups.isEmpty {
                Section {
                    Text("No duplicates found")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(viewModel.duplicateGroups) { group in
                    Section(header: Text("\(group.unit) (\(group.measureType))")) {
                        // Canonical measure (to keep)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text("Canonical (Keep)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            MeasureRow(measure: group.canonicalMeasure)
                        }

                        // Duplicates (to merge)
                        ForEach(group.duplicates) { duplicate in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "arrow.triangle.merge")
                                        .foregroundStyle(.orange)
                                    Text("Duplicate (Merge)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                MeasureRow(measure: duplicate)
                            }
                        }

                        // Actions
                        HStack(spacing: 12) {
                            Button {
                                selectedGroup = group
                                Task {
                                    previewResult = await viewModel.previewMerge(group: group)
                                    showingPreview = true
                                }
                            } label: {
                                Label("Preview", systemImage: "eye")
                            }
                            .buttonStyle(.bordered)

                            Button(role: .destructive) {
                                selectedGroup = group
                                Task {
                                    await viewModel.merge(group: group)
                                }
                            } label: {
                                Label("Merge Now", systemImage: "arrow.triangle.merge")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isLoading)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Error message
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Deduplicate Measures")
        .task {
            await viewModel.loadDuplicates()
        }
        .sheet(isPresented: $showingPreview) {
            if let result = previewResult {
                PreviewSheet(result: result)
            }
        }
    }
}

// MARK: - Helper Views

struct MeasureRow: View {
    let measure: MeasureData

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @State private var usageCount: (actions: Int, goals: Int) = (0, 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(measure.displayTitle)
                .font(.body)

            Text("Unit: \(measure.unit) • Type: \(measure.measureType)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Used in: \(usageCount.actions) actions, \(usageCount.goals) goals")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Created: \(measure.logTime.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text("ID: \(measure.id.uuidString.prefix(8))...")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .task {
            await loadUsageCount()
        }
    }

    private func loadUsageCount() async {
        do {
            usageCount = try await database.read { db in
                // Use raw SQL for counts
                let actionSQL = "SELECT COUNT(*) FROM measuredActions WHERE measureId = ?"
                let actionCount = try Int.fetchOne(db, sql: actionSQL, arguments: [measure.id.uuidString.lowercased()]) ?? 0

                let goalSQL = "SELECT COUNT(*) FROM expectationMeasures WHERE measureId = ?"
                let goalCount = try Int.fetchOne(db, sql: goalSQL, arguments: [measure.id.uuidString.lowercased()]) ?? 0

                return (actionCount, goalCount)
            }
        } catch {
            print("❌ Failed to load usage count: \(error)")
        }
    }
}

struct PreviewSheet: View {
    let result: MeasureMergeResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Merge Preview") {
                    Text("Canonical Measure: \(result.canonicalTitle)")
                    Text("Canonical ID: \(result.canonicalId)")
                }

                Section("Changes") {
                    Text("Measured Actions Updated: \(result.measuredActionsUpdated)")
                    Text("Expectation Measures Updated: \(result.expectationMeasuresUpdated)")
                    Text("Duplicates Deleted: \(result.duplicatesDeleted)")
                }

                Section("Merged IDs") {
                    ForEach(result.mergedIds, id: \.self) { id in
                        Text(id.uuidString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Merge Preview")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MeasureDeduplicationView()
    }
}
