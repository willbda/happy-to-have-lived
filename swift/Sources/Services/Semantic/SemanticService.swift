//
//  SemanticService.swift
//  Sources/Services/Semantic
//
//  Written by Claude Code on 2025-11-14
//
//  PURPOSE: Modern async semantic embedding service with integrated caching
//  PATTERN: Sendable service (NOT @MainActor) for background I/O
//
//  RESPONSIBILITIES:
//  - Generate embeddings using NLEmbedding (NaturalLanguage framework)
//  - Cache embeddings via EmbeddingCacheRepository
//  - Text normalization and SHA256 hashing for cache invalidation
//  - Calculate similarity between vectors
//  - Graceful degradation when NLEmbedding unavailable
//

import Foundation
import NaturalLanguage
import CryptoKit
import Models           // For EmbeddingVector, EmbeddingCacheEntry, SemanticConfiguration
import Database         // For DatabaseWriter
import SQLiteData       // For database queries

/// Semantic embedding service with integrated caching
///
/// **Architecture**: Cache-first pattern
/// 1. Hash input text (SHA256)
/// 2. Check repository for cached embedding
/// 3. If found → return cached vector
/// 4. If not → generate with NLEmbedding, store, return
///
/// **Concurrency**: Sendable, NOT @MainActor (database I/O runs in background)
@available(iOS 26.0, macOS 26.0, *)
public final class SemanticService: Sendable {

    // MARK: - Properties

    private let database: any DatabaseWriter
    private let configuration: SemanticConfiguration

    // MARK: - Initialization

    /// Create semantic service with database and configuration
    /// - Parameters:
    ///   - database: Database writer for cache storage
    ///   - configuration: Configuration (default uses 0.75 similarity threshold)
    public init(
        database: any DatabaseWriter,
        configuration: SemanticConfiguration = .default
    ) {
        self.database = database
        self.configuration = configuration
    }

    // MARK: - Availability

    /// Check if NLEmbedding is available for semantic operations
    ///
    /// **Use Case**: Check availability before attempting semantic features
    /// ```swift
    /// if semanticService.isAvailable {
    ///     let vector = try await semanticService.generateEmbedding(for: text)
    /// }
    /// ```
    ///
    /// - Returns: True if NLEmbedding sentence model is available
    public var isAvailable: Bool {
        return NLEmbedding.sentenceEmbedding(for: .english) != nil
    }

    // MARK: - Public API

    /// Generate embedding for text (cached if available)
    ///
    /// **Performance**:
    /// - First call: 10-50ms (NLEmbedding generation)
    /// - Cached calls: <1ms (database lookup)
    ///
    /// **Graceful Degradation**:
    /// Returns `nil` if NLEmbedding unavailable (e.g., on unsupported platforms)
    ///
    /// - Parameter text: Text to embed
    /// - Returns: EmbeddingVector if successful, nil if NLEmbedding unavailable
    /// - Throws: Database errors during cache storage
    public func generateEmbedding(for text: String) async throws -> EmbeddingVector? {
        guard configuration.enableSemanticSearch else {
            return nil  // Feature disabled in configuration
        }

        // Normalize text for consistent hashing
        let normalized = normalizeText(text)
        guard !normalized.isEmpty else {
            return nil  // Empty text has no embedding
        }

        // Generate cache key
        let textHash = hashText(normalized)

        // Check cache first (if enabled)
        if configuration.enableCaching {
            if let cached = try await fetchCachedEmbedding(textHash: textHash) {
                return cached
            }
        }

        // Generate new embedding with NLEmbedding
        guard let embedding = generateWithNLEmbedding(normalized) else {
            return nil  // NLEmbedding unavailable
        }

        // Convert [Double] → EmbeddingVector (Float32)
        let vector = EmbeddingVector(from: embedding)

        // Store in cache for future use (if enabled)
        if configuration.enableCaching {
            try await storeCachedEmbedding(
                vector: vector,
                textHash: textHash,
                sourceText: normalized
            )
        }

        return vector
    }

