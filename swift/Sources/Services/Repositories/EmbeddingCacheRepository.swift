//
//  EmbeddingCacheRepository.swift
//  ten-week-goal-app
//
//  Written by Claude Code on 2025-11-14
//
//  PURPOSE: Repository for managing cached semantic embeddings
//  PATTERN: Standard repository pattern with SQLiteData integration
//
//  RESPONSIBILITIES:
//  - CRUD operations for semanticEmbeddings table
//  - Cache invalidation on text changes
//  - Batch fetching for performance
//  - Cleanup of orphaned embeddings
//

import Foundation
import GRDB  // For FetchableRecord protocol
import Models  // For EmbeddingVector, EmbeddingCacheEntry, SemanticConfiguration
import SQLiteData

/// Repository for managing cached semantic embeddings
/// Follows the established repository pattern with Sendable conformance
public final class EmbeddingCacheRepository: Sendable {
    // MARK: - Properties

    private let database: any DatabaseWriter

    // MARK: - Initialization

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Fetching

    /// Fetch a cached embedding by entity reference
    public func fetchEmbedding(
        entityType: String,
        entityId: UUID,
        textHash: String? = nil
    ) async throws -> EmbeddingCacheEntry? {
        try await database.read { db in
            var sql = """
                    SELECT id, entityType, entityId, textHash, sourceText,
                           embedding, embeddingModel, dimensionality, generatedAt, logTime
                    FROM semanticEmbeddings
                    WHERE entityType = ? AND entityId = ?
                """

            var arguments: [any DatabaseValueConvertible] = [entityType, entityId.uuidString]

            // Optionally filter by text hash for exact match
            if let textHash = textHash {
                sql += " AND textHash = ?"
                arguments.append(textHash)
            }

            sql += " ORDER BY generatedAt DESC LIMIT 1"

            guard
                let row = try EmbeddingCacheRow.fetchOne(
                    db, sql: sql, arguments: StatementArguments(arguments))
            else {
                return nil
            }

            return try self.mapRowToEntry(row)
        }
    }

    /// Fetch all embeddings for a specific entity type
    /// Useful for batch similarity operations
    public func fetchAllByType(_ entityType: String) async throws -> [EmbeddingCacheEntry] {
        try await database.read { db in
            let sql = """
                    SELECT id, entityType, entityId, textHash, sourceText,
                           embedding, embeddingModel, dimensionality, generatedAt, logTime
                    FROM semanticEmbeddings
                    WHERE entityType = ?
                    ORDER BY generatedAt DESC
                """

            let rows = try EmbeddingCacheRow.fetchAll(db, sql: sql, arguments: [entityType])
            return try rows.compactMap { try self.mapRowToEntry($0) }
        }
    }

    /// Fetch embeddings for multiple entities
    public func fetchEmbeddings(
        entityType: String,
        entityIds: [UUID]
    ) async throws -> [UUID: EmbeddingCacheEntry] {
        guard !entityIds.isEmpty else { return [:] }

        return try await database.read { db in
            let placeholders = Array(repeating: "?", count: entityIds.count).joined(separator: ", ")
            let sql = """
                    SELECT id, entityType, entityId, textHash, sourceText,
                           embedding, embeddingModel, dimensionality, generatedAt, logTime
                    FROM semanticEmbeddings
                    WHERE entityType = ? AND entityId IN (\(placeholders))
                """

            var arguments: [any DatabaseValueConvertible] = [entityType]
            arguments.append(contentsOf: entityIds.map { $0.uuidString })

            let rows = try EmbeddingCacheRow.fetchAll(
                db, sql: sql, arguments: StatementArguments(arguments))

            var result: [UUID: EmbeddingCacheEntry] = [:]
            for row in rows {
                if let entry = try self.mapRowToEntry(row) {
                    result[entry.entityId] = entry
                }
            }
            return result
        }
    }

    // MARK: - Storing

