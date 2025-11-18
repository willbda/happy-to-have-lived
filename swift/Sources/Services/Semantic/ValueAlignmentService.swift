//
// ValueAlignmentService.swift
// Written by Claude Code on 2025-11-18
//
// PURPOSE:
// Compute goal-value alignment matrix using semantic embeddings.
// Generates similarity scores for all goal×value pairs for heatmap visualization.
//
// DESIGN DECISIONS:
// - Goals use titleOnly variant (faster, title is semantic key)
// - Values use fullContext variant (richer conceptual meaning)
// - Batch embedding fetching for performance
// - Returns structured AlignmentMatrix type
//
// ARCHITECTURE:
// ValueAlignmentService → EmbeddingGenerationService → SemanticService → NLEmbedding
//
// USAGE:
// ```swift
// let service = ValueAlignmentService(database: database)
// let matrix = try await service.computeAlignmentMatrix(goals: goals, values: values)
// ```

import Foundation
import Models
import Database
import SQLiteData

/// Service for computing goal-value alignment using semantic embeddings
///
/// **Pattern**: Sendable service (NOT @MainActor, background I/O)
///
/// **Performance**:
/// - Embeddings cached in semanticEmbeddings table
/// - Batch fetching for goals and values
/// - O(goals × values) similarity computations (negligible for typical data)
///
/// **Typical Use Case**:
/// - 20 goals × 10 values = 200 similarity computations (~5ms total)
/// - Cached embeddings = no NLEmbedding overhead
@available(iOS 26.0, macOS 26.0, *)
public final class ValueAlignmentService: Sendable {

    // MARK: - Properties

    private let database: any DatabaseWriter

    // MARK: - Initialization

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Public API

    /// Compute alignment matrix for all goals × values
    ///
    /// **Algorithm**:
    /// 1. Fetch/generate embeddings for all goals (titleOnly variant)
    /// 2. Fetch/generate embeddings for all values (fullContext variant)
    /// 3. Compute cosine similarity for each goal×value pair
    /// 4. Build structured AlignmentMatrix
    ///
    /// **Performance**:
    /// - First run: ~100ms (embedding generation)
    /// - Subsequent runs: ~10ms (cached embeddings)
    ///
    /// - Parameters:
    ///   - goals: Goals to compute alignments for (rows)
    ///   - values: Values to compute alignments for (columns)
    /// - Returns: AlignmentMatrix with similarity scores
    /// - Throws: DatabaseError if embedding operations fail
    public func computeAlignmentMatrix(
        goals: [GoalData],
        values: [PersonalValueData]
    ) async throws -> AlignmentMatrix {
        // Edge cases
        guard !goals.isEmpty, !values.isEmpty else {
            return AlignmentMatrix(goals: goals, values: values, similarities: [])
        }

        // STEP 1: Fetch goal embeddings (titleOnly for fast comparison)
        let goalEmbeddings = try await fetchGoalEmbeddings(goals, variant: .titleOnly)

        // STEP 2: Fetch value embeddings (fullContext for richer meaning)
        let valueEmbeddings = try await fetchValueEmbeddings(values, variant: .fullContext)

        // STEP 3: Compute similarity matrix (goals × values)
        let similarities = computeSimilarityMatrix(
            goals: goals,
            goalEmbeddings: goalEmbeddings,
            values: values,
            valueEmbeddings: valueEmbeddings
        )

        // STEP 4: Build structured matrix
        return AlignmentMatrix(goals: goals, values: values, similarities: similarities)
    }

    // MARK: - Embedding Fetching

    /// Fetch or generate embeddings for all goals
    ///
    /// **Pattern**: Batch fetching for performance
    /// **Variant**: titleOnly (goals identified by title)
    ///
    /// - Parameters:
    ///   - goals: Goals to embed
    ///   - variant: Embedding variant (titleOnly or fullContext)
    /// - Returns: Dictionary mapping goal ID → embedding vector
    /// - Throws: DatabaseError if embedding generation fails
    private func fetchGoalEmbeddings(
        _ goals: [GoalData],
        variant: EmbeddingSourceVariant
    ) async throws -> [UUID: EmbeddingVector] {
        let embeddingService = EmbeddingGenerationService(database: database)

        var embeddings: [UUID: EmbeddingVector] = [:]

        for goal in goals {
            // Generate or fetch cached embedding
            if let vector = try await embeddingService.generateGoalEmbedding(
                goal: goal,
                variant: variant
            ) {
                embeddings[goal.id] = vector
            } else {
                // NLEmbedding unavailable or empty source text
                // Use zero vector (no similarity to anything)
                embeddings[goal.id] = EmbeddingVector(values: Array(repeating: 0.0, count: 768))
            }
        }

        return embeddings
    }

    /// Fetch or generate embeddings for all values
    ///
    /// **Pattern**: Batch fetching for performance
    /// **Variant**: fullContext (values include guidance, domain, description)
    ///
    /// - Parameters:
    ///   - values: Values to embed
    ///   - variant: Embedding variant (titleOnly or fullContext)
    /// - Returns: Dictionary mapping value ID → embedding vector
    /// - Throws: DatabaseError if embedding generation fails
    private func fetchValueEmbeddings(
        _ values: [PersonalValueData],
        variant: EmbeddingSourceVariant
    ) async throws -> [UUID: EmbeddingVector] {
        let embeddingService = EmbeddingGenerationService(database: database)

        var embeddings: [UUID: EmbeddingVector] = [:]

        for value in values {
            // Generate or fetch cached embedding
            if let vector = try await embeddingService.generateValueEmbedding(
                value: value,
                variant: variant
            ) {
                embeddings[value.id] = vector
            } else {
                // NLEmbedding unavailable or empty source text
                // Use zero vector (no similarity to anything)
                embeddings[value.id] = EmbeddingVector(values: Array(repeating: 0.0, count: 768))
            }
        }

        return embeddings
    }

