//
// AlignmentInsights.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE:
// Structured insights derived from goal-value alignment matrix.
// Provides meaningful interpretations of semantic similarity data.
//
// DESIGN PHILOSOPHY:
// Raw cosine similarity scores (0.0-1.0) are meaningless to users.
// Transform embedding data into actionable insights about:
// - Which values are underserved
// - Which goals are holistic vs narrow
// - Overall portfolio balance
//
// USAGE:
// ```swift
// let insights = AlignmentInsights(matrix: matrix)
// insights.underservedValues // Values with weak goal alignment
// insights.holisticGoals      // Goals that serve multiple values
// ```

import Foundation

/// Structured insights derived from alignment matrix
///
/// **Transforms raw cosine similarity into actionable insights**:
/// - Value coverage: Which values lack supporting goals?
/// - Goal focus: Which goals are narrow vs holistic?
/// - Portfolio balance: Overall alignment health
@available(iOS 26.0, macOS 26.0, *)
public struct AlignmentInsights: Sendable {

    // MARK: - Input Data

    /// Source alignment matrix
    public let matrix: AlignmentMatrix

    // MARK: - Initialization

    public init(matrix: AlignmentMatrix) {
        self.matrix = matrix
    }

    // MARK: - Value Coverage Insights

    /// Values that lack strong goal alignment (need attention)
    ///
    /// **Criteria**: Average similarity < 0.60 across all goals
    /// **Interpretation**: These values are underserved by current goals
    /// **Action**: Consider creating goals that align with these values
    public var underservedValues: [ValueCoverage] {
        matrix.values.enumerated().compactMap { (valueIndex, value) in
            let alignments = matrix.goals.indices.map { goalIndex in
                matrix[goalIndex, valueIndex].similarity
            }
            let avgAlignment = alignments.reduce(0.0, +) / Double(alignments.count)

            guard avgAlignment < 0.60 else { return nil }

            return ValueCoverage(
                value: value,
                averageAlignment: avgAlignment,
                strongGoalCount: alignments.filter { $0 >= 0.75 }.count,
                recommendation: recommendationFor(avgAlignment: avgAlignment)
            )
        }
        .sorted { $0.averageAlignment < $1.averageAlignment }
    }

    /// Values with strong goal support (well covered)
    ///
    /// **Criteria**: Average similarity >= 0.60 across all goals
    /// **Interpretation**: These values are well-represented in goal portfolio
    public var wellServedValues: [ValueCoverage] {
        matrix.values.enumerated().compactMap { (valueIndex, value) in
            let alignments = matrix.goals.indices.map { goalIndex in
                matrix[goalIndex, valueIndex].similarity
            }
            let avgAlignment = alignments.reduce(0.0, +) / Double(alignments.count)

            guard avgAlignment >= 0.60 else { return nil }

            return ValueCoverage(
                value: value,
                averageAlignment: avgAlignment,
                strongGoalCount: alignments.filter { $0 >= 0.75 }.count,
                recommendation: recommendationFor(avgAlignment: avgAlignment)
            )
        }
        .sorted { $0.averageAlignment > $1.averageAlignment }
    }

    // MARK: - Goal Focus Insights

    /// Goals that align strongly with multiple values (holistic)
    ///
    /// **Criteria**: 3+ values with similarity >= 0.75
    /// **Interpretation**: These goals serve multiple life areas
    /// **Benefit**: High leverage - progress serves many values
    public var holisticGoals: [GoalFocus] {
        matrix.goals.enumerated().compactMap { (goalIndex, goal) in
            let alignments = matrix.values.indices.map { valueIndex in
                (value: matrix.values[valueIndex], similarity: matrix[goalIndex, valueIndex].similarity)
            }
            let strongAlignments = alignments.filter { $0.similarity >= 0.75 }

            guard strongAlignments.count >= 3 else { return nil }

            return GoalFocus(
                goal: goal,
                alignedValues: strongAlignments.map { $0.value },
                focusType: .holistic,
                primaryValue: alignments.max { $0.similarity < $1.similarity }?.value
            )
        }
    }

    /// Goals that align strongly with 1-2 values (focused)
    ///
    /// **Criteria**: 1-2 values with similarity >= 0.75
    /// **Interpretation**: These goals are highly focused on specific values
    /// **Benefit**: Clear purpose, easier to measure progress
    public var focusedGoals: [GoalFocus] {
        matrix.goals.enumerated().compactMap { (goalIndex, goal) in
            let alignments = matrix.values.indices.map { valueIndex in
                (value: matrix.values[valueIndex], similarity: matrix[goalIndex, valueIndex].similarity)
            }
            let strongAlignments = alignments.filter { $0.similarity >= 0.75 }

            guard strongAlignments.count >= 1 && strongAlignments.count <= 2 else { return nil }

            return GoalFocus(
                goal: goal,
                alignedValues: strongAlignments.map { $0.value },
                focusType: .focused,
                primaryValue: alignments.max { $0.similarity < $1.similarity }?.value
            )
        }
    }