    /// Store a new embedding in the cache
    public func storeEmbedding(_ entry: EmbeddingCacheEntry) async throws {
        try await database.write { db in
            let sql = """
                    INSERT OR REPLACE INTO semanticEmbeddings (
                        id, entityType, entityId, textHash, sourceText,
                        embedding, embeddingModel, dimensionality,
                        generatedAt, logTime
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """

            try db.execute(
                sql: sql,
                arguments: [
                    entry.id.uuidString.lowercased(),
                    entry.entityType,
                    entry.entityId.uuidString,
                    entry.textHash,
                    entry.sourceText,
                    entry.embedding,  // Already Data
                    entry.embeddingModel,
                    entry.dimensionality,
                    entry.generatedAt.ISO8601Format(),
                    entry.logTime.ISO8601Format(),
                ]
            )
        }
    }

    /// Store multiple embeddings in a single transaction
    public func storeBatch(_ entries: [EmbeddingCacheEntry]) async throws {
        guard !entries.isEmpty else { return }

        try await database.write { db in
            let sql = """
                    INSERT OR REPLACE INTO semanticEmbeddings (
                        id, entityType, entityId, textHash, sourceText,
                        embedding, embeddingModel, dimensionality,
                        generatedAt, logTime
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """

            for entry in entries {
                try db.execute(
                    sql: sql,
                    arguments: [
                        entry.id.uuidString.lowercased(),
                        entry.entityType,
                        entry.entityId.uuidString,
                        entry.textHash,
                        entry.sourceText,
                        entry.embedding,  // Already Data
                        entry.embeddingModel,
                        entry.dimensionality,
                        entry.generatedAt.ISO8601Format(),
                        entry.logTime.ISO8601Format(),
                    ]
                )
            }
        }
    }

    // MARK: - Invalidation

    /// Invalidate cached embeddings for a specific entity
    /// Called when entity text changes
    public func invalidateCache(entityType: String, entityId: UUID) async throws {
        try await database.write { db in
            let sql = """
                    DELETE FROM semanticEmbeddings
                    WHERE entityType = ? AND entityId = ?
                """
            try db.execute(sql: sql, arguments: [entityType, entityId.uuidString])
        }
    }

    /// Invalidate all embeddings for an entity type
    /// Useful when model changes or bulk updates occur
    public func invalidateCacheForType(_ entityType: String) async throws {
        try await database.write { db in
            let sql = """
                    DELETE FROM semanticEmbeddings
                    WHERE entityType = ?
                """
            try db.execute(sql: sql, arguments: [entityType])
        }
    }

    /// Invalidate embeddings older than a specific date
    /// Useful for periodic cache refresh
    public func invalidateOlderThan(_ date: Date) async throws {
        try await database.write { db in
            let sql = """
                    DELETE FROM semanticEmbeddings
                    WHERE generatedAt < ?
                """
            try db.execute(sql: sql, arguments: [date.ISO8601Format()])
        }
    }

    // MARK: - Cleanup

    /// Remove orphaned embeddings (where entity no longer exists)
    /// Should be called periodically for maintenance
    public func cleanupOrphaned() async throws {
        try await database.write { db in
            // Clean up orphaned goal embeddings
            var sql = """
                    DELETE FROM semanticEmbeddings
                    WHERE entityType = 'goal'
                      AND entityId NOT IN (SELECT id FROM goals)
                """
            try db.execute(sql: sql)

            // Clean up orphaned action embeddings
            sql = """
                    DELETE FROM semanticEmbeddings
                    WHERE entityType = 'action'
                      AND entityId NOT IN (SELECT id FROM actions)
                """
            try db.execute(sql: sql)

            // Clean up orphaned value embeddings
            sql = """
                    DELETE FROM semanticEmbeddings
                    WHERE entityType = 'value'
                      AND entityId NOT IN (SELECT id FROM personalValues)
                """
            try db.execute(sql: sql)

            // Clean up orphaned measure embeddings
            sql = """
                    DELETE FROM semanticEmbeddings
                    WHERE entityType = 'measure'
                      AND entityId NOT IN (SELECT id FROM measures)
                """
            try db.execute(sql: sql)
        }
    }

