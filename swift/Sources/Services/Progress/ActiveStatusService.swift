//
// ActiveStatusService.swift
// Written by Claude Code on 2025-11-19
// Trimmed by Claude Code on 2025-11-19
//
// PURPOSE: Helper service for determining active status of expectations
// PATTERN: Sendable service that delegates to ProgressCalculationService
//
// RESPONSIBILITIES:
// - Determine if goals are truly "active" (considering term status, dates, completion)
// - Provide status for milestones (upcoming/due/overdue)
// - Provide status for obligations (pending/approaching/overdue)
//
// CONCURRENCY: Sendable, no @MainActor (background calculation)
//
// NOTE: For filtering by status, use repository methods directly:
// - MilestoneRepository.fetchByStatus()
// - ObligationRepository.fetchByStatus()
//

import Database
import Foundation
import Models

/// Service for determining active status of expectations
///
/// This service provides simple helper methods for status checking.
/// For database filtering by status, use repository methods instead.
///
/// All methods are thread-safe and suitable for background computation.
public final class ActiveStatusService: Sendable {
    // MARK: - Dependencies

    private let calculationService: ProgressCalculationService

    // MARK: - Initialization

    public init(calculationService: ProgressCalculationService = ProgressCalculationService()) {
        self.calculationService = calculationService
    }

    // MARK: - Goal Active Status

    /// Enhanced active detection for a goal
    ///
    /// A goal is active if:
    /// 1. Its term (if assigned) is active or planned (not cancelled/delayed/on_hold)
    /// 2. Current date is between startDate and targetDate
    /// 3. Goal is not completed
    ///
    /// - Parameters:
    ///   - goalId: Goal UUID
    ///   - startDate: Goal start date (optional)
    ///   - targetDate: Goal target date (optional)
    ///   - termStatus: Status of the term this goal is assigned to (if any)
    ///   - currentDate: Reference date (defaults to now)
    /// - Returns: True if goal is active
    public func isGoalActive(
        goalId: UUID,
        startDate: Date?,
        targetDate: Date?,
        termStatus: String?,
        currentDate: Date = Date()
    ) -> Bool {
        // Rule 1: If assigned to a term, respect term status
        if let status = termStatus {
            // Only active/planned terms have active goals
            guard status == "active" || status == "planned" else {
                return false
            }
        }

        // Rule 2: Check if goal period is current
        if let target = targetDate, target < currentDate {
            return false  // Past target date = inactive
        }

        if let start = startDate, start > currentDate {
            return false  // Future start date = not yet active
        }

        // Rule 3: No target date = open-ended goal (active)
        return true
    }

    // MARK: - Milestone Status

    /// Get milestone status
    ///
    /// Delegates to ProgressCalculationService for actual calculation.
    ///
    /// - Parameters:
    ///   - milestone: Milestone to evaluate
    ///   - currentDate: Reference date (defaults to now)
    /// - Returns: Milestone status (upcoming/due/overdue/completed)
    public func getMilestoneStatus(
        milestone: MilestoneWithDetails,
        currentDate: Date = Date()
    ) -> MilestoneStatus {
        return calculationService.calculateMilestoneStatus(
            milestone: milestone,
            currentDate: currentDate
        )
    }

    // MARK: - Obligation Status

    /// Get obligation status
    ///
    /// Delegates to ProgressCalculationService for actual calculation.
    ///
    /// - Parameters:
    ///   - obligation: Obligation to evaluate
    ///   - currentDate: Reference date (defaults to now)
    /// - Returns: Obligation status (pending/approaching/overdue/completed)
    public func getObligationStatus(
        obligation: ObligationWithDetails,
        currentDate: Date = Date()
    ) -> ObligationStatus {
        return calculationService.calculateObligationStatus(
            obligation: obligation,
            currentDate: currentDate
        )
    }
}
