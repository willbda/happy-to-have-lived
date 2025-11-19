//
// ProgressData.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Canonical data types for progress tracking across all Expectation types
// PATTERN: Sendable, Codable, Identifiable for safe concurrency and serialization
//
// USAGE:
// - Goals: Full progress tracking (time + action metrics, velocity, trend)
// - Milestones: Status tracking (upcoming, due, overdue, completed)
// - Obligations: Deadline tracking (pending, approaching, overdue, completed)
//

import Foundation

// MARK: - Status Enums

/// Status for goals based on progress vs time elapsed
public enum ProgressStatus: String, Codable, Sendable, CaseIterable {
    case onTrack = "on_track"     // progress >= timeProgress
    case behind = "behind"         // progress < timeProgress
    case ahead = "ahead"           // progress > timeProgress + 0.1
    case stalled = "stalled"       // no actions in 14+ days
    case completed = "completed"   // progress >= 1.0
}

/// Trend direction for goal progress velocity
public enum ProgressTrend: String, Codable, Sendable, CaseIterable {
    case increasing = "increasing"  // Velocity increasing over time
    case stable = "stable"          // Steady progress
    case decreasing = "decreasing"  // Slowing down
    case stalled = "stalled"        // No recent progress
}

/// Status for milestones (point-in-time checkpoints)
public enum MilestoneStatus: String, Codable, Sendable, CaseIterable {
    case upcoming = "upcoming"      // targetDate > now + 7 days
    case due = "due"                // targetDate within 7 days
    case overdue = "overdue"        // targetDate < now
    case completed = "completed"    // Manually marked complete
}

/// Status for obligations (external commitments with deadlines)
public enum ObligationStatus: String, Codable, Sendable, CaseIterable {
    case pending = "pending"        // deadline > now + 7 days
    case approaching = "approaching" // deadline within 7 days
    case overdue = "overdue"        // deadline < now
    case completed = "completed"    // Manually marked complete
}

/// Type of time period for aggregation
public enum PeriodType: String, Codable, Sendable, CaseIterable {
    case term = "term"              // GoalTerm (structured planning)
    case custom = "custom"          // User-defined range
    case rolling = "rolling"        // Last N days
    case quarter = "quarter"        // Calendar quarter
    case year = "year"              // Calendar year
}

// MARK: - Goal Progress Types

/// Progress data for a single measure within a goal
public struct MeasureProgress: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // measureId
    public let measureTitle: String?
    public let measureUnit: String
    public let targetValue: Double
    public let actualValue: Double
    public let progress: Double            // 0.0 to 1.0

    public init(
        id: UUID,
        measureTitle: String?,
        measureUnit: String,
        targetValue: Double,
        actualValue: Double,
        progress: Double
    ) {
        self.id = id
        self.measureTitle = measureTitle
        self.measureUnit = measureUnit
        self.targetValue = targetValue
        self.actualValue = actualValue
        self.progress = progress
    }
}

/// Complete progress data for a single goal
public struct GoalProgress: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // goalId

    // Time-based progress
    public let timeProgress: Double        // 0.0 to 1.0 (% of time elapsed)
    public let daysElapsed: Int?
    public let daysRemaining: Int?

    // Action-based progress
    public let actionProgress: Double      // 0.0 to 1.0 (% of targets achieved)
    public let measureProgress: [MeasureProgress]

    // Combined metrics
    public let combinedProgress: Double    // Weighted: 30% time + 70% action
    public let progressStatus: ProgressStatus  // .onTrack, .behind, .ahead, .stalled

    // Velocity & trend
    public let velocity: Double?           // Progress per day
    public let trend: ProgressTrend        // .increasing, .stable, .decreasing, .stalled
    public let lastActionDate: Date?
    public let estimatedCompletion: Date?  // Based on velocity

    // Metadata
    public let calculatedAt: Date

    public init(
        id: UUID,
        timeProgress: Double,
        daysElapsed: Int?,
        daysRemaining: Int?,
        actionProgress: Double,
        measureProgress: [MeasureProgress],
        combinedProgress: Double,
        progressStatus: ProgressStatus,
        velocity: Double?,
        trend: ProgressTrend,
        lastActionDate: Date?,
        estimatedCompletion: Date?,
        calculatedAt: Date
    ) {
        self.id = id
        self.timeProgress = timeProgress
        self.daysElapsed = daysElapsed
        self.daysRemaining = daysRemaining
        self.actionProgress = actionProgress
        self.measureProgress = measureProgress
        self.combinedProgress = combinedProgress
        self.progressStatus = progressStatus
        self.velocity = velocity
        self.trend = trend
        self.lastActionDate = lastActionDate
        self.estimatedCompletion = estimatedCompletion
        self.calculatedAt = calculatedAt
    }
}

