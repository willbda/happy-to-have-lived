//
// ProgressCalculationService.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Calculate individual progress metrics for all Expectation types
// PATTERN: Sendable service with pure calculation functions
//
// RESPONSIBILITIES:
// - Goals: Calculate time progress, action progress, combined metrics, velocity, trend
// - Milestones: Calculate status based on target date proximity
// - Obligations: Calculate status based on deadline proximity
//
// CONCURRENCY: Sendable, no @MainActor (pure calculation, no UI state)
//

import Foundation
import Models

/// Service for calculating progress metrics
///
/// This service provides pure calculation functions for:
/// - Goal progress (time + action metrics)
/// - Milestone status (upcoming/due/overdue)
/// - Obligation status (pending/approaching/overdue)
/// - Velocity and trend analysis
///
/// All methods are thread-safe and suitable for background computation.
public final class ProgressCalculationService: Sendable {
    // MARK: - Constants

    /// Number of days before milestone/obligation is considered "due" or "approaching"
    private static let approachingThresholdDays = 7

    /// Number of days without action to be considered "stalled"
    private static let stalledThresholdDays = 14

    /// Weight for time progress in combined calculation (0.3 = 30%)
    private static let timeProgressWeight = 0.3

    /// Weight for action progress in combined calculation (0.7 = 70%)
    private static let actionProgressWeight = 0.7

    /// Threshold for being "ahead" of schedule (0.1 = 10% ahead)
    private static let aheadThreshold = 0.1

    // MARK: - Initialization

    public init() {}

    // MARK: - Goal Progress Calculation

    /// Calculate time-based progress for a goal
    ///
    /// Returns progress as a value from 0.0 to 1.0 representing % of time elapsed.
    /// If no start/target dates, returns 0.0.
    ///
    /// - Parameters:
    ///   - startDate: Goal start date (optional)
    ///   - targetDate: Goal target date (optional)
    ///   - currentDate: Reference date (defaults to now)
    /// - Returns: Time progress (0.0 to 1.0), days elapsed, days remaining
    public func calculateTimeProgress(
        startDate: Date?,
        targetDate: Date?,
        currentDate: Date = Date()
    ) -> (progress: Double, daysElapsed: Int?, daysRemaining: Int?) {
        guard let start = startDate, let target = targetDate else {
            return (0.0, nil, nil)
        }

        guard start < target else {
            return (1.0, 0, 0)  // Invalid date range, consider complete
        }

        let totalDays = Calendar.current.dateComponents([.day], from: start, to: target).day ?? 0
        let elapsedDays = Calendar.current.dateComponents([.day], from: start, to: currentDate).day ?? 0
        let remainingDays = Calendar.current.dateComponents([.day], from: currentDate, to: target).day ?? 0

        guard totalDays > 0 else {
            return (1.0, elapsedDays, remainingDays)
        }

        let progress = min(1.0, max(0.0, Double(elapsedDays) / Double(totalDays)))

        return (progress, elapsedDays, remainingDays)
    }

    /// Calculate action-based progress for a goal
    ///
    /// Compares actual measurements from actions against goal targets.
    ///
    /// - Parameters:
    ///   - targets: Goal measure targets (from GoalData.measureTargets)
    ///   - actions: Actions that contribute to this goal
    /// - Returns: Overall action progress (0.0 to 1.0) and per-measure progress
    public func calculateActionProgress(
        targets: [MeasureTarget],
        actions: [ActionWithMeasurements]
    ) -> (progress: Double, measureProgress: [MeasureProgress]) {
        guard !targets.isEmpty else {
            return (0.0, [])
        }

        var measureProgressList: [MeasureProgress] = []

        // Calculate progress for each measure
        for target in targets {
            // Sum all actual measurements for this measure
            let actualValue = actions.reduce(0.0) { sum, action in
                let measurementValue = action.measurements
                    .filter { $0.measureId == target.measureId }
                    .reduce(0.0) { $0 + $1.value }
                return sum + measurementValue
            }

            let progress = target.targetValue > 0
                ? min(1.0, actualValue / target.targetValue)
                : 0.0

            measureProgressList.append(
                MeasureProgress(
                    id: target.measureId,
                    measureTitle: target.measureTitle,
                    measureUnit: target.measureUnit,
                    targetValue: target.targetValue,
                    actualValue: actualValue,
                    progress: progress
                )
            )
        }

        // Overall action progress is average across all measures
        let overallProgress = measureProgressList.isEmpty
            ? 0.0
            : measureProgressList.reduce(0.0) { $0 + $1.progress } / Double(measureProgressList.count)

        return (overallProgress, measureProgressList)
    }

