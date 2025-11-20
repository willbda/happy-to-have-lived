// SyncDebugView.swift
// Debug controls for CloudKit sync
//
// Written by Claude Code on 2025-11-17

import SwiftUI
import Dependencies
import SQLiteData
import Database  // For CloudKitManualSync

@MainActor
struct SyncDebugView: View {
    @Dependency(\.defaultSyncEngine) var syncEngine
    @Dependency(\.defaultDatabase) var database
    @State private var isResetting = false
    @State private var isSyncing = false
    @State private var showConfirmation = false
    @State private var lastSyncMessage: String?
    @State private var metadataStats: MetadataStats?

    var body: some View {
        Form {
            Section("Sync Status") {
                LabeledContent("Is Running") {
                    Text(syncEngine.isRunning ? "✅ Yes" : "⛔️ No")
                }
                LabeledContent("Is Synchronizing") {
                    Text(syncEngine.isSynchronizing ? "🔄 Yes" : "✅ No")
                }
                LabeledContent("Is Fetching") {
                    Text(syncEngine.isFetchingChanges ? "⬇️ Yes" : "—")
                }
                LabeledContent("Is Sending") {
                    Text(syncEngine.isSendingChanges ? "⬆️ Yes" : "—")
                }

                if let message = lastSyncMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Metadata State") {
                if let stats = metadataStats {
                    LabeledContent("Goals in Database") {
                        Text("\(stats.goalsCount)")
                    }
                    LabeledContent("Metadata Records") {
                        Text("\(stats.metadataCount)")
                    }
                    LabeledContent("State Tokens") {
                        Text("\(stats.stateTokenCount)")
                    }

                    if stats.goalsCount == 0 && stats.metadataCount > 0 {
                        Text("⚠️ Stale metadata detected - database is empty but metadata exists")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("Loading...")
                        .foregroundStyle(.secondary)
                }

                Button("Refresh Stats") {
                    Task { await loadMetadataStats() }
                }
            }

            Section("Manual Sync") {
                Button {
                    Task { await forceFetch() }
                } label: {
                    HStack {
                        Text("Fetch Changes from iCloud")
                        Spacer()
                        if isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isSyncing)

                Text("Calls SyncEngine.fetchChanges() to download pending records")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Engine Controls") {
                Button("Start Sync Engine") {
                    Task {
                        try? await syncEngine.start()
                    }
                }
                .disabled(syncEngine.isRunning)

                Button("Stop Sync Engine") {
                    syncEngine.stop()
                }
                .disabled(!syncEngine.isRunning)
            }

            Section("Nuclear Options") {
                Button("Delete All & Re-sync", role: .destructive) {
                    showConfirmation = true
                }
                .disabled(isResetting)

                Text("Deletes all local data and re-downloads from CloudKit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("CloudKit Sync")
        .task {
            await loadMetadataStats()
        }
        .confirmationDialog(
            "Delete all local data?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete & Re-sync", role: .destructive) {
                Task { await performReset() }
            }
        } message: {
            Text("This removes all local data and re-downloads from CloudKit. Unsynced changes will be lost.")
        }
        .overlay {
            if isResetting {
                ZStack {
                    Color.black.opacity(0.3)
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Resetting...")
                            .font(.headline)
                    }
                    .padding(32)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func forceFetch() async {
        isSyncing = true
        lastSyncMessage = nil

        do {
            // TODO: SyncEngine API change - fetchChanges() method not available
            // The manual fetch functionality is temporarily disabled until we determine
            // the correct API for triggering a CloudKit sync fetch
            // try await syncEngine.fetchChanges()
            lastSyncMessage = "⚠️ Manual fetch not available (API change)"
            await loadMetadataStats()
        } catch {
            lastSyncMessage = "❌ Fetch failed: \(error.localizedDescription)"
        }

        isSyncing = false
    }

    private func performReset() async {
        isResetting = true

        do {
            try await syncEngine.deleteLocalData()
            lastSyncMessage = "✅ Reset complete"
            await loadMetadataStats()
        } catch {
            lastSyncMessage = "❌ Reset failed: \(error)"
        }

        isResetting = false
    }

    private func loadMetadataStats() async {
        do {
            let stats = try await database.read { db in
                let goalsCount = try #sql(
                    "SELECT COUNT(*) FROM goals",
                    as: Int.self
                ).fetchOne(db) ?? 0

                let metadataCount = try #sql(
                    "SELECT COUNT(*) FROM sqlitedata_icloud_metadata",
                    as: Int.self
                ).fetchOne(db) ?? 0

                let stateTokenCount = try #sql(
                    "SELECT COUNT(*) FROM sqlitedata_icloud_stateSerialization",
                    as: Int.self
                ).fetchOne(db) ?? 0

                return MetadataStats(
                    goalsCount: goalsCount,
                    metadataCount: metadataCount,
                    stateTokenCount: stateTokenCount
                )
            }
            metadataStats = stats
        } catch {
            print("❌ Failed to load metadata stats: \(error)")
        }
    }
}

struct MetadataStats {
    let goalsCount: Int
    let metadataCount: Int
    let stateTokenCount: Int
}

#Preview {
    NavigationStack {
        SyncDebugView()
    }
}
