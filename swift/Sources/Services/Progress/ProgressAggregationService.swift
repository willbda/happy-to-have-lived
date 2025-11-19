//
// ProgressAggregationService.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Aggregate progress data at different levels (goal, term, period, portfolio)
// PATTERN: Sendable service that uses ProgressCalculationService and repositories
//
// RESPONSIBILITIES:
// - Goal-level: Individual goal progress with full details
// - Term-level: All goals in a term (average, min, max, distribution)
// - Period-level: Abstract aggregation for any time period
// - Portfolio-level: All active goals across all terms
//
// CONCURRENCY: Sendable, no @MainActor (background aggregation)
//

import Database
import Foundation
import Models

/// Service for aggregating progress data at various levels
///
/// This service rolls up progress calculations into meaningful summaries:
/// - Individual goals with full progress details
/// - Terms with aggregated goal progress
/// - Arbitrary time periods (custom ranges, rolling windows)
/// - Portfolio-wide metrics across all active goals
///
/// All methods are thread-safe and perform database I/O on background threads.
public final class ProgressAggregationService: Sendable {
    // MARK: - Dependencies

    private let database: any DatabaseWriter
    private let calculationService: ProgressCalculationService

    // MARK: - Initialization

    public init(database: any DatabaseWriter, calculationService: ProgressCalculationService = ProgressCalculationService()) {
        self.database = database
        self.calculationService = calculationService
    }

    // MARK: - Goal-Level Aggregation

    /// Aggregate full progress data for a single goal
    ///
    /// This is the primary method for getting detailed progress information about a goal.
    ///
    /// - Parameter goalId: UUID of the goal
    /// - Returns: Complete goal progress data
    /// - Throws: ValidationError if goal not found or database error
    public func aggregateByGoal(goalId: UUID) async throws -> GoalProgress {
        // TODO: Implement in Phase 2 after repository enhancements
        // Steps:
        // 1. Fetch goal from GoalRepository
        // 2. Fetch actions contributing to this goal
        // 3. Extract measure targets and action measurements
        // 4. Call ProgressCalculationService methods
        // 5. Build and return GoalProgress

        fatalError("aggregateByGoal not yet implemented - Phase 2 repository integration needed")
    }

    // MARK: - Term-Level Aggregation

    /// Aggregate progress for all goals in a term
    ///
    /// Provides comprehensive metrics about how the term is progressing.
    ///
    /// - Parameter termId: UUID of the term
    /// - Returns: Aggregated term progress data
    /// - Throws: ValidationError if term not found or database error
    public func aggregateByTerm(termId: UUID) async throws -> TermProgressData {
        // TODO: Implement in Phase 2 after repository enhancements
        // Steps:
        // 1. Fetch term from TimePeriodRepository
        // 2. Fetch all goals assigned to this term
        // 3. For each goal, call aggregateByGoal()
        // 4. Calculate term time progress
        // 5. Aggregate goal progress (average, median, min, max)
        // 6. Count distribution (onTrack, behind, ahead, stalled)
        // 7. Build and return TermProgressData

        fatalError("aggregateByTerm not yet implemented - Phase 2 repository integration needed")
    }

    // MARK: - Period-Level Aggregation

    /// Aggregate progress for any time period (abstract)
    ///
    /// Allows querying progress for arbitrary date ranges.
    ///
    /// - Parameters:
    ///   - startDate: Period start date
    ///   - endDate: Period end date
    ///   - periodType: Type of period (custom, rolling, quarter, etc.)
    /// - Returns: Aggregated period progress data
    /// - Throws: ValidationError if invalid date range or database error
    public func aggregateByPeriod(
        startDate: Date,
        endDate: Date,
        periodType: PeriodType = .custom
    ) async throws -> PeriodProgressData {
        // TODO: Implement in Phase 2 after repository enhancements
        // Steps:
        // 1. Validate date range
        // 2. Fetch all goals with targetDate in range
        // 3. For each goal, call aggregateByGoal()
        // 4. Calculate period time progress
        // 5. Aggregate goal progress
        // 6. Build and return PeriodProgressData

        fatalError("aggregateByPeriod not yet implemented - Phase 2 repository integration needed")
    }

    // MARK: - Portfolio-Level Aggregation

    /// Aggregate portfolio-wide progress across all active goals
    ///
    /// Provides high-level overview of entire goal portfolio.
    ///
    /// - Returns: Portfolio progress summary
    /// - Throws: ValidationError on database error
    public func aggregatePortfolio() async throws -> PortfolioProgressData {
        // TODO: Implement in Phase 2 after repository enhancements
        // Steps:
        // 1. Fetch all active goals from GoalRepository
        // 2. For each goal, call aggregateByGoal()
        // 3. Calculate overall metrics (average, velocity, momentum)
        // 4. Aggregate by term (call aggregateByTerm for each term)
        // 5. Identify focus goals (top priorities)
        // 6. Identify struggling goals (behind schedule)
        // 7. Build and return PortfolioProgressData

        fatalError("aggregatePortfolio not yet implemented - Phase 2 repository integration needed")
    }

    // MARK: - Helper Methods

    /// Calculate median progress from a list of progress values
    ///
    /// - Parameter progressValues: Array of progress values (0.0 to 1.0)
    /// - Returns: Median progress value
    private func calculateMedian(_ progressValues: [Double]) -> Double {
        guard !progressValues.isEmpty else { return 0.0 }

        let sorted = progressValues.sorted()
        let count = sorted.count

        if count % 2 == 0 {
            // Even count: average of two middle values
            let mid1 = sorted[count / 2 - 1]
            let mid2 = sorted[count / 2]
            return (mid1 + mid2) / 2.0
        } else {
            // Odd count: middle value
            return sorted[count / 2]
        }
    }

    /// Calculate momentum score based on velocity and trend
    ///
    /// Momentum score is a 0.0-1.0 value indicating overall progress momentum.
    ///
    /// - Parameters:
    ///   - averageVelocity: Average velocity across active goals
    ///   - trends: Distribution of trends across goals
    /// - Returns: Momentum score (0.0 to 1.0)
    private func calculateMomentumScore(
        averageVelocity: Double,
        trends: [ProgressTrend: Int]
    ) -> Double {
        // Base score from velocity (normalized to 0-0.5 range)
        let velocityScore = min(0.5, averageVelocity * 10)  // Assume good velocity is ~0.05/day

        // Trend score (0-0.5 range based on trend distribution)
        let totalGoals = trends.values.reduce(0, +)
        guard totalGoals > 0 else { return velocityScore }

        let increasingCount = trends[.increasing] ?? 0
        let stableCount = trends[.stable] ?? 0
        let decreasingCount = trends[.decreasing] ?? 0
        let stalledCount = trends[.stalled] ?? 0

        // Weighted trend score
        let trendScore = (
            Double(increasingCount) * 1.0 +
            Double(stableCount) * 0.7 +
            Double(decreasingCount) * 0.3 +
            Double(stalledCount) * 0.0
        ) / Double(totalGoals) * 0.5

        return velocityScore + trendScore
    }
}
