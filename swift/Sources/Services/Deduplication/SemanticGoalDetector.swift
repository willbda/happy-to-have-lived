//
//  SemanticGoalDetector.swift
//  Ten Week Goal App
//
//  Written by Claude Code on 2025-11-12
//
//  PURPOSE: Semantic duplicate detection for goals
//  Uses NLEmbedding-based similarity to detect paraphrases and conceptual duplicates
//
//  EXAMPLES:
//  - "Run a marathon" vs "Complete 26.2 miles" → 85%+ similarity (detected)
//  - "Write novel" vs "Exercise daily" → <30% similarity (not detected)
//

import Foundation
import Models
// Note: SemanticService is in same module (Services), no import needed

/// Detector for goal title duplicates using semantic similarity
public final class SemanticGoalDetector: Sendable {

    // MARK: - Dependencies

    private let semanticService: SemanticService
    private let config: DeduplicationConfig

    // MARK: - Initialization

    public init(
        semanticService: SemanticService,
        config: DeduplicationConfig = .goals
    ) {
        self.semanticService = semanticService
        self.config = config
    }

    // MARK: - Duplicate Detection

    /// Find duplicate goals based on title similarity
    /// - Parameters:
    ///   - title: Goal title to check
    ///   - existingGoals: Goals to compare against (canonical GoalData)
    ///   - threshold: Minimum similarity (0.0-1.0) to consider a duplicate
    /// - Returns: Array of duplicate matches sorted by similarity (highest first)
    /// - Throws: DeduplicationError if semantic service unavailable
    public func findDuplicates(
        for title: String,
        in existingGoals: [GoalData],
        threshold: Double? = nil
    ) async throws -> [DuplicateMatch] {
        // Use config threshold if not specified
        let minimumThreshold = threshold ?? config.minimumThreshold

        // Validate input
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        guard !existingGoals.isEmpty else {
            throw DeduplicationError.noCandidatesToCompare
        }

        // Generate embedding for new title
        guard let queryEmbedding = try await semanticService.generateEmbedding(for: title) else {
            // NLEmbedding unavailable - graceful degradation
            throw DeduplicationError.semanticServiceUnavailable
        }

        // Generate embeddings for existing goal titles
        // Note: Embeddings are cached automatically by SemanticService
        var candidateEmbeddings: [EmbeddingVector?] = []
        for goal in existingGoals {
            let goalTitle = goal.title ?? "Untitled"
            let embedding = try await semanticService.generateEmbedding(for: goalTitle)
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
                let goal = existingGoals[index]
                matches.append(DuplicateMatch(
                    entityId: goal.id,
                    title: goal.title ?? "Untitled",
                    similarity: similarity,
                    entityType: .goal
                ))
            }
        }

        // Sort by similarity (highest first) and limit to maxMatches
        return matches
            .sorted { $0.similarity > $1.similarity }
            .prefix(config.maxMatches)
            .map { $0 }
    }

    /// Check if title would create a duplicate (returns highest match if found)
    /// - Parameters:
    ///   - title: Goal title to check
    ///   - existingGoals: Goals to compare against (canonical GoalData)
    /// - Returns: Highest similarity duplicate match, or nil if no duplicates
    public func checkForDuplicate(
        title: String,
        in existingGoals: [GoalData]
    ) async throws -> DuplicateMatch? {
        let duplicates = try await findDuplicates(
            for: title,
            in: existingGoals
        )

        return duplicates.first
    }

    /// Check if duplicate should block goal creation
    /// - Parameters:
    ///   - title: Goal title to check
    ///   - existingGoals: Goals to compare against (canonical GoalData)
    /// - Returns: Blocking duplicate match if found, nil otherwise
    public func checkForBlockingDuplicate(
        title: String,
        in existingGoals: [GoalData]
    ) async throws -> DuplicateMatch? {
        guard let match = try await checkForDuplicate(title: title, in: existingGoals) else {
            return nil
        }

        // Only block if configured and severity is high enough
        if config.blockOnHighSeverity && match.severity.shouldBlock {
            return match
        }

        return nil
    }
}

// MARK: - Convenience Extensions

extension SemanticGoalDetector {
    /// Batch check multiple titles for duplicates
    /// - Parameters:
    ///   - titles: Array of goal titles to check
    ///   - existingGoals: Goals to compare against (canonical GoalData)
    /// - Returns: Dictionary mapping titles to their duplicate matches
    public func batchCheck(
        titles: [String],
        in existingGoals: [GoalData]
    ) async throws -> [String: [DuplicateMatch]] {
        var results: [String: [DuplicateMatch]] = [:]

        for title in titles {
            let duplicates = try await findDuplicates(
                for: title,
                in: existingGoals
            )
            results[title] = duplicates
        }

        return results
    }

    /// Check if semantic detection is available on this device
    /// - Returns: True if NLEmbedding is available for current language
    public var isAvailable: Bool {
        return semanticService.isAvailable
    }
}
