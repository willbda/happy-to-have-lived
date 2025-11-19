//
// ActiveStatusService.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Enhanced active/inactive detection and filtering for all Expectation types
// PATTERN: Sendable service that uses ProgressCalculationService and repositories
//
// RESPONSIBILITIES:
// - Determine if goals are truly "active" (considering term status, dates, completion)
// - Filter milestones by status (upcoming, due vs overdue)
// - Filter obligations by status (pending, approaching vs overdue)
// - Provide "focus set" for dashboard (prioritized active expectations)
//
// CONCURRENCY: Sendable, no @MainActor (background filtering)
//

import Database
import Foundation
import Models

/// Service for determining active status and filtering expectations
///
/// This service provides enhanced logic for determining which expectations
/// are "active" and should be displayed prominently in the UI:
/// - Goals: Consider term status, dates, and completion state
/// - Milestones: Filter to upcoming/due (exclude overdue)
/// - Obligations: Filter to pending/approaching (exclude overdue)
///
/// All methods are thread-safe and perform database I/O on background threads.
public final class ActiveStatusService: Sendable {
    // MARK: - Dependencies

    private let database: any DatabaseWriter
    private let calculationService: ProgressCalculationService

    // MARK: - Initialization

    public init(database: any DatabaseWriter, calculationService: ProgressCalculationService = ProgressCalculationService()) {
        self.database = database
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
    ///   - goal: Goal to evaluate
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

    /// Get all active goals
    ///
    /// - Returns: Array of active goals
    /// - Throws: ValidationError on database error
    public func getActiveGoals() async throws -> [GoalWithDetails] {
        // TODO: Implement in Phase 2 after repository enhancements
        // Steps:
        // 1. Fetch all goals from GoalRepository
        // 2. For each goal, check term status if assigned
        // 3. Filter using isGoalActive()
        // 4. Return filtered list

        fatalError("getActiveGoals not yet implemented - Phase 2 repository integration needed")
    }

    /// Get focus set for dashboard (top priority active goals)
    ///
    /// Focus set is a small set (3-5) of highest priority active goals.
    ///
    /// - Parameter limit: Maximum number of goals to return (default: 5)
    /// - Returns: Array of focus goals sorted by priority
    /// - Throws: ValidationError on database error
    public func getFocusSet(limit: Int = 5) async throws -> [GoalWithDetails] {
        // TODO: Implement in Phase 2 after repository enhancements
        // Steps:
        // 1. Get all active goals
        // 2. Sort by: importance * urgency (descending)
        // 3. Take top N
        // 4. Return sorted list

        fatalError("getFocusSet not yet implemented - Phase 2 repository integration needed")
    }

    // MARK: - Milestone Active Status

    /// Get milestone status
    ///
    /// - Parameters:
    ///   - milestone: Milestone to evaluate
    ///   - currentDate: Reference date (defaults to now)
    /// - Returns: Milestone status
    public func getMilestoneStatus(
        milestone: MilestoneWithDetails,
        currentDate: Date = Date()
    ) -> MilestoneStatus {
        return calculationService.calculateMilestoneStatus(
            milestone: milestone,
            currentDate: currentDate
        )
    }

    /// Get all active milestones (upcoming or due, not overdue)
    ///
    /// - Returns: Array of active milestones
    /// - Throws: ValidationError on database error
    public func getActiveMilestones() async throws -> [MilestoneWithDetails] {
        // TODO: Implement in Phase 2 after repository enhancements
        // Steps:
        // 1. Fetch all milestones from MilestoneRepository
        // 2. Calculate status for each milestone
        // 3. Filter to upcoming and due (exclude overdue)
        // 4. Sort by targetDate ASC
        // 5. Return filtered list

        fatalError("getActiveMilestones not yet implemented - Phase 2 repository integration needed")
    }

    // MARK: - Obligation Active Status

    /// Get obligation status
    ///
    /// - Parameters:
    ///   - obligation: Obligation to evaluate
    ///   - currentDate: Reference date (defaults to now)
    /// - Returns: Obligation status
    public func getObligationStatus(
        obligation: ObligationWithDetails,
        currentDate: Date = Date()
    ) -> ObligationStatus {
        return calculationService.calculateObligationStatus(
            obligation: obligation,
            currentDate: currentDate
        )
    }

    /// Get all active obligations (pending or approaching, not overdue)
    ///
    /// - Returns: Array of active obligations
    /// - Throws: ValidationError on database error
    public func getActiveObligations() async throws -> [ObligationWithDetails] {
        // TODO: Implement in Phase 2 after repository enhancements
        // Steps:
        // 1. Fetch all obligations from ObligationRepository
        // 2. Calculate status for each obligation
        // 3. Filter to pending and approaching (exclude overdue)
        // 4. Sort by deadline ASC
        // 5. Return filtered list

        fatalError("getActiveObligations not yet implemented - Phase 2 repository integration needed")
    }

    // MARK: - Term Active Status

    /// Get all active terms
    ///
    /// A term is active if:
    /// 1. Status is "active" or "planned"
    /// 2. End date is in the future
    ///
    /// - Returns: Array of active terms
    /// - Throws: ValidationError on database error
    public func getActiveTerms() async throws -> [TimePeriodData] {
        // TODO: Implement in Phase 2 after repository enhancements
        // Steps:
        // 1. Fetch all terms from TimePeriodRepository
        // 2. Filter to status = active or planned
        // 3. Filter to endDate >= now
        // 4. Return filtered list

        fatalError("getActiveTerms not yet implemented - Phase 2 repository integration needed")
    }

    // MARK: - Combined Expectation Summary

    /// Get summary of all active expectations across types
    ///
    /// Provides a high-level overview of all active expectations:
    /// - Goals: Active count
    /// - Milestones: Counts by status
    /// - Obligations: Counts by status
    ///
    /// - Returns: Combined expectation summary
    /// - Throws: ValidationError on database error
    public func getAllActiveExpectations() async throws -> ExpectationSummary {
        // TODO: Implement in Phase 2 after repository enhancements
        // Steps:
        // 1. Fetch all goals, count active
        // 2. Fetch all milestones, count by status
        // 3. Fetch all obligations, count by status
        // 4. Calculate combined metrics
        // 5. Build and return ExpectationSummary

        fatalError("getAllActiveExpectations not yet implemented - Phase 2 repository integration needed")
    }
}

// MARK: - Helper Types

/// Simplified goal details for active status checking
public struct GoalWithDetails: Sendable {
    public let id: UUID
    public let startDate: Date?
    public let targetDate: Date?
    public let termStatus: String?
    public let importance: Int
    public let urgency: Int

    public init(
        id: UUID,
        startDate: Date?,
        targetDate: Date?,
        termStatus: String?,
        importance: Int,
        urgency: Int
    ) {
        self.id = id
        self.startDate = startDate
        self.targetDate = targetDate
        self.termStatus = termStatus
        self.importance = importance
        self.urgency = urgency
    }
}