    /// Get statistics about cached embeddings
    public func getStatistics() async throws -> CacheStatistics {
        try await database.read { db in
            let sql = """
                    SELECT
                        entityType,
                        COUNT(*) as count,
                        MIN(generatedAt) as oldestDate,
                        MAX(generatedAt) as newestDate,
                        AVG(dimensionality) as avgDimensionality
                    FROM semanticEmbeddings
                    GROUP BY entityType
                """

            let rows = try StatisticsRow.fetchAll(db, sql: sql)

            var byType: [String: CacheStatistics.TypeStatistics] = [:]
            var totalCount = 0

            for row in rows {
                totalCount += row.count

                let stats = CacheStatistics.TypeStatistics(
                    count: row.count,
                    oldestDate: row.oldestDate.flatMap { ISO8601DateFormatter().date(from: $0) },
                    newestDate: row.newestDate.flatMap { ISO8601DateFormatter().date(from: $0) },
                    averageDimensionality: row.avgDimensionality
                )

                byType[row.entityType] = stats
            }

            return CacheStatistics(
                totalEntries: totalCount,
                byType: byType
            )
        }
    }

    // MARK: - Existence Checks

    /// Check if a valid embedding exists for an entity
    public func hasEmbedding(
        entityType: String,
        entityId: UUID,
        textHash: String
    ) async throws -> Bool {
        try await database.read { db in
            let sql = """
                    SELECT COUNT(*) as count
                    FROM semanticEmbeddings
                    WHERE entityType = ? AND entityId = ? AND textHash = ?
                """

            let count =
                try Int.fetchOne(
                    db,
                    sql: sql,
                    arguments: [entityType, entityId.uuidString, textHash]
                ) ?? 0

            return count > 0
        }
    }

    // MARK: - Private Helpers

    /// Map a database row to an EmbeddingCacheEntry
    private func mapRowToEntry(_ row: EmbeddingCacheRow) throws -> EmbeddingCacheEntry? {
        guard let id = UUID(uuidString: row.id),
            let entityId = UUID(uuidString: row.entityId),
            let generatedAt = ISO8601DateFormatter().date(from: row.generatedAt),
            let logTime = ISO8601DateFormatter().date(from: row.logTime)
        else {
            return nil
        }

        // Validate embedding data can be deserialized to EmbeddingVector
        guard EmbeddingVector(from: row.embedding) != nil else {
            print(
                "⚠️ EmbeddingCacheRepository: Failed to decode embedding vector for entity \(row.entityType):\(row.entityId)"
            )
            return nil
        }

        // Return EmbeddingCacheEntry (stores Data, not EmbeddingVector)
        return EmbeddingCacheEntry(
            id: id,
            entityType: row.entityType,
            entityId: entityId,
            sourceVariant: row.sourceVariant,
            textHash: row.textHash,
            sourceText: row.sourceText,
            embedding: row.embedding,  // Keep as Data (matches schema)
            embeddingModel: row.embeddingModel,
            dimensionality: row.dimensionality,
            generatedAt: generatedAt,
            logTime: logTime
        )
    }
}

// MARK: - Row Types

/// Result row from semanticEmbeddings table query
/// Decodes SQL result for embedding cache entries
private struct EmbeddingCacheRow: Decodable, FetchableRecord, Sendable {
    let id: String
    let entityType: String
    let entityId: String
    let sourceVariant: String
    let textHash: String
    let sourceText: String
    let embedding: Data
    let embeddingModel: String
    let dimensionality: Int
    let generatedAt: String
    let logTime: String
}

/// Result row from statistics aggregation query
private struct StatisticsRow: Decodable, FetchableRecord, Sendable {
    let entityType: String
    let count: Int
    let oldestDate: String?
    let newestDate: String?
    let avgDimensionality: Double
}

// MARK: - Supporting Types

/// Statistics about cached embeddings
public struct CacheStatistics: Sendable {
    public let totalEntries: Int
    public let byType: [String: TypeStatistics]

    public struct TypeStatistics: Sendable {
        public let count: Int
        public let oldestDate: Date?
        public let newestDate: Date?
        public let averageDimensionality: Double
    }
}
