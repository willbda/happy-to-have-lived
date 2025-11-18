//
// EmbeddingGenerationService.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// Coordinate entity-specific embedding generation with caching and variant management.
// Wraps SemanticService with entity-aware caching using sourceVariant field.
//
// DESIGN DECISIONS:
// - Entity-aware caching (entityType + entityId + sourceVariant)
// - Uses EmbeddingSourceTextBuilders for text normalization
// - Lazy generation (only embed when needed)
// - Cache invalidation via SHA256 hash comparison
// - Supports both title-only and full-context variants
//
// ARCHITECTURE:
// EmbeddingGenerationService → SemanticService → NLEmbedding + EmbeddingCacheRepository
//
// USAGE:
// ```swift
// let service = EmbeddingGenerationService(database: database)
//
// // Generate title-only embedding for duplicate detection
// let titleVector = try await service.generateGoalEmbedding(
//     goal: goalData,
//     variant: .titleOnly
// )
//
// // Generate full-context embedding for semantic search
// let fullVector = try await service.generateGoalEmbedding(
//     goal: goalData,
//     variant: .fullContext
// )
// ```

import Foundation
import Models
import Database
import SQLiteData
import CryptoKit

/// Service for generating and caching entity-specific embeddings
///
/// **Caching Strategy**:
/// - Each entity can have 2 embeddings (title_only + full_context)
/// - Cache key: (entityType, entityId, sourceVariant)
/// - Cache invalidation: SHA256 hash of source text
///
/// **Concurrency**: Sendable, NOT @MainActor (database I/O runs in background)
@available(iOS 26.0, macOS 26.0, *)
public final class EmbeddingGenerationService: Sendable {

    // MARK: - Properties

    private let database: any DatabaseWriter

    // MARK: - Initialization

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Goal Embeddings

    /// Generate or retrieve cached embedding for Goal
    ///
    /// **Pattern**: Check cache → Build source text → Generate if needed → Store → Return
    ///
    /// - Parameters:
    ///   - goal: Goal data to embed
    ///   - variant: Title-only or full-context variant
    /// - Returns: Embedding vector (768-dimensional Float32 array)
    /// - Throws: DatabaseError if cache operations fail
    public func generateGoalEmbedding(
        goal: GoalData,
        variant: EmbeddingSourceVariant
    ) async throws -> EmbeddingVector? {
        return try await generateEntityEmbedding(
            entityType: "goal",
            entityId: goal.id,
            variant: variant,
            buildSource: { EmbeddingSourceTextBuilders.buildGoalSource(goal, variant: $0) }
        )
    }

    // MARK: - Action Embeddings

    /// Generate or retrieve cached embedding for Action
    ///
    /// - Parameters:
    ///   - action: Action data to embed
    ///   - variant: Title-only or full-context variant
    /// - Returns: Embedding vector (768-dimensional Float32 array)
    /// - Throws: DatabaseError if cache operations fail
    public func generateActionEmbedding(
        action: ActionData,
        variant: EmbeddingSourceVariant
    ) async throws -> EmbeddingVector? {
        return try await generateEntityEmbedding(
            entityType: "action",
            entityId: action.id,
            variant: variant,
            buildSource: { EmbeddingSourceTextBuilders.buildActionSource(action, variant: $0) }
        )
    }

    // MARK: - PersonalValue Embeddings

    /// Generate or retrieve cached embedding for PersonalValue
    ///
    /// - Parameters:
    ///   - value: PersonalValue data to embed
    ///   - variant: Title-only or full-context variant
    /// - Returns: Embedding vector (768-dimensional Float32 array)
    /// - Throws: DatabaseError if cache operations fail
    public func generateValueEmbedding(
        value: PersonalValueData,
        variant: EmbeddingSourceVariant
    ) async throws -> EmbeddingVector? {
        return try await generateEntityEmbedding(
            entityType: "value",
            entityId: value.id,
            variant: variant,
            buildSource: { EmbeddingSourceTextBuilders.buildValueSource(value, variant: $0) }
        )
    }

    // MARK: - Measure Embeddings

    /// Generate or retrieve cached embedding for Measure
    ///
    /// - Parameters:
    ///   - measure: Measure data to embed
    ///   - variant: Title-only or full-context variant
    /// - Returns: Embedding vector (768-dimensional Float32 array)
    /// - Throws: DatabaseError if cache operations fail
    public func generateMeasureEmbedding(
        measure: MeasureData,
        variant: EmbeddingSourceVariant
    ) async throws -> EmbeddingVector? {
        return try await generateEntityEmbedding(
            entityType: "measure",
            entityId: measure.id,
            variant: variant,
            buildSource: { EmbeddingSourceTextBuilders.buildMeasureSource(measure, variant: $0) }
        )
    }