    /// Calculate cosine similarity between two vectors
    ///
    /// **Similarity Interpretation**:
    /// - 0.90+: Near-identical (typo-level differences)
    /// - 0.75-0.89: Very similar (likely duplicate)
    /// - 0.60-0.74: Similar (related concepts)
    /// - <0.60: Different topics
    ///
    /// - Parameters:
    ///   - a: First vector
    ///   - b: Second vector
    /// - Returns: Similarity score (0.0 = orthogonal, 1.0 = identical)
    public func similarity(_ a: EmbeddingVector, _ b: EmbeddingVector) -> Double {
        return a.cosineSimilarity(to: b)
    }

    /// Check if two texts are semantically similar above threshold
    ///
    /// Convenience method combining embedding generation and similarity calculation
    ///
    /// - Parameters:
    ///   - text1: First text
    ///   - text2: Second text
    ///   - threshold: Minimum similarity score (default from configuration)
    /// - Returns: True if similarity >= threshold, false otherwise
    /// - Throws: Database errors during embedding generation
    public func areSimilar(
        _ text1: String,
        _ text2: String,
        threshold: Double? = nil
    ) async throws -> Bool {
        let effectiveThreshold = threshold ?? configuration.similarityThreshold

        guard let v1 = try await generateEmbedding(for: text1),
              let v2 = try await generateEmbedding(for: text2) else {
            return false  // Can't compare without embeddings
        }

        let score = similarity(v1, v2)
        return score >= effectiveThreshold
    }

    // MARK: - Cache Management

    /// Fetch cached embedding by text hash
    private func fetchCachedEmbedding(textHash: String) async throws -> EmbeddingVector? {
        return try await database.read { db in
            // Query for any cached embedding with this text hash
            // (We don't filter by entityType/entityId since same text = same embedding)
            let entry = try EmbeddingCacheEntry.all
                .where { $0.textHash.eq(textHash) }
                .limit(1)
                .fetchOne(db)

            return entry?.toEmbeddingVector()
        }
    }

    /// Store embedding in cache
    ///
    /// Note: Uses generic entityType='semantic_cache' since this is not entity-specific
    private func storeCachedEmbedding(
        vector: EmbeddingVector,
        textHash: String,
        sourceText: String
    ) async throws {
        try await database.write { db in
            let entry = EmbeddingCacheEntry.from(
                vector: vector,
                entityType: "semantic_cache",  // Generic cache (not tied to specific entity)
                entityId: UUID(),  // Placeholder UUID (not entity-specific)
                sourceVariant: "full_context",  // Generic embeddings are full-context
                textHash: textHash,
                sourceText: sourceText,
                embeddingModel: configuration.embeddingModel
            )

            // Use SQLiteData insert API
            try EmbeddingCacheEntry.insert { entry }.execute(db)
        }
    }

    // MARK: - Text Processing

    /// Normalize text for consistent embedding generation
    ///
    /// **Normalization Steps**:
    /// 1. Trim whitespace and newlines
    /// 2. Convert to lowercase
    /// 3. Collapse multiple spaces to single space
    ///
    /// - Parameter text: Raw input text
    /// - Returns: Normalized text ready for embedding
    private func normalizeText(_ text: String) -> String {
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Hash text using SHA256 for cache invalidation
    ///
    /// **Cache Invalidation Strategy**:
    /// When entity text changes → textHash changes → new embedding generated
    /// Old embeddings orphaned (cleaned up by periodic purge)
    ///
    /// - Parameter text: Normalized text
    /// - Returns: Hex-encoded SHA256 hash
    private func hashText(_ text: String) -> String {
        let data = Data(text.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - NLEmbedding Integration

    /// Generate embedding using NaturalLanguage framework
    ///
    /// **Graceful Degradation**:
    /// Returns nil if NLEmbedding unavailable (e.g., unsupported platform, model not loaded)
    ///
    /// **Performance**:
    /// - First call: 10-50ms (model loading + inference)
    /// - Subsequent calls: 2-5ms (inference only)
    ///
    /// - Parameter text: Normalized text
    /// - Returns: 768-dimensional Double array, or nil if unavailable
    private func generateWithNLEmbedding(_ text: String) -> [Double]? {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            // NLEmbedding not available on this platform/configuration
            return nil
        }

        // Generate embedding vector
        // Note: NLEmbedding returns [Double]? with 768 dimensions for sentence model
        guard let vector = embedding.vector(for: text), !vector.isEmpty else {
            return nil  // Vector generation failed or returned empty array
        }

        return vector
    }
}
