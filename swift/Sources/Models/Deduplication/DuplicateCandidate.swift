// DuplicateCandidate.swift
// Tracks potential duplicate entities for user review
//
// Written by Claude Code on 2025-11-17
//
// ARCHITECTURE:
// - Synced table (working metadata shared across devices)
// - Stores similarity analysis between two entities
// - User review decisions (merged/ignored) sync across devices
//
// DESIGN PRINCIPLES:
// - Uniqueness enforced at application level (CloudKit sync compatible)
// - Status tracking enables deduplication workflow
// - Resolution history preserved for audit trail

import Foundation
import SQLiteData

/// Represents a potential duplicate entity pair requiring user review
///
/// **Database Table**: `duplicateCandidates`
/// **Purpose**: Track and manage duplicate detection results
///
/// **Design Principle**: This table stores the *results* of duplicate detection,
/// not the computation itself. Embeddings and MinHash signatures are computed
/// on-demand, but once duplicates are identified, that metadata should sync.
///
/// **Why sync this table?**
/// - User review decisions should be consistent across devices
/// - Merge operations need to be reflected everywhere
/// - "Ignore" decisions prevent re-flagging on other devices
/// - Provides audit trail for data hygiene
///
/// **Usage**:
/// ```swift
/// // Create duplicate candidate after semantic similarity check
/// let candidate = DuplicateCandidate(
///     entityType: "goal",
///     entity1Id: existingGoal.id,
///     entity2Id: newGoal.id,
///     similarity: 0.87,
///     severity: .high,
///     status: .pending
/// )
///
/// // After user review - merge entities
/// candidate.resolve(
///     resolution: .mergedInto1,
///     notes: "User confirmed these are the same goal"
/// )
/// ```
@Table
public struct DuplicateCandidate: DomainComposit {
    // MARK: - Identity

    /// Unique identifier (required by SQLiteData)
    public var id: UUID

    // MARK: - Entity Classification

    /// Type of entity being compared
    public var entityType: EntityType

    /// First entity in comparison
    public var entity1Id: UUID

    /// Second entity in comparison
    public var entity2Id: UUID

    // MARK: - Similarity Analysis

    /// Cosine similarity score (0.0 to 1.0)
    /// Higher = more similar
    public var similarity: Double

    /// Severity classification for prioritization
    public var severity: Severity

    // MARK: - Processing State

    /// Current status of this duplicate candidate
    public var status: Status

    /// When this candidate was created
    public var createdAt: Date

    /// When user reviewed it (if applicable)
    public var reviewedAt: Date?

    /// When it was resolved (if applicable)
    public var resolvedAt: Date?

    // MARK: - Resolution Details

    /// How this duplicate was resolved
    public var resolution: Resolution?

    /// Optional notes from user or system
    public var resolutionNotes: String?

    // MARK: - Initialization

    public init(
        entityType: EntityType,
        entity1Id: UUID,
        entity2Id: UUID,
        similarity: Double,
        severity: Severity,
        status: Status = .pending,
        createdAt: Date = Date(),
        reviewedAt: Date? = nil,
        resolvedAt: Date? = nil,
        resolution: Resolution? = nil,
        resolutionNotes: String? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.entityType = entityType
        self.entity1Id = entity1Id
        self.entity2Id = entity2Id
        self.similarity = similarity
        self.severity = severity
        self.status = status
        self.createdAt = createdAt
        self.reviewedAt = reviewedAt
        self.resolvedAt = resolvedAt
        self.resolution = resolution
        self.resolutionNotes = resolutionNotes
    }
}

// MARK: - Supporting Types

extension DuplicateCandidate {
    /// Entity types that can have duplicates
    ///
    /// NOTE: QueryRepresentable + QueryBindable conformance required by SQLiteData's @Table macro.
    /// These conformances enable enums to be stored/retrieved from SQLite as strings.
    public enum EntityType: String, Codable, Sendable, QueryRepresentable, QueryBindable {
        case action
        case expectation
        case measure
        case personalValue
        case timePeriod
        case goal
        case milestone
        case obligation
        case goalTerm
    }

    /// Severity levels for prioritization
    ///
    /// NOTE: QueryRepresentable + QueryBindable conformance required by SQLiteData's @Table macro.
    public enum Severity: String, Codable, Sendable, QueryRepresentable, QueryBindable {
        case exact      // 0.95+ similarity (almost certainly duplicates)
        case high       // 0.85-0.95 similarity (very likely duplicates)
        case moderate   // 0.70-0.85 similarity (possibly duplicates)
        case low        // 0.50-0.70 similarity (review if time permits)
    }

    /// Processing status
    ///
    /// NOTE: QueryRepresentable + QueryBindable conformance required by SQLiteData's @Table macro.
    public enum Status: String, Codable, Sendable, QueryRepresentable, QueryBindable {
        case pending    // Awaiting user review
        case merged     // Entities merged into one
        case ignored    // User confirmed these are distinct
        case resolved   // Handled but not merged
    }

    /// How the duplicate was resolved
    ///
    /// NOTE: QueryRepresentable + QueryBindable conformance required by SQLiteData's @Table macro.
    public enum Resolution: String, Codable, Sendable, QueryRepresentable, QueryBindable {
        case mergedInto1    // Kept entity1, merged entity2 into it
        case mergedInto2    // Kept entity2, merged entity1 into it
        case keptBoth       // User confirmed these are distinct
        case deleted1       // Deleted entity1 (was duplicate)
        case deleted2       // Deleted entity2 (was duplicate)
    }
}

// MARK: - Convenience Methods

extension DuplicateCandidate {
    /// Mark this candidate as resolved
    mutating func resolve(resolution: Resolution, notes: String? = nil) {
        self.status = .resolved
        self.resolution = resolution
        self.resolutionNotes = notes
        self.resolvedAt = Date()
        self.reviewedAt = self.reviewedAt ?? Date()
    }

    /// Mark this candidate as ignored (not duplicates)
    mutating func ignore(notes: String? = nil) {
        self.status = .ignored
        self.resolution = .keptBoth
        self.resolutionNotes = notes
        self.reviewedAt = Date()
    }

    /// Mark this candidate as merged
    mutating func merge(into primaryId: UUID, notes: String? = nil) {
        self.status = .merged
        self.resolution = primaryId == entity1Id ? .mergedInto1 : .mergedInto2
        self.resolutionNotes = notes
        self.resolvedAt = Date()
        self.reviewedAt = self.reviewedAt ?? Date()
    }

    /// Check if this is a high-priority duplicate
    public var isHighPriority: Bool {
        severity == .exact || severity == .high
    }
}
