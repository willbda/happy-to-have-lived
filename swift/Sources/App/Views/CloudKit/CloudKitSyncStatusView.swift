//
// CloudKitSyncStatusView.swift
// Written by Claude Code on 2025-11-21
//
// PURPOSE: Monitor and control CloudKit sync status
//
// FEATURES:
// - View sync status (connected/disconnected/error)
// - Manual sync trigger button
// - Last sync timestamp
// - Account status display
//
// PATTERN: Simple status view with manual trigger
// FUTURE: Add detailed sync logs, conflict resolution UI

import SwiftUI
import CloudKit
import Database

/// View displaying CloudKit sync status and manual controls
///
/// **Features**:
/// - Account status (available/restricted/no account)
/// - Manual sync trigger
/// - Last sync timestamp (placeholder for future implementation)
/// - Error display
///
/// **Usage**: Navigate from Settings or HomeView menu
@available(iOS 17, macOS 14, *)
public struct CloudKitSyncStatusView: View {

    // MARK: - State

    @State private var accountStatus: CKAccountStatus?
    @State private var isLoading = false
    @State private var lastSyncDate: Date?
    @State private var errorMessage: String?
    @State private var isSyncing = false

    // MARK: - Body

    public var body: some View {
        List {
            // Account Status Section
            Section {
                if let status = accountStatus {
                    LabeledContent("Status") {
                        statusBadge(for: status)
                    }
                } else {
                    LabeledContent("Status") {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Unknown")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("iCloud Account")
            } footer: {
                if let status = accountStatus {
                    Text(statusDescription(for: status))
                        .font(.caption)
                }
            }

            // Sync Controls Section
            Section {
                Button {
                    Task {
                        await triggerManualSync()
                    }
                } label: {
                    HStack {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")

                        Spacer()

                        if isSyncing {
                            ProgressView()
                        }
                    }
                }
                .disabled(isSyncing || accountStatus != .available)

                if let lastSync = lastSyncDate {
                    LabeledContent("Last Sync") {
                        Text(lastSync, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Sync Controls")
            }

            // Error Section
            if let error = errorMessage {
                Section {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                } header: {
                    Label("Error", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            // Info Section
            Section {
                Text("CloudKit syncs your goals, actions, and values across all your devices signed into the same iCloud account.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("About CloudKit Sync")
            }
        }
        .navigationTitle("CloudKit Sync")
        .task {
            await checkAccountStatus()
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func statusBadge(for status: CKAccountStatus) -> some View {
        switch status {
        case .available:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .restricted:
            Label("Restricted", systemImage: "xmark.circle.fill")
                .foregroundStyle(.orange)
        case .noAccount:
            Label("Not Signed In", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .couldNotDetermine:
            Label("Unknown", systemImage: "questionmark.circle.fill")
                .foregroundStyle(.gray)
        case .temporarilyUnavailable:
            Label("Temporarily Unavailable", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        @unknown default:
            Label("Unknown", systemImage: "questionmark.circle.fill")
                .foregroundStyle(.gray)
        }
    }

    private func statusDescription(for status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "iCloud account is available. Your data syncs automatically."
        case .restricted:
            return "iCloud access is restricted on this device. Check Screen Time or parental controls."
        case .noAccount:
            return "No iCloud account is signed in. Sign in to Settings to enable sync."
        case .couldNotDetermine:
            return "Unable to determine iCloud account status. Check your internet connection."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable. Try again later."
        @unknown default:
            return "Unknown iCloud account status."
        }
    }

    // MARK: - Actions

    @MainActor
    private func checkAccountStatus() async {
        isLoading = true
        errorMessage = nil

        do {
            let container = CKContainer.default()
            let status = try await container.accountStatus()
            self.accountStatus = status

            if status == .available {
                // Optionally fetch last sync timestamp from UserDefaults
                // For now, we just clear errors
                errorMessage = nil
            }
        } catch {
            errorMessage = "Failed to check account status: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @MainActor
    private func triggerManualSync() async {
        guard accountStatus == .available else {
            errorMessage = "Cannot sync: iCloud account not available"
            return
        }

        isSyncing = true
        errorMessage = nil

        do {
            try await CloudKitManualSync.triggerSync()
            lastSyncDate = Date()
            errorMessage = nil
        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }

        isSyncing = false
    }
}

// MARK: - Preview

#Preview("CloudKit Available") {
    NavigationStack {
        CloudKitSyncStatusView()
    }
}

#Preview("CloudKit Not Available") {
    NavigationStack {
        CloudKitSyncStatusView()
    }
}
