//
// EmbeddingManagementView.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: UI for managing semantic embeddings cache
// PATTERN: SwiftUI view with @Observable ViewModel
//
// FEATURES:
// - View embedding statistics by entity type
// - Purge orphaned embeddings (cache cleanup)
// - Regenerate missing embeddings (backfill)
// - Force regenerate all embeddings
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
public struct EmbeddingManagementView: View {
    @State private var viewModel = EmbeddingManagementViewModel()
    @State private var showPurgeConfirmation = false
    @State private var showDeleteAllConfirmation = false
    @State private var showForceRegenerateConfirmation = false

    public init() {}

    public var body: some View {
        List {
            // Statistics Section
            if let stats = viewModel.stats {
                statisticsSection(stats: stats)
            }

            // Actions Section
            actionsSection

            // Results Section
            if viewModel.hasResult || viewModel.hasError {
                resultsSection
            }
        }
        .navigationTitle("Embedding Management")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await viewModel.loadStats()
        }
        .refreshable {
            await viewModel.loadStats()
        }
        .alert("Purge Orphaned Embeddings?", isPresented: $showPurgeConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Purge", role: .destructive) {
                Task {
                    await viewModel.purgeOrphanedEmbeddings()
                }
            }
        } message: {
            if let stats = viewModel.stats {
                Text("This will delete approximately \(stats.orphanedCount) orphaned embeddings. Latest versions will be preserved.")
            }
        }
        .alert("Delete ALL Embeddings?", isPresented: $showDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                Task {
                    await viewModel.deleteAllEmbeddings()
                }
            }
        } message: {
            Text("⚠️ This will delete ALL \(viewModel.stats?.totalEmbeddings ?? 0) embeddings. You can regenerate them afterward.")
        }
        .alert("Force Regenerate All?", isPresented: $showForceRegenerateConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Regenerate", role: .destructive) {
                Task {
                    await viewModel.forceRegenerateAll()
                }
            }
        } message: {
            Text("This will delete and regenerate ALL embeddings. This may take several minutes.")
        }
    }

    // MARK: - Statistics Section

    @ViewBuilder
    private func statisticsSection(stats: EmbeddingStats) -> some View {
        Section {
            // Overview
            LabeledContent("Total Embeddings", value: "\(stats.totalEmbeddings)")
            LabeledContent("Estimated Size", value: String(format: "%.1f MB", stats.estimatedSizeMB))

            if stats.hasOrphanedEmbeddings {
                Label {
                    Text("~\(stats.orphanedCount) orphaned embeddings")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Overview")
        }

        // Goals
        Section {
            entityTypeRow(
                title: "Goals",
                unique: stats.goalTitleOnlyUnique,
                titleOnly: stats.goalTitleOnlyCount,
                fullContext: stats.goalFullContextCount,
                bloatFactor: stats.goalBloatFactor
            )
        } header: {
            Text("Goals")
        }

        // Values
        Section {
            entityTypeRow(
                title: "Values",
                unique: stats.valueFullContextUnique,
                titleOnly: stats.valueTitleOnlyCount,
                fullContext: stats.valueFullContextCount,
                bloatFactor: stats.valueBloatFactor
            )
        } header: {
            Text("Values")
        }

        // Actions
        Section {
            entityTypeRow(
                title: "Actions",
                unique: stats.actionTitleOnlyUnique,
                titleOnly: stats.actionTitleOnlyCount,
                fullContext: stats.actionFullContextCount,
                bloatFactor: 1.0  // Actions typically don't bloat
            )
        } header: {
            Text("Actions")
        }

        // Measures & Terms
        Section {
            HStack {
                Text("Measures")
                Spacer()
                Text("\(stats.measureTotalCount)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Terms")
                Spacer()
                Text("\(stats.termTotalCount)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Semantic Cache")
                Spacer()
                Text("\(stats.semanticCacheCount)")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Other")
        }
    }

    @ViewBuilder
    private func entityTypeRow(
        title: String,
        unique: Int,
        titleOnly: Int,
        fullContext: Int,
        bloatFactor: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Unique Entities")
                Spacer()
                Text("\(unique)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Title-Only Embeddings")
                Spacer()
                Text("\(titleOnly)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Full-Context Embeddings")
                Spacer()
                Text("\(fullContext)")
                    .foregroundStyle(.secondary)
            }

            if bloatFactor > 2.0 {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Bloat Factor: \(String(format: "%.1fx", bloatFactor))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                }
            }
        }
        .font(.subheadline)
    }

    // MARK: - Actions Section

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            // Purge Orphaned
            Button {
                showPurgeConfirmation = true
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("Purge Orphaned Embeddings")
                        Text("Remove old versions, keep latest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "trash")
                        .foregroundStyle(.orange)
                }
            }
            .disabled(viewModel.isLoading || !(viewModel.stats?.hasOrphanedEmbeddings ?? false))

            // Regenerate Missing
            Button {
                Task {
                    await viewModel.regenerateMissingEmbeddings()
                }
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("Regenerate Missing")
                        Text("Backfill embeddings for entities without them")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.blue)
                }
            }
            .disabled(viewModel.isLoading)
        } header: {
            Text("Maintenance")
        }

        Section {
            // Force Regenerate All
            Button {
                showForceRegenerateConfirmation = true
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("Force Regenerate All")
                        Text("Delete and regenerate all embeddings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.purple)
                }
            }
            .disabled(viewModel.isLoading)

            // Delete All
            Button {
                showDeleteAllConfirmation = true
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("Delete All Embeddings")
                        Text("Nuclear option - removes everything")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.red)
                }
            }
            .disabled(viewModel.isLoading)
        } header: {
            Text("Nuclear Options")
        } footer: {
            Text("Use force regenerate or delete all with caution. These operations may take several minutes.")
        }
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        Section {
            if let result = viewModel.operationResult {
                Label {
                    Text(result)
                } icon: {
                    if result.contains("✅") {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if result.contains("⚠️") {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Label {
                    Text(error)
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Results")
        }
    }
}

#Preview {
    NavigationStack {
        EmbeddingManagementView()
    }
}