    // MARK: - TimePeriod Embeddings

    /// Generate or retrieve cached embedding for TimePeriod
    ///
    /// - Parameters:
    ///   - period: TimePeriod data to embed
    ///   - variant: Title-only or full-context variant
    /// - Returns: Embedding vector (768-dimensional Float32 array)
    /// - Throws: DatabaseError if cache operations fail
    public func generateTimePeriodEmbedding(
        period: TimePeriodData,
        variant: EmbeddingSourceVariant
    ) async throws -> EmbeddingVector? {
        return try await generateEntityEmbedding(
            entityType: "term",
            entityId: period.id,
            variant: variant,
            buildSource: { EmbeddingSourceTextBuilders.buildTimePeriodSource(period, variant: $0) }
        )
    }

    // MARK: - Core Generation Logic

    /// Generate or retrieve cached embedding for any entity type
    ///
    /// **Algorithm**:
    /// 1. Build source text via buildSource closure
    /// 2. Hash source text (SHA256)
    /// 3. Check cache for (entityType, entityId, sourceVariant, textHash)
    /// 4. If found → return cached vector
    /// 5. If not → generate with NLEmbedding, store, return
    ///
    /// **Cache Invalidation**:
    /// When source text changes (e.g., goal title edited), textHash changes.
    /// Old embedding remains until purged, new embedding generated and stored.
    ///
    /// - Parameters:
    ///   - entityType: Entity type ('goal', 'action', 'value', 'measure', 'term')
    ///   - entityId: Entity UUID
    ///   - variant: Source variant (title_only or full_context)
    ///   - buildSource: Closure to build source text for given variant
    /// - Returns: Embedding vector if successful, nil if NLEmbedding unavailable
    /// - Throws: DatabaseError if cache operations fail
    private func generateEntityEmbedding(
        entityType: String,
        entityId: UUID,
        variant: EmbeddingSourceVariant,
        buildSource: @Sendable (EmbeddingSourceVariant) -> String
    ) async throws -> EmbeddingVector? {
        // Build source text using entity-specific builder
        let sourceText = buildSource(variant)
        guard !sourceText.isEmpty else {
            return nil  // Empty source text has no embedding
        }

        // Hash source text for cache invalidation
        let textHash = hashText(sourceText)

        // Check cache for existing embedding with matching hash
        if let cached = try await fetchCachedEmbedding(
            entityType: entityType,
            entityId: entityId,
            variant: variant,
            textHash: textHash
        ) {
            return cached
        }

        // Generate new embedding with SemanticService
        let semanticService = SemanticService(database: database)
        guard let vector = try await semanticService.generateEmbedding(for: sourceText) else {
            return nil  // NLEmbedding unavailable
        }

        // Store in entity-specific cache
        try await storeCachedEmbedding(
            vector: vector,
            entityType: entityType,
            entityId: entityId,
            variant: variant,
            textHash: textHash,
            sourceText: sourceText
        )

        return vector
    }

    // MARK: - Cache Operations

