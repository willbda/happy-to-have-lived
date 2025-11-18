//
//  EmbeddingCacheEntry.swift
//  Sources/Models/SemanticTypes
//
//  Written by Claude Code on 2025-11-14
//
//  PURPOSE: Database entity for cached semantic embeddings
//  PATTERN: SQLiteData @Table model matching semanticEmbeddings schema
//
//  RESPONSIBILITIES:
//  - Store vector embeddings in SQLite BLOB format
//  - Track source text changes via textHash
//  - Support cache invalidation on entity updates
//

import Foundation
import SQLiteData

/// Cached semantic embedding for an entity
/// Maps to semanticEmbeddings table in schema_current.sql
@Table("semanticEmbeddings")
public struct EmbeddingCacheEntry: Sendable, Identifiable {

    @Column("id") public let id: UUID
    @Column("entityType") public let entityType: String  // 'goal', 'action', 'value', etc.
    @Column("entityId") public let entityId: UUID
    @Column("sourceVariant") public let sourceVariant: String  // 'title_only' or 'full_context'
    @Column("textHash") public let textHash: String      // SHA256 of source text
    @Column("sourceText") public let sourceText: String
    @Column("embedding") public let embedding: Data      // Serialized EmbeddingVector (BLOB)
    @Column("embeddingModel") public let embeddingModel: String
    @Column("dimensionality") public let dimensionality: Int
    @Column("generatedAt") public let generatedAt: Date
    @Column("logTime") public let logTime: Date

    // MARK: - Initialization

    /// Create new embedding cache entry
    public init(
        id: UUID = UUID(),
        entityType: String,
        entityId: UUID,
        sourceVariant: String,
        textHash: String,
        sourceText: String,
        embedding: Data,  // Accepts pre-serialized Data (from EmbeddingVector.toData())
        embeddingModel: String = "NLEmbedding-sentence-english",
        dimensionality: Int,
        generatedAt: Date = Date(),
        logTime: Date = Date()
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.sourceVariant = sourceVariant
        self.textHash = textHash
        self.sourceText = sourceText
        self.embedding = embedding
        self.embeddingModel = embeddingModel
        self.dimensionality = dimensionality
        self.generatedAt = generatedAt
        self.logTime = logTime
    }
}

// MARK: - Computed Properties

extension EmbeddingCacheEntry {
    /// Check if entity type is valid per schema constraint
    public var isValidEntityType: Bool {
        ["goal", "action", "value", "measure", "term", "conversation"].contains(entityType)
    }

    /// Deserialize embedding to EmbeddingVector
    /// - Returns: EmbeddingVector if data is valid, nil if corrupted
    public func toEmbeddingVector() -> EmbeddingVector? {
        return EmbeddingVector(from: embedding)
    }
}

// MARK: - Convenience Factory

extension EmbeddingCacheEntry {
    /// Create cache entry from EmbeddingVector
    /// - Parameters:
    ///   - vector: The embedding vector to cache
    ///   - entityType: Type of entity ('goal', 'action', etc.)
    ///   - entityId: UUID of the entity
    ///   - sourceVariant: Embedding variant ('title_only' or 'full_context')
    ///   - textHash: SHA256 hash of source text
    ///   - sourceText: Original text that was embedded
    ///   - embeddingModel: Model identifier (default: NLEmbedding-sentence-english)
    /// - Returns: New cache entry ready for database storage
    public static func from(
        vector: EmbeddingVector,
        entityType: String,
        entityId: UUID,
        sourceVariant: String,
        textHash: String,
        sourceText: String,
        embeddingModel: String = "NLEmbedding-sentence-english"
    ) -> EmbeddingCacheEntry {
        return EmbeddingCacheEntry(
            entityType: entityType,
            entityId: entityId,
            sourceVariant: sourceVariant,
            textHash: textHash,
            sourceText: sourceText,
            embedding: vector.toData(),  // Convert EmbeddingVector → Data
            embeddingModel: embeddingModel,
            dimensionality: vector.dimensionality
        )
    }
}