    /// Calculate combined progress for a goal (time + action weighted)
    ///
    /// Formula: 30% time progress + 70% action progress
    ///
    /// - Parameters:
    ///   - timeProgress: Time-based progress (0.0 to 1.0)
    ///   - actionProgress: Action-based progress (0.0 to 1.0)
    /// - Returns: Combined progress (0.0 to 1.0)
    public func calculateCombinedProgress(
        timeProgress: Double,
        actionProgress: Double
    ) -> Double {
        return (Self.timeProgressWeight * timeProgress) + (Self.actionProgressWeight * actionProgress)
    }

    /// Determine progress status by comparing progress to time elapsed
    ///
    /// - Parameters:
    ///   - combinedProgress: Overall progress (0.0 to 1.0)
    ///   - timeProgress: Time elapsed (0.0 to 1.0)
    ///   - lastActionDate: Date of most recent action
    ///   - currentDate: Reference date (defaults to now)
    /// - Returns: Progress status (onTrack, behind, ahead, stalled, completed)
    public func determineProgressStatus(
        combinedProgress: Double,
        timeProgress: Double,
        lastActionDate: Date?,
        currentDate: Date = Date()
    ) -> ProgressStatus {
        // Check if completed
        if combinedProgress >= 1.0 {
            return .completed
        }

        // Check if stalled (no action in X days)
        if let lastAction = lastActionDate {
            let daysSinceAction = Calendar.current.dateComponents([.day], from: lastAction, to: currentDate).day ?? 0
            if daysSinceAction >= Self.stalledThresholdDays {
                return .stalled
            }
        }

        // Compare progress to time
        if combinedProgress >= timeProgress + Self.aheadThreshold {
            return .ahead
        } else if combinedProgress < timeProgress {
            return .behind
        } else {
            return .onTrack
        }
    }

    /// Calculate velocity (progress per day) over recent actions
    ///
    /// - Parameters:
    ///   - actions: Recent actions with dates
    ///   - currentProgress: Current combined progress
    ///   - timePeriodDays: Number of days to analyze (default: 30)
    /// - Returns: Velocity (progress per day) or nil if insufficient data
    public func calculateVelocity(
        actions: [ActionWithMeasurements],
        currentProgress: Double,
        timePeriodDays: Int = 30
    ) -> Double? {
        guard actions.count >= 2 else {
            return nil  // Need at least 2 actions to calculate velocity
        }

        // Sort actions by date
        let sortedActions = actions.sorted { $0.logTime < $1.logTime }

        guard let firstAction = sortedActions.first,
              let lastAction = sortedActions.last else {
            return nil
        }

        let daysBetween = Calendar.current.dateComponents([.day], from: firstAction.logTime, to: lastAction.logTime).day ?? 0

        guard daysBetween > 0 else {
            return nil
        }

        // Velocity = progress / days
        return currentProgress / Double(daysBetween)
    }

    /// Determine progress trend based on recent velocity
    ///
    /// - Parameters:
    ///   - actions: Recent actions
    ///   - lastActionDate: Date of most recent action
    ///   - currentDate: Reference date
    /// - Returns: Progress trend (increasing, stable, decreasing, stalled)
    public func determineTrend(
        actions: [ActionWithMeasurements],
        lastActionDate: Date?,
        currentDate: Date = Date()
    ) -> ProgressTrend {
        // Check if stalled first
        if let lastAction = lastActionDate {
            let daysSinceAction = Calendar.current.dateComponents([.day], from: lastAction, to: currentDate).day ?? 0
            if daysSinceAction >= Self.stalledThresholdDays {
                return .stalled
            }
        }

        guard actions.count >= 4 else {
            return .stable  // Not enough data to determine trend
        }

        // Compare first half vs second half action frequency
        let sortedActions = actions.sorted { $0.logTime < $1.logTime }
        let midpoint = sortedActions.count / 2
        let firstHalf = Array(sortedActions[..<midpoint])
        let secondHalf = Array(sortedActions[midpoint...])

        guard let firstHalfStart = firstHalf.first?.logTime,
              let firstHalfEnd = firstHalf.last?.logTime,
              let secondHalfStart = secondHalf.first?.logTime,
              let secondHalfEnd = secondHalf.last?.logTime else {
            return .stable
        }

        let firstHalfDays = Calendar.current.dateComponents([.day], from: firstHalfStart, to: firstHalfEnd).day ?? 1
        let secondHalfDays = Calendar.current.dateComponents([.day], from: secondHalfStart, to: secondHalfEnd).day ?? 1

        let firstHalfRate = Double(firstHalf.count) / Double(max(1, firstHalfDays))
        let secondHalfRate = Double(secondHalf.count) / Double(max(1, secondHalfDays))

        // Compare rates with 20% threshold
        if secondHalfRate > firstHalfRate * 1.2 {
            return .increasing
        } else if secondHalfRate < firstHalfRate * 0.8 {
            return .decreasing
        } else {
            return .stable
        }
    }