/// Compact summary of goal progress (for lists and aggregations)
public struct GoalProgressSummary: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // goalId
    public let title: String?
    public let combinedProgress: Double
    public let progressStatus: ProgressStatus
    public let trend: ProgressTrend

    public init(
        id: UUID,
        title: String?,
        combinedProgress: Double,
        progressStatus: ProgressStatus,
        trend: ProgressTrend
    ) {
        self.id = id
        self.title = title
        self.combinedProgress = combinedProgress
        self.progressStatus = progressStatus
        self.trend = trend
    }
}

// MARK: - Term Progress Types

/// Aggregated progress for all goals in a term
public struct TermProgressData: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // termId
    public let termNumber: Int
    public let status: String  // TermStatus.rawValue

    // Time boundaries
    public let startDate: Date
    public let endDate: Date
    public let timeProgress: Double        // 0.0 to 1.0
    public let daysElapsed: Int
    public let daysRemaining: Int

    // Goal counts
    public let totalGoals: Int
    public let activeGoals: Int
    public let completedGoals: Int
    public let stalledGoals: Int

    // Aggregated progress
    public let averageProgress: Double     // Mean of all goal progress
    public let medianProgress: Double      // Median (more robust to outliers)
    public let minProgress: Double
    public let maxProgress: Double

    // Distribution
    public let goalsOnTrack: Int           // progress >= timeProgress
    public let goalsBehind: Int            // progress < timeProgress
    public let goalsAhead: Int             // progress > timeProgress + 0.1

    // Individual goal summaries
    public let goalProgress: [GoalProgressSummary]

    // Metadata
    public let calculatedAt: Date

    public init(
        id: UUID,
        termNumber: Int,
        status: String,
        startDate: Date,
        endDate: Date,
        timeProgress: Double,
        daysElapsed: Int,
        daysRemaining: Int,
        totalGoals: Int,
        activeGoals: Int,
        completedGoals: Int,
        stalledGoals: Int,
        averageProgress: Double,
        medianProgress: Double,
        minProgress: Double,
        maxProgress: Double,
        goalsOnTrack: Int,
        goalsBehind: Int,
        goalsAhead: Int,
        goalProgress: [GoalProgressSummary],
        calculatedAt: Date
    ) {
        self.id = id
        self.termNumber = termNumber
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
        self.timeProgress = timeProgress
        self.daysElapsed = daysElapsed
        self.daysRemaining = daysRemaining
        self.totalGoals = totalGoals
        self.activeGoals = activeGoals
        self.completedGoals = completedGoals
        self.stalledGoals = stalledGoals
        self.averageProgress = averageProgress
        self.medianProgress = medianProgress
        self.minProgress = minProgress
        self.maxProgress = maxProgress
        self.goalsOnTrack = goalsOnTrack
        self.goalsBehind = goalsBehind
        self.goalsAhead = goalsAhead
        self.goalProgress = goalProgress
        self.calculatedAt = calculatedAt
    }
}

/// Compact summary of term progress (for portfolio view)
public struct TermProgressSummary: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // termId
    public let termNumber: Int
    public let status: String
    public let averageProgress: Double
    public let goalsCount: Int

    public init(
        id: UUID,
        termNumber: Int,
        status: String,
        averageProgress: Double,
        goalsCount: Int
    ) {
        self.id = id
        self.termNumber = termNumber
        self.status = status
        self.averageProgress = averageProgress
        self.goalsCount = goalsCount
    }
}

// MARK: - Period Progress Types

/// Abstract progress data for ANY time period (not just terms)
///
/// Use cases:
/// - Custom date ranges ("Show progress for Q1 2025")
/// - Rolling windows ("Show progress for last 30 days")
/// - Fiscal years, sprints, arbitrary periods
public struct PeriodProgressData: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // Generated ID for the period
    public let periodType: PeriodType
    public let startDate: Date
    public let endDate: Date

    // Same structure as TermProgressData
    public let timeProgress: Double
    public let daysElapsed: Int
    public let daysRemaining: Int
    public let totalGoals: Int
    public let activeGoals: Int
    public let averageProgress: Double
    public let goalProgress: [GoalProgressSummary]
    public let calculatedAt: Date

    public init(
        id: UUID,
        periodType: PeriodType,
        startDate: Date,
        endDate: Date,
        timeProgress: Double,
        daysElapsed: Int,
        daysRemaining: Int,
        totalGoals: Int,
        activeGoals: Int,
        averageProgress: Double,
        goalProgress: [GoalProgressSummary],
        calculatedAt: Date
    ) {
        self.id = id
        self.periodType = periodType
        self.startDate = startDate
        self.endDate = endDate
        self.timeProgress = timeProgress
        self.daysElapsed = daysElapsed
        self.daysRemaining = daysRemaining
        self.totalGoals = totalGoals
        self.activeGoals = activeGoals
        self.averageProgress = averageProgress
        self.goalProgress = goalProgress
        self.calculatedAt = calculatedAt
    }
}