    /// Goals with weak alignment across all values (disconnected)
    ///
    /// **Criteria**: No values with similarity >= 0.75
    /// **Interpretation**: Goal may not align with stated values
    /// **Action**: Review goal or clarify value alignment
    public var disconnectedGoals: [GoalFocus] {
        matrix.goals.enumerated().compactMap { (goalIndex, goal) in
            let alignments = matrix.values.indices.map { valueIndex in
                (value: matrix.values[valueIndex], similarity: matrix[goalIndex, valueIndex].similarity)
            }
            let strongAlignments = alignments.filter { $0.similarity >= 0.75 }

            guard strongAlignments.isEmpty else { return nil }

            return GoalFocus(
                goal: goal,
                alignedValues: [],
                focusType: .disconnected,
                primaryValue: alignments.max { $0.similarity < $1.similarity }?.value
            )
        }
    }

    // MARK: - Portfolio Health

    /// Overall portfolio health metrics
    ///
    /// **Aggregates**:
    /// - Average goal-value alignment
    /// - Value coverage percentage
    /// - Goal focus distribution
    /// - Disconnected goal count
    public var portfolioHealth: PortfolioHealth {
        let allSimilarities = matrix.cells.map { $0.similarity }
        let avgAlignment = allSimilarities.reduce(0.0, +) / Double(allSimilarities.count)

        let valueCoverageRatio = Double(wellServedValues.count) / Double(matrix.values.count)

        let goalDistribution = GoalDistribution(
            holistic: holisticGoals.count,
            focused: focusedGoals.count,
            disconnected: disconnectedGoals.count
        )

        return PortfolioHealth(
            averageAlignment: avgAlignment,
            valueCoveragePercentage: valueCoverageRatio * 100.0,
            goalDistribution: goalDistribution,
            overallScore: calculateOverallScore(
                avgAlignment: avgAlignment,
                valueCoverage: valueCoverageRatio,
                disconnectedCount: disconnectedGoals.count
            )
        )
    }

    // MARK: - Helper Methods

    private func recommendationFor(avgAlignment: Double) -> String {
        switch avgAlignment {
        case 0.0..<0.30:
            return "Create goals that directly support this value"
        case 0.30..<0.45:
            return "Consider how existing goals could better serve this value"
        case 0.45..<0.60:
            return "Weak alignment - review goal descriptions to strengthen connection"
        case 0.60..<0.75:
            return "Moderate alignment - goals partially support this value"
        default:
            return "Strong alignment - goals support this value well"
        }
    }

    private func calculateOverallScore(
        avgAlignment: Double,
        valueCoverage: Double,
        disconnectedCount: Int
    ) -> Double {
        // Weighted scoring: 40% avg alignment + 40% value coverage + 20% penalty for disconnected
        let alignmentScore = avgAlignment * 0.4
        let coverageScore = valueCoverage * 0.4
        let disconnectedPenalty = Double(disconnectedCount) * 0.02 // -2% per disconnected goal

        return min(1.0, max(0.0, alignmentScore + coverageScore - disconnectedPenalty))
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, macOS 26.0, *)
extension AlignmentInsights {

    /// Value coverage analysis
    public struct ValueCoverage: Identifiable, Sendable {
        public var id: UUID { value.id }

        public let value: PersonalValueData
        public let averageAlignment: Double
        public let strongGoalCount: Int
        public let recommendation: String

        /// Severity level for UI presentation
        public var severity: Severity {
            switch averageAlignment {
            case 0.0..<0.30:
                return .critical
            case 0.30..<0.45:
                return .high
            case 0.45..<0.60:
                return .moderate
            default:
                return .low
            }
        }
    }

    /// Goal focus analysis
    public struct GoalFocus: Identifiable, Sendable {
        public var id: UUID { goal.id }

        public let goal: GoalData
        public let alignedValues: [PersonalValueData]
        public let focusType: FocusType
        public let primaryValue: PersonalValueData?

        public enum FocusType: String, Sendable {
            case holistic = "Holistic"
            case focused = "Focused"
            case disconnected = "Disconnected"
        }
    }

    /// Portfolio health metrics
    public struct PortfolioHealth: Sendable {
        public let averageAlignment: Double
        public let valueCoveragePercentage: Double
        public let goalDistribution: GoalDistribution
        public let overallScore: Double

        /// Health level for UI presentation
        public var healthLevel: HealthLevel {
            switch overallScore {
            case 0.0..<0.40:
                return .poor
            case 0.40..<0.60:
                return .fair
            case 0.60..<0.80:
                return .good
            default:
                return .excellent
            }
        }
    }

    /// Distribution of goal focus types
    public struct GoalDistribution: Sendable {
        public let holistic: Int
        public let focused: Int
        public let disconnected: Int

        public var total: Int { holistic + focused + disconnected }
    }

    /// Severity levels for value coverage
    public enum Severity: String, Sendable {
        case critical = "Critical"
        case high = "High"
        case moderate = "Moderate"
        case low = "Low"
    }

    /// Health levels for portfolio assessment
    public enum HealthLevel: String, Sendable {
        case poor = "Needs Attention"
        case fair = "Fair"
        case good = "Good"
        case excellent = "Excellent"
    }
}