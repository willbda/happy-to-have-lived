// EntitySignature.swift
// Precomputed MinHash signatures for deduplication
//
// Written by Claude Code on 2025-11-17
//
// ARCHITECTURE:
// - Synced table (cached computation results shared across devices)
// - Stores MinHash signatures for fast similarity comparison
// - Enables LSH (Locality-Sensitive Hashing) for efficient duplicate detection
//
// DESIGN PRINCIPLES:
// - Uniqueness enforced at application level (CloudKit sync compatible)
// - Cache invalidation via lshVersion field
// - Signatures computed once, reused across devices

import Foundation
import SQLiteData

/// Precomputed MinHash signature for an entity
///
/// **Database Table**: `entitySignatures`
/// **Purpose**: Cache expensive MinHash computations
///
/// **Design Principle**: MinHash signature computation is expensive (text
/// preprocessing, shingling, hashing), but the results are small and reusable.
/// Syncing these signatures means devices can perform duplicate detection
/// without re-computing signatures that other devices already created.
///
/// **Why sync this table?**
/// - Signature computation is CPU-intensive
/// - Results are small (a few KB per signature)
/// - Once computed, signature is valid until entity text changes
/// - Sharing signatures across devices saves computation
///
/// **Usage**:
/// ```swift
/// // Compute and store signature
/// let signature = EntitySignature(
///     entityType: "goal",
///     entityId: goal.id,
///     signature: minHash.serialize(),
///     semanticContent: goal.title,
///     lshVersion: 1
/// )
///
/// // Later: Fast similarity check using precomputed signatures
/// let similarity = estimateSimilarity(sig1.signature, sig2.signature)
/// ```
@Table
public struct EntitySignature: DomainComposit {
    // MARK: - Identity

    /// Unique identifier (required by SQLiteData)
    public var id: UUID

    // MARK: - Entity Reference

    /// Type of entity this signature represents
    public var entityType: String

    /// ID of the entity
    public var entityId: UUID

    // MARK: - Signature Data

    /// Serialized MinHash signature (binary blob)
    /// Typically 128-256 bytes for 128 hash functions
    public var signature: Data

    /// The semantic content that was hashed
    /// Used for debugging and cache invalidation
    public var semanticContent: String

    // MARK: - Metadata

    /// When this signature was computed
    public var computedAt: Date

    /// LSH algorithm version for cache invalidation
    /// Increment when MinHash parameters change
    public var lshVersion: Int

    // MARK: - Initialization

    public init(
        entityType: String,
        entityId: UUID,
        signature: Data,
        semanticContent: String,
        computedAt: Date = Date(),
        lshVersion: Int = 1,
        id: UUID = UUID()
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.signature = signature
        self.semanticContent = semanticContent
        self.computedAt = computedAt
        self.lshVersion = lshVersion
    }
}

// MARK: - Convenience Methods

extension EntitySignature {
    /// Check if this signature is stale (algorithm version changed)
    public func isStale(currentVersion: Int) -> Bool {
        lshVersion < currentVersion
    }

    /// Check if this signature matches the current content
    /// Returns false if entity text has changed
    public func matchesContent(_ currentContent: String) -> Bool {
        semanticContent == currentContent
    }
}
