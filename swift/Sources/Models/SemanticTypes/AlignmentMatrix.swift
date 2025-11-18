//
// AlignmentMatrix.swift
// Written by Claude Code on 2025-11-18
//
// PURPOSE:
// Structured container for goal-value alignment heatmap data.
// Holds similarity scores between all goals and values with color-coded levels.
//
// DESIGN DECISIONS:
// - Flat cell array for efficient access (avoid nested arrays)
// - Computed alignment levels for UI color mapping
// - Sendable for Swift 6 concurrency
// - Identifiable cells for SwiftUI Grid rendering
//
// USAGE:
// ```swift
// let matrix = AlignmentMatrix(goals: goals, values: values, similarities: scores)
// let cell = matrix[goalIndex, valueIndex]
// let color = cell.alignmentLevel.color
// ```

import Foundation
import Models
import SwiftUI

/// Structured container for goal-value alignment heatmap
///
/// **Architecture**:
/// - Goals = Rows (vertical axis)
/// - Values = Columns (horizontal axis)
/// - Cells = Similarity scores with color-coded levels
///
/// **Access Pattern**:
/// ```swift
/// let cell = matrix[goalIndex, valueIndex]
/// // Returns Cell with goalId, valueId, similarity score
/// ```
public struct AlignmentMatrix: Sendable {

    // MARK: - Properties

    /// Goals (row headers)
    public let goals: [GoalData]

    /// Values (column headers)
    public let values: [PersonalValueData]

    /// Flat array of all cells (goals.count × values.count)
    /// Layout: [g0v0, g0v1, g0v2, g1v0, g1v1, g1v2, ...]
    public let cells: [Cell]

    // MARK: - Initialization

    /// Create alignment matrix from goals, values, and similarity scores
    ///
    /// - Parameters:
    ///   - goals: Goals to display (rows)
    ///   - values: Values to display (columns)
    ///   - similarities: 2D array of similarity scores [goalIndex][valueIndex]
    public init(goals: [GoalData], values: [PersonalValueData], similarities: [[Double]]) {
        self.goals = goals
        self.values = values

        // Flatten 2D similarity array into Cell objects
        var cells: [Cell] = []
        for (goalIndex, goal) in goals.enumerated() {
            for (valueIndex, value) in values.enumerated() {
                let similarity = similarities[goalIndex][valueIndex]
                let cell = Cell(
                    goalId: goal.id,
                    valueId: value.id,
                    similarity: similarity
                )
                cells.append(cell)
            }
        }

        self.cells = cells
    }

    // MARK: - Subscript Access

    /// Access cell by goal and value indices
    ///
    /// **Usage**:
    /// ```swift
    /// let cell = matrix[goalIndex, valueIndex]
    /// ```
    ///
    /// - Parameters:
    ///   - goalIndex: Row index (0..<goals.count)
    ///   - valueIndex: Column index (0..<values.count)
    /// - Returns: Cell with similarity score
    public subscript(goalIndex: Int, valueIndex: Int) -> Cell {
        let index = goalIndex * values.count + valueIndex
        return cells[index]
    }

    // MARK: - Statistics

    /// Compute statistics across entire matrix
    public var statistics: Statistics {
        let similarities = cells.map { $0.similarity }
        return Statistics(
            minSimilarity: similarities.min() ?? 0.0,
            maxSimilarity: similarities.max() ?? 1.0,
            avgSimilarity: similarities.reduce(0.0, +) / Double(similarities.count),
            strongAlignmentCount: cells.filter { $0.alignmentLevel == .strong || $0.alignmentLevel == .veryStrong }.count
        )
    }
}

// MARK: - Cell

extension AlignmentMatrix {
    /// Individual cell in alignment matrix
    ///
    /// Represents similarity between one goal and one value.
    public struct Cell: Identifiable, Hashable, Sendable {
        /// Unique identifier (goalId_valueId)
        public var id: String { "\(goalId)_\(valueId)" }

        /// Goal ID (row)
        public let goalId: UUID

        /// Value ID (column)
        public let valueId: UUID

        /// Cosine similarity score (0.0 = orthogonal, 1.0 = identical)
        public let similarity: Double

        // MARK: - Computed Alignment Level

        /// Categorical alignment level based on similarity threshold
        ///
        /// **Interpretation**:
        /// - Very Strong (0.90+): Near-identical semantic meaning
        /// - Strong (0.75-0.89): Clearly aligned concepts
        /// - Moderate (0.60-0.74): Related concepts
        /// - Weak (<0.60): Minimal semantic overlap
        public var alignmentLevel: AlignmentLevel {
            switch similarity {
            case 0.90...:
                return .veryStrong
            case 0.75..<0.90:
                return .strong
            case 0.60..<0.75:
                return .moderate
            default:
                return .weak
            }
        }
    }
}

// MARK: - Alignment Level

extension AlignmentMatrix {
    /// Categorical alignment strength
    public enum AlignmentLevel: String, Sendable, CaseIterable {
        case weak = "Weak"
        case moderate = "Moderate"
        case strong = "Strong"
        case veryStrong = "Very Strong"

        /// Color for heatmap visualization (Liquid Glass compatible)
        ///
        /// Uses semantic colors that work on rich backgrounds with .regularMaterial
        public var color: Color {
            switch self {
            case .weak:
                return .gray
            case .moderate:
                return .yellow
            case .strong:
                return .orange
            case .veryStrong:
                return .red
            }
        }

        /// Opacity multiplier for color intensity
        ///
        /// **Design Note**: Base opacity 0.3, scaled by similarity for smooth gradation
        /// Works with Liquid Glass materials for legibility
        public func opacity(for similarity: Double) -> Double {
            return 0.3 + (similarity * 0.7)  // Range: 0.3 - 1.0
        }
    }
}

// MARK: - Statistics

extension AlignmentMatrix {
    /// Summary statistics for alignment matrix
    public struct Statistics: Sendable {
        public let minSimilarity: Double
        public let maxSimilarity: Double
        public let avgSimilarity: Double
        public let strongAlignmentCount: Int

        /// Percentage of cells with strong/very strong alignment
        public func strongAlignmentPercentage(totalCells: Int) -> Double {
            guard totalCells > 0 else { return 0.0 }
            return (Double(strongAlignmentCount) / Double(totalCells)) * 100.0
        }
    }
}

// MARK: - Usage Example

/*
 // Create matrix from repository data
 let goals = try await goalRepository.fetchAll()
 let values = try await valueRepository.fetchAll()

 // Compute similarity scores (goals × values)
 let similarities: [[Double]] = goals.map { goal in
     values.map { value in
         cosineSimilarity(goalEmbedding(goal), valueEmbedding(value))
     }
 }

 // Build matrix
 let matrix = AlignmentMatrix(goals: goals, values: values, similarities: similarities)

 // Access cell
 let cell = matrix[0, 0]  // First goal, first value
 print("Similarity: \(cell.similarity)")
 print("Level: \(cell.alignmentLevel.rawValue)")
 print("Color: \(cell.alignmentLevel.color)")

 // Display in heatmap
 Grid {
     ForEach(matrix.goals.indices, id: \.self) { goalIndex in
         GridRow {
             ForEach(matrix.values.indices, id: \.self) { valueIndex in
                 let cell = matrix[goalIndex, valueIndex]
                 AlignmentCell(cell: cell)
             }
         }
     }
 }
 */