    /// Fetch cached embedding for entity
    ///
    /// **Query Pattern**:
    /// ```sql
    /// SELECT * FROM semanticEmbeddings
    /// WHERE entityType = ? AND entityId = ? AND sourceVariant = ? AND textHash = ?
    /// ```
    ///
    /// **Cache Hit Conditions**:
    /// - Entity exists (entityType + entityId match)
    /// - Variant matches (title_only vs full_context)
    /// - Source text unchanged (textHash matches)
    ///
    /// - Parameters:
    ///   - entityType: Entity type ('goal', 'action', etc.)
    ///   - entityId: Entity UUID
    ///   - variant: Source variant (title_only or full_context)
    ///   - textHash: SHA256 hash of source text
    /// - Returns: Cached vector if found and hash matches, nil otherwise
    /// - Throws: DatabaseError on query failure
    private func fetchCachedEmbedding(
        entityType: String,
        entityId: UUID,
        variant: EmbeddingSourceVariant,
        textHash: String
    ) async throws -> EmbeddingVector? {
        return try await database.read { db in
            let sql = """
                SELECT embedding, dimensionality
                FROM semanticEmbeddings
                WHERE entityType = ?
                  AND entityId = ?
                  AND sourceVariant = ?
                  AND textHash = ?
                LIMIT 1
                """

            let row = try Row.fetchOne(
                db,
                sql: sql,
                arguments: [entityType, entityId.uuidString.lowercased(), variant.rawValue, textHash]
            )

            guard let row = row else {
                return nil  // Cache miss
            }

            // Deserialize embedding BLOB → EmbeddingVector
            let embeddingData: Data = row["embedding"]
            let dimensionality: Int = row["dimensionality"]

            // Validate dimensionality (should be 768 for NLEmbedding)
            guard dimensionality == 768 else {
                print("⚠️ Unexpected embedding dimensionality: \(dimensionality) (expected 768)")
                return nil
            }

            // Convert Data → [Float32]
            let floatArray = embeddingData.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Float32.self))
            }

            return EmbeddingVector(values: floatArray)
        }
    }

    /// Store embedding in entity-specific cache
    ///
    /// **Storage Pattern**:
    /// ```sql
    /// INSERT INTO semanticEmbeddings (
    ///   id, entityType, entityId, sourceVariant, textHash, sourceText,
    ///   embedding, embeddingModel, dimensionality, generatedAt, logTime
    /// ) VALUES (...)
    /// ```
    ///
    /// - Parameters:
    ///   - vector: Embedding vector to store
    ///   - entityType: Entity type ('goal', 'action', etc.)
    ///   - entityId: Entity UUID
    ///   - variant: Source variant (title_only or full_context)
    ///   - textHash: SHA256 hash of source text
    ///   - sourceText: Normalized source text (for debugging)
    /// - Throws: DatabaseError on insert failure
    private func storeCachedEmbedding(
        vector: EmbeddingVector,
        entityType: String,
        entityId: UUID,
        variant: EmbeddingSourceVariant,
        textHash: String,
        sourceText: String
    ) async throws {
        try await database.write { db in
            // Serialize [Float32] → Data (BLOB storage)
            let embeddingData = Data(
                bytes: vector.values,
                count: vector.values.count * MemoryLayout<Float32>.size
            )

            let now = Date()

            try db.execute(
                sql: """
                    INSERT INTO semanticEmbeddings (
                        id, entityType, entityId, sourceVariant, textHash, sourceText,
                        embedding, embeddingModel, dimensionality, generatedAt, logTime
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    UUID().uuidString.lowercased(),
                    entityType,
                    entityId.uuidString.lowercased(),
                    variant.rawValue,
                    textHash,
                    sourceText,
                    embeddingData,
                    "NLEmbedding-sentence-english",
                    vector.values.count,  // dimensionality (should be 768)
                    now.ISO8601Format(),
                    now.ISO8601Format(),
                ]
            )
        }
    }

    // MARK: - Hashing

    /// Hash text for cache invalidation
    ///
    /// **Pattern**: SHA256(sourceText) → hex string
    ///
    /// **Why SHA256**:
    /// - Detects semantic changes (title/description edits)
    /// - Collision-resistant (safe for cache keys)
    /// - Fast enough for our use case (<1ms)
    ///
    /// - Parameter text: Normalized source text
    /// - Returns: SHA256 hash as hex string
    private func hashText(_ text: String) -> String {
        let data = Data(text.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Usage Examples

/*
 // Generate title-only embedding for duplicate detection
 let service = EmbeddingGenerationService(database: database)
 let titleVector = try await service.generateGoalEmbedding(goal: goalData, variant: .titleOnly)
 // Result: 768-dimensional vector for "run a marathon this year"

 // Generate full-context embedding for semantic search
 let fullVector = try await service.generateGoalEmbedding(goal: goalData, variant: .fullContext)
 // Result: 768-dimensional vector for "run a marathon this year. complete 26.2 miles by december. targets: 120 km. values: health"

 // Cache hit on subsequent call (same entity, same variant, same source text)
 let cached = try await service.generateGoalEmbedding(goal: goalData, variant: .titleOnly)
 // Result: Same vector, fetched from database in <1ms

 // Cache miss on variant change (same entity, different variant)
 let different = try await service.generateGoalEmbedding(goal: goalData, variant: .fullContext)
 // Result: Different vector (full context includes more text)

 // Cache miss on title edit (source text changed, hash changed)
 let updated = try await service.generateGoalEmbedding(goal: editedGoalData, variant: .titleOnly)
 // Result: New vector generated, old vector orphaned until purge
 */