    /// Estimate completion date based on current velocity
    ///
    /// - Parameters:
    ///   - currentProgress: Current combined progress (0.0 to 1.0)
    ///   - velocity: Progress per day
    ///   - currentDate: Reference date
    /// - Returns: Estimated completion date or nil if velocity is too low
    public func estimateCompletion(
        currentProgress: Double,
        velocity: Double?,
        currentDate: Date = Date()
    ) -> Date? {
        guard let vel = velocity, vel > 0 else {
            return nil
        }

        let remainingProgress = 1.0 - currentProgress
        let daysRemaining = remainingProgress / vel

        guard daysRemaining > 0, daysRemaining.isFinite else {
            return nil
        }

        return Calendar.current.date(byAdding: .day, value: Int(daysRemaining), to: currentDate)
    }

    // MARK: - Milestone Status Calculation

    /// Calculate status for a milestone based on target date proximity
    ///
    /// - Parameters:
    ///   - milestone: Milestone to evaluate
    ///   - currentDate: Reference date (defaults to now)
    /// - Returns: Milestone status (upcoming, due, overdue, completed)
    public func calculateMilestoneStatus(
        milestone: MilestoneWithDetails,
        currentDate: Date = Date()
    ) -> MilestoneStatus {
        let targetDate = milestone.milestone.targetDate

        // Check if overdue
        if targetDate < currentDate {
            return .overdue
        }

        // Check if due soon (within threshold)
        let daysUntil = Calendar.current.dateComponents([.day], from: currentDate, to: targetDate).day ?? 0
        if daysUntil <= Self.approachingThresholdDays {
            return .due
        }

        // Otherwise upcoming
        return .upcoming
    }

    // MARK: - Obligation Status Calculation

    /// Calculate status for an obligation based on deadline proximity
    ///
    /// - Parameters:
    ///   - obligation: Obligation to evaluate
    ///   - currentDate: Reference date (defaults to now)
    /// - Returns: Obligation status (pending, approaching, overdue, completed)
    public func calculateObligationStatus(
        obligation: ObligationWithDetails,
        currentDate: Date = Date()
    ) -> ObligationStatus {
        let deadline = obligation.obligation.deadline

        // Check if overdue
        if deadline < currentDate {
            return .overdue
        }

        // Check if approaching (within threshold)
        let daysUntil = Calendar.current.dateComponents([.day], from: currentDate, to: deadline).day ?? 0
        if daysUntil <= Self.approachingThresholdDays {
            return .approaching
        }

        // Otherwise pending
        return .pending
    }
}

// MARK: - Helper Types

/// Simplified measure target for progress calculation
public struct MeasureTarget: Sendable {
    public let measureId: UUID
    public let measureTitle: String?
    public let measureUnit: String
    public let targetValue: Double

    public init(measureId: UUID, measureTitle: String?, measureUnit: String, targetValue: Double) {
        self.measureId = measureId
        self.measureTitle = measureTitle
        self.measureUnit = measureUnit
        self.targetValue = targetValue
    }
}

/// Simplified action with measurements for progress calculation
public struct ActionWithMeasurements: Sendable {
    public let id: UUID
    public let logTime: Date
    public let measurements: [ActionMeasurement]

    public init(id: UUID, logTime: Date, measurements: [ActionMeasurement]) {
        self.id = id
        self.logTime = logTime
        self.measurements = measurements
    }
}

/// Simplified measurement for progress calculation
public struct ActionMeasurement: Sendable {
    public let measureId: UUID
    public let value: Double

    public init(measureId: UUID, value: Double) {
        self.measureId = measureId
        self.value = value
    }
}
