//
// ImportTypes.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// Data structures for import preview and result reporting.
//
// PATTERN:
// - ImportRecord: Single record with validation status (for preview UI)
// - ImportStatus: Enum describing validation state
// - ImportResult: Summary of completed import operation
//

import Foundation
import Models

// MARK: - Import Record

/// A single record from import file with validation status
///
/// **Usage**: Preview UI displays array of ImportRecords with checkboxes.
/// User can uncheck invalid/unwanted records before confirming import.
///
/// **Generic**: Works with any Data type (ActionData, GoalData, etc.)
public struct ImportRecord<T: Identifiable>: Identifiable {
    public let id: UUID  // Matches T.id for SwiftUI List
    public let rowNumber: Int
    public let data: T
    public var status: ImportStatus
    public var validationErrors: [ValidationError]
    public var duplicateMatches: [DuplicateMatch]
    public var shouldImport: Bool  // User checkbox state

    public init(
        id: UUID,
        rowNumber: Int,
        data: T,
        status: ImportStatus,
        validationErrors: [ValidationError] = [],
        duplicateMatches: [DuplicateMatch] = [],
        shouldImport: Bool = true
    ) {
        self.id = id
        self.rowNumber = rowNumber
        self.data = data
        self.status = status
        self.validationErrors = validationErrors
        self.duplicateMatches = duplicateMatches
        self.shouldImport = shouldImport
    }

    /// User-friendly status description for UI
    public var statusDescription: String {
        switch status {
        case .valid:
            return "Ready to import"
        case .duplicateID(let existingId):
            return "Duplicate ID: \(existingId)"
        case .semanticDuplicate(let similarity):
            return "Similar record (\(Int(similarity * 100))% match)"
        case .validationError:
            return validationErrors.first?.userMessage ?? "Validation failed"
        case .foreignKeyMissing(let entity):
            return "Missing \(entity)"
        }
    }

    /// Badge color for status indicator
    public var statusColor: StatusColor {
        switch status {
        case .valid:
            return .green
        case .duplicateID:
            return .orange
        case .semanticDuplicate:
            return .yellow
        case .validationError, .foreignKeyMissing:
            return .red
        }
    }

    public enum StatusColor {
        case green, yellow, orange, red
    }
}

// MARK: - Import Status

/// Validation status for import record
///
/// **Pattern**: Enum cases cover all validation scenarios.
/// UI shows different badges/warnings based on status.
public enum ImportStatus: Equatable, Sendable {
    /// Record is valid and ready to import
    case valid

    /// Record ID already exists in database
    /// Associated value: existing record's ID
    case duplicateID(existing: UUID)

    /// Semantically similar record found (NLEmbedding match)
    /// Associated value: similarity score (0.0-1.0)
    case semanticDuplicate(similarity: Double)

    /// Business rule validation failed
    case validationError

    /// Foreign key reference not found (measure, goal, value)
    /// Associated value: entity type name
    case foreignKeyMissing(entity: String)
}

// MARK: - Duplicate Match

// MARK: - Import Result
//
// Note: DuplicateMatch is defined in Services/Deduplication/DuplicationResult.swift
// and is reused here for semantic duplicate detection during import.

/// Summary of completed import operation
///
/// **Usage**: Shown in ImportResultView after confirmation.
/// Provides detailed success/failure breakdown.
public struct ImportResult: Sendable {
    public let totalRecords: Int
    public let imported: Int
    public let skipped: Int
    public let failed: [(rowNumber: Int, error: String)]

    public init(
        totalRecords: Int,
        imported: Int,
        skipped: Int,
        failed: [(rowNumber: Int, error: String)]
    ) {
        self.totalRecords = totalRecords
        self.imported = imported
        self.skipped = skipped
        self.failed = failed
    }

    /// User-friendly summary message
    public var summaryMessage: String {
        if failed.isEmpty && skipped == 0 {
            return "✓ Successfully imported all \(imported) records"
        } else if failed.isEmpty {
            return "✓ Imported \(imported) of \(totalRecords) records (\(skipped) skipped)"
        } else {
            return "⚠️ Imported \(imported) of \(totalRecords) records (\(failed.count) failed, \(skipped) skipped)"
        }
    }

    /// Whether import was completely successful
    public var isFullSuccess: Bool {
        failed.isEmpty && skipped == 0
    }

    /// Whether import had partial success
    public var isPartialSuccess: Bool {
        imported > 0 && (!failed.isEmpty || skipped > 0)
    }

    /// Whether import completely failed
    public var isCompleteFailure: Bool {
        imported == 0
    }
}

// MARK: - Convenience Extensions

extension ImportRecord where T == ActionData {
    /// Preview display title
    public var displayTitle: String {
        data.title ?? "Untitled Action"
    }
}

extension ImportRecord where T == GoalData {
    /// Preview display title
    public var displayTitle: String {
        data.title ?? "Untitled Goal"
    }
}

extension ImportRecord where T == PersonalValueData {
    /// Preview display title
    public var displayTitle: String {
        data.title
    }
}

extension ImportRecord where T == TimePeriodData {
    /// Preview display title
    public var displayTitle: String {
        data.timePeriodTitle ?? "Term \(data.termNumber)"
    }
}