    // MARK: - Similarity Computation

    /// Compute similarity matrix for all goal×value pairs
    ///
    /// **Algorithm**: Cosine similarity for each pair
    /// **Complexity**: O(goals × values × dimensions) = O(20 × 10 × 768) ≈ 153,600 ops
    /// **Performance**: ~5ms for typical dataset
    ///
    /// - Parameters:
    ///   - goals: Goals (rows)
    ///   - goalEmbeddings: Embedding vectors for goals
    ///   - values: Values (columns)
    ///   - valueEmbeddings: Embedding vectors for values
    /// - Returns: 2D array of similarity scores [goalIndex][valueIndex]
    private func computeSimilarityMatrix(
        goals: [GoalData],
        goalEmbeddings: [UUID: EmbeddingVector],
        values: [PersonalValueData],
        valueEmbeddings: [UUID: EmbeddingVector]
    ) -> [[Double]] {
        var similarities: [[Double]] = []

        for goal in goals {
            var row: [Double] = []

            guard let goalVector = goalEmbeddings[goal.id] else {
                // Missing goal embedding - fill row with zeros
                row = Array(repeating: 0.0, count: values.count)
                similarities.append(row)
                continue
            }

            for value in values {
                guard let valueVector = valueEmbeddings[value.id] else {
                    // Missing value embedding - zero similarity
                    row.append(0.0)
                    continue
                }

                // Compute cosine similarity
                let similarity = goalVector.cosineSimilarity(to: valueVector)
                row.append(similarity)
            }

            similarities.append(row)
        }

        return similarities
    }

    // MARK: - Individual Alignment

    /// Compute alignment between a single goal and value
    ///
    /// **Use Case**: On-demand similarity check (not heatmap)
    ///
    /// - Parameters:
    ///   - goal: Goal to compare
    ///   - value: Value to compare
    /// - Returns: Similarity score (0.0 - 1.0)
    /// - Throws: DatabaseError if embedding generation fails
    public func computeAlignment(
        goal: GoalData,
        value: PersonalValueData
    ) async throws -> Double {
        let embeddingService = EmbeddingGenerationService(database: database)

        // Fetch embeddings
        guard let goalVector = try await embeddingService.generateGoalEmbedding(
            goal: goal,
            variant: .titleOnly
        ),
              let valueVector = try await embeddingService.generateValueEmbedding(
            value: value,
            variant: .fullContext
        ) else {
            return 0.0  // NLEmbedding unavailable
        }

        // Compute similarity
        return goalVector.cosineSimilarity(to: valueVector)
    }

    // MARK: - Top Alignments

    /// Find top N values aligned with a goal
    ///
    /// **Use Case**: "Which values does this goal serve most?"
    ///
    /// - Parameters:
    ///   - goal: Goal to analyze
    ///   - values: Values to consider
    ///   - topN: Number of top alignments to return
    /// - Returns: Sorted array of (value, similarity) pairs
    /// - Throws: DatabaseError if embedding operations fail
    public func findTopValueAlignments(
        for goal: GoalData,
        among values: [PersonalValueData],
        topN: Int = 5
    ) async throws -> [(value: PersonalValueData, similarity: Double)] {
        let embeddingService = EmbeddingGenerationService(database: database)

        // Fetch goal embedding
        guard let goalVector = try await embeddingService.generateGoalEmbedding(
            goal: goal,
            variant: .titleOnly
        ) else {
            return []
        }

        // Compute similarities for all values
        var alignments: [(value: PersonalValueData, similarity: Double)] = []

        for value in values {
            guard let valueVector = try await embeddingService.generateValueEmbedding(
                value: value,
                variant: .fullContext
            ) else {
                continue
            }

            let similarity = goalVector.cosineSimilarity(to: valueVector)
            alignments.append((value: value, similarity: similarity))
        }

        // Sort by similarity (descending) and take top N
        return alignments
            .sorted { $0.similarity > $1.similarity }
            .prefix(topN)
            .map { $0 }
    }
}

// MARK: - Usage Examples

/*
 // Compute full alignment matrix for heatmap
 let service = ValueAlignmentService(database: database)
 let goals = try await goalRepository.fetchAll()
 let values = try await valueRepository.fetchAll()

 let matrix = try await service.computeAlignmentMatrix(goals: goals, values: values)
 // Result: AlignmentMatrix with 20×10 = 200 similarity scores

 // Access individual cell
 let cell = matrix[0, 0]
 print("Goal '\(goals[0].title ?? "")' aligns with value '\(values[0].title)' at \(cell.similarity)")

 // Find top alignments for a goal
 let topAlignments = try await service.findTopValueAlignments(
     for: myGoal,
     among: allValues,
     topN: 3
 )
 for (value, similarity) in topAlignments {
     print("Value '\(value.title)': \(similarity)")
 }
 // Output:
 // Value 'Health': 0.89
 // Value 'Discipline': 0.76
 // Value 'Adventure': 0.62
 */
