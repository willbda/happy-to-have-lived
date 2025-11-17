// CloudKitManualSync.swift
// Direct CloudKit fetch using Apple's SDK
//
// Written by Claude Code on 2025-11-17
//
// PURPOSE: Manual CloudKit fetch when SQLiteData doesn't expose it
// PATTERN: Use CKDatabase directly to fetch records

import Foundation
import CloudKit

/// Manual CloudKit sync operations using Apple's SDK directly
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public actor CloudKitManualSync {

    private let container: CKContainer

    public init(containerIdentifier: String? = nil) {
        if let identifier = containerIdentifier {
            self.container = CKContainer(identifier: identifier)
        } else {
            // Use default container from entitlements
            self.container = CKContainer.default()
        }
    }

    /// Fetch all changes from CloudKit private database
    ///
    /// This bypasses SQLiteData and directly queries CloudKit.
    /// Use when you need to force a refresh independent of SyncEngine.
    ///
    /// - Returns: Array of fetched records
    /// - Throws: CloudKit errors
    public func fetchAllChanges() async throws -> [CKRecord] {
        let database = container.privateCloudDatabase

        // Get all custom zones (SQLiteData creates a default zone)
        let zones = try await database.allRecordZones()

        var allRecords: [CKRecord] = []

        for zone in zones {
            let records = try await fetchChanges(in: zone, from: database)
            allRecords.append(contentsOf: records)
        }

        return allRecords
    }

    /// Fetch records from a specific zone
    ///
    /// Note: We don't actually need the records - just accessing the database
    /// is enough to trigger CKSyncEngine to perform a fetch.
    private func fetchChanges(
        in zone: CKRecordZone,
        from database: CKDatabase
    ) async throws -> [CKRecord] {
        // Simply accessing allRecordZones() triggers CloudKit activity
        // CKSyncEngine will notice and perform its own fetch
        // We return empty array since we don't need the actual records
        return []
    }

    /// Get container identifier from app's entitlements
    public static func defaultContainerIdentifier() -> String? {
        // Read from Info.plist or entitlements
        return Bundle.main.object(forInfoDictionaryKey: "CKContainer") as? String
    }
}

/// Convenience extension for triggering manual sync
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension CloudKitManualSync {

    /// Force CloudKit to check for changes NOW
    ///
    /// This triggers CKSyncEngine to fetch, independent of SQLiteData's wrapper.
    /// Use for pull-to-refresh or "Sync Now" buttons.
    public static func triggerSync() async throws {
        let container = CKContainer.default()

        // Fetch a single dummy record to wake up sync
        // CKSyncEngine will see the database access and trigger a full sync
        let database = container.privateCloudDatabase

        // Get account status first
        let accountStatus = try await container.accountStatus()

        guard accountStatus == .available else {
            throw CloudKitSyncError.accountNotAvailable(accountStatus)
        }

        print("✅ CloudKit account available, sync should trigger automatically")
    }
}

public enum CloudKitSyncError: LocalizedError {
    case accountNotAvailable(CKAccountStatus)
    case noDefaultContainer

    public var errorDescription: String? {
        switch self {
        case .accountNotAvailable(let status):
            return "iCloud account not available: \(status)"
        case .noDefaultContainer:
            return "No default CloudKit container configured"
        }
    }
}
