//
//  SemanticDuplicateDetector.swift
//  Ten Week Goal App
//
//  Written by Claude Code on 2025-11-16
//
//  PURPOSE: Generic semantic duplicate detection for any SemanticDetectable entity
//  Uses NLEmbedding-based similarity to detect paraphrases and conceptual duplicates
//
//  EXAMPLES:
//  - Goals: "Run a marathon" vs "Complete 26.2 miles" → 85%+ similarity
//  - Values: "Health & Wellness" vs "Physical Wellbeing" → 80%+ similarity
//  - Actions: "Morning jog" vs "Early run" → 75%+ similarity
//

import Foundation
import Models

/// Generic detector for semantic duplicates across any entity type
///
/// Uses NLEmbedding to find entities with similar semantic meaning, even when
/// text differs syntactically (paraphrases, synonyms, conceptual equivalents).
///
/// ## Usage
/// ```swift
/// let detector = SemanticDuplicateDetector<PersonalValue>(
///     semanticService: semanticService,
///     config: .values
/// )
///
/// let duplicates = try await detector.findDuplicates(
///     for: "Health & Fitness",
///     in: existingValues
/// )
/// // Returns: [("Physical Wellness", 0.82), ("Health", 0.78), ...]
/// ```
@available(iOS 26.0, macOS 26.0, *)
public final class SemanticDuplicateDetector<Entity: SemanticDetectable>: Sendable {

    // MARK: - Dependencies

    private let semanticService: SemanticService
    private let config: DeduplicationConfig

    // MARK: - Initialization

    public init(
        semanticService: SemanticService,
        config: DeduplicationConfig
    ) {
        self.semanticService = semanticService
        self.config = config
    }

    // MARK: - Duplicate Detection

    /// Find duplicate entities based on semantic text similarity
    /// - Parameters:
    ///   - text: Text to check for duplicates (e.g., new goal title)
    ///   - existingEntities: Entities to compare against
    ///   - threshold: Minimum similarity (0.0-1.0) to consider a duplicate
    /// - Returns: Array of duplicate matches sorted by similarity (highest first)
    /// - Throws: DeduplicationError if semantic service unavailable
    public func findDuplicates(
        for text: String,
        in existingEntities: [Entity],
        threshold: Double? = nil
    ) async throws -> [DuplicateMatch] {
        // Use config threshold if not specified
        let minimumThreshold = threshold ?? config.minimumThreshold

        // Validate input
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        guard !existingEntities.isEmpty else {
            throw DeduplicationError.noCandidatesToCompare
        }

        // Generate embedding for new text
        guard let queryEmbedding = try await semanticService.generateEmbedding(for: text) else {
            // NLEmbedding unavailable - graceful degradation
            throw DeduplicationError.semanticServiceUnavailable
        }

        // Generate embeddings for existing entities
        // Note: Embeddings are cached automatically by SemanticService
        var candidateEmbeddings: [EmbeddingVector?] = []
        for entity in existingEntities {
            let embedding = try await semanticService.generateEmbedding(for: entity.semanticText)
            candidateEmbeddings.append(embedding)
        }

        // Calculate similarities
        var matches: [DuplicateMatch] = []

        for (index, embedding) in candidateEmbeddings.enumerated() {
            guard let candidateEmbedding = embedding else {
                continue  // Skip if embedding generation failed
            }

            let similarity = semanticService.similarity(queryEmbedding, candidateEmbedding)

            // Only include if above threshold
            if similarity >= minimumThreshold {
                let entity = existingEntities[index]

                // Infer entity type based on Entity generic parameter
                let entityType: DuplicationEntityType
                if Entity.self == GoalData.self {
                    entityType = .goal
                } else if Entity.self == PersonalValueData.self {
                    entityType = .value
                } else if Entity.self == ActionData.self {
                    entityType = .action
                } else {
                    // Fallback for future entity types
                    entityType = .goal
                }

                matches.append(DuplicateMatch(
                    entityId: entity.id,
                    title: entity.semanticText,
                    similarity: similarity,
                    entityType: entityType
                ))
            }
        }

        // Sort by similarity (highest first) and limit to maxMatches
        return matches
            .sorted { $0.similarity > $1.similarity }
            .prefix(config.maxMatches)
            .map { $0 }
    }

    /// Check if text would create a duplicate (returns highest match if found)
    /// - Parameters:
    ///   - text: Text to check
    ///   - existingEntities: Entities to compare against
    /// - Returns: Highest similarity match if duplicate found, nil otherwise
    /// - Throws: DeduplicationError if semantic service unavailable
    public func isDuplicate(
        _ text: String,
        of existingEntities: [Entity]
    ) async throws -> DuplicateMatch? {
        let matches = try await findDuplicates(for: text, in: existingEntities)
        return matches.first
    }

    /// Batch check multiple texts for duplicates
    /// - Parameters:
    ///   - texts: Array of texts to check
    ///   - existingEntities: Entities to compare against
    /// - Returns: Dictionary mapping texts to their duplicate matches
    public func batchCheck(
        texts: [String],
        in existingEntities: [Entity]
    ) async throws -> [String: [DuplicateMatch]] {
        var results: [String: [DuplicateMatch]] = [:]

        for text in texts {
            let duplicates = try await findDuplicates(
                for: text,
                in: existingEntities
            )
            results[text] = duplicates
        }

        return results
    }

    /// Check if semantic detection is available on this device
    /// - Returns: True if NLEmbedding is available for current language
    public var isAvailable: Bool {
        return semanticService.isAvailable
    }
}

// MARK: - Note
//
// DeduplicationConfig presets (`.values`, `.goals`) are defined in DuplicationResult.swift
// to avoid duplicate declarations across files.