// MARK: - Portfolio Progress Types

/// Portfolio-wide progress summary across all expectations
public struct PortfolioProgressData: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // Portfolio ID (could be userId in future)

    // Overall metrics
    public let totalGoals: Int
    public let activeGoals: Int
    public let completedGoals: Int
    public let stalledGoals: Int

    // Progress distribution
    public let averageProgress: Double
    public let goalsOnTrack: Int
    public let goalsBehind: Int
    public let goalsAhead: Int

    // Velocity & momentum
    public let portfolioVelocity: Double   // Average velocity across active goals
    public let momentumScore: Double       // 0.0 to 1.0 (based on trend + velocity)

    // By term breakdown
    public let termProgress: [TermProgressSummary]

    // Top insights
    public let focusGoals: [GoalProgressSummary]  // Top 3-5 priorities
    public let strugglingGoals: [GoalProgressSummary]  // Needs attention

    public let calculatedAt: Date

    public init(
        id: UUID,
        totalGoals: Int,
        activeGoals: Int,
        completedGoals: Int,
        stalledGoals: Int,
        averageProgress: Double,
        goalsOnTrack: Int,
        goalsBehind: Int,
        goalsAhead: Int,
        portfolioVelocity: Double,
        momentumScore: Double,
        termProgress: [TermProgressSummary],
        focusGoals: [GoalProgressSummary],
        strugglingGoals: [GoalProgressSummary],
        calculatedAt: Date
    ) {
        self.id = id
        self.totalGoals = totalGoals
        self.activeGoals = activeGoals
        self.completedGoals = completedGoals
        self.stalledGoals = stalledGoals
        self.averageProgress = averageProgress
        self.goalsOnTrack = goalsOnTrack
        self.goalsBehind = goalsBehind
        self.goalsAhead = goalsAhead
        self.portfolioVelocity = portfolioVelocity
        self.momentumScore = momentumScore
        self.termProgress = termProgress
        self.focusGoals = focusGoals
        self.strugglingGoals = strugglingGoals
        self.calculatedAt = calculatedAt
    }
}

// MARK: - Expectation Summary Types

/// Combined summary of all active expectations across types
public struct ExpectationSummary: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // Summary ID

    // Goals
    public let totalGoals: Int
    public let activeGoals: Int
    public let completedGoals: Int

    // Milestones
    public let totalMilestones: Int
    public let upcomingMilestones: Int
    public let dueMilestones: Int
    public let overdueMilestones: Int

    // Obligations
    public let totalObligations: Int
    public let pendingObligations: Int
    public let approachingObligations: Int
    public let overdueObligations: Int

    // Combined metrics
    public let totalActiveExpectations: Int
    public let highUrgencyCount: Int  // expectationUrgency >= 8

    public let calculatedAt: Date

    public init(
        id: UUID,
        totalGoals: Int,
        activeGoals: Int,
        completedGoals: Int,
        totalMilestones: Int,
        upcomingMilestones: Int,
        dueMilestones: Int,
        overdueMilestones: Int,
        totalObligations: Int,
        pendingObligations: Int,
        approachingObligations: Int,
        overdueObligations: Int,
        totalActiveExpectations: Int,
        highUrgencyCount: Int,
        calculatedAt: Date
    ) {
        self.id = id
        self.totalGoals = totalGoals
        self.activeGoals = activeGoals
        self.completedGoals = completedGoals
        self.totalMilestones = totalMilestones
        self.upcomingMilestones = upcomingMilestones
        self.dueMilestones = dueMilestones
        self.overdueMilestones = overdueMilestones
        self.totalObligations = totalObligations
        self.pendingObligations = pendingObligations
        self.approachingObligations = approachingObligations
        self.overdueObligations = overdueObligations
        self.totalActiveExpectations = totalActiveExpectations
        self.highUrgencyCount = highUrgencyCount
        self.calculatedAt = calculatedAt
    }
}
