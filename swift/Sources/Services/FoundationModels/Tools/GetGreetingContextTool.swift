//
//  GetGreetingContextTool.swift
//  ten-week-goal-app
//
//  Written by Claude Code on 2025-11-20
//
//  PURPOSE: Provide LLM with minimal, focused context for generating personalized greetings
//  PATTERN: Foundation Models Tool protocol with context-efficient data summaries
//
//  DESIGN PHILOSOPHY:
//  - Minimize context window usage (summaries, not full entities)
//  - Fast queries (limit to recent data only)
//  - Single-call tool (returns everything needed for greeting generation)
//  - No user input required (automatic context gathering)
//

import Database
import Foundation
import FoundationModels
import Models
import SQLiteData
import Services

/// Tool for fetching compact greeting context (values, recent activity, neglected goals)
/// Designed for minimal context window usage in single-shot greeting generation
@available(iOS 26.0, macOS 26.0, *)
public struct GetGreetingContextTool: Tool {
    // MARK: - Tool Protocol Requirements

    public let name = "getGreetingContext"
    public let description = """
        Get compact summary of user's top value, recent activity (last 3 days), \
        and any goals needing attention. Returns minimal data optimized for greeting generation.
        """

    // MARK: - Arguments (none needed - automatic context gathering)

    @Generable
    public struct Arguments: Codable {
        // No arguments - tool automatically gathers relevant context

        public init() {}
    }

    // MARK: - Dependencies

    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Tool Execution

    public func call(arguments: Arguments) async throws -> GreetingContext {
        // Parallel queries for efficiency
        async let topValueTask = fetchTopValue()
        async let recentActivityTask = fetchRecentActivity()
        async let neglectedGoalsTask = fetchNeglectedGoals()

        let topValue = try await topValueTask
        let activity = try await recentActivityTask
        let neglectedGoals = try await neglectedGoalsTask

        // Calculate time of day for greeting
        let timeOfDay = determineTimeOfDay()

        return GreetingContext(
            timeOfDay: timeOfDay,
            topValue: topValue,
            recentActivity: activity,
            neglectedGoals: neglectedGoals
        )
    }

    // MARK: - Private Query Methods

    /// Fetch user's single highest-priority value (minimal data)
    /// Priority semantics: LOWER number = HIGHER priority (like Unix nice values)
    /// Repository returns ORDER BY priority ASC, so .first() gives highest priority
    private func fetchTopValue() async throws -> ValueSummaryCompact? {
        let repository = PersonalValueRepository(database: database)
        let values = try await repository.fetchAll()

        // fetchAll() returns ORDER BY priority ASC (1, 2, 3...)
        // Lower number = higher priority, so .first() is the highest priority value
        guard let topValue = values.first else {
            return nil
        }

        return ValueSummaryCompact(
            title: topValue.title,
            priority: topValue.priority,
            lifeDomain: topValue.lifeDomain
        )
    }

    /// Fetch activity summary for last 3 days (counts only, not full entities)
    private func fetchRecentActivity() async throws -> RecentActivitySummary {
        let repository = ActionRepository(database: database)
        let allActions = try await repository.fetchAll()

        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()

        let recentActions = allActions.filter { $0.logTime >= threeDaysAgo }

        let totalActions = recentActions.count
        let totalDuration = recentActions.compactMap { $0.durationMinutes }.reduce(0, +)
        let uniqueGoalsWorkedOn = Set(
            recentActions.flatMap { $0.contributions.map { $0.goalId } }
        ).count

        return RecentActivitySummary(
            totalActions: totalActions,
            totalDurationMinutes: Int(totalDuration),
            uniqueGoalsWorkedOn: uniqueGoalsWorkedOn,
            daysLookedBack: 3
        )
    }

    /// Fetch goals with no recent actions (max 3, high priority only)
    private func fetchNeglectedGoals() async throws -> [NeglectedGoalSummary] {
        let goalRepository = GoalRepository(database: database)
        let actionRepository = ActionRepository(database: database)

        let allGoals = try await goalRepository.fetchAll()
        let allActions = try await actionRepository.fetchAll()

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        // Find goals with no actions in last 7 days
        var neglected: [NeglectedGoalSummary] = []

        for goal in allGoals {
            // Get actions for this goal
            let actionsForGoal = allActions.filter { action in
                action.contributions.contains { $0.goalId == goal.id }
            }

            // Find most recent action
            let mostRecentAction = actionsForGoal.max { $0.logTime < $1.logTime }

            // Calculate days since last action
            let daysSinceAction: Int
            if let lastAction = mostRecentAction {
                let days = Calendar.current.dateComponents(
                    [.day],
                    from: lastAction.logTime,
                    to: Date()
                ).day ?? 0
                daysSinceAction = days
            } else {
                daysSinceAction = 999  // Never logged action
            }

            // Only report if neglected AND high importance/urgency
            let isHighPriority = goal.expectationImportance >= 7 || goal.expectationUrgency >= 7
            let isNeglected = daysSinceAction >= 7

            if isNeglected && isHighPriority {
                // Calculate urgency score for sorting
                let urgencyScore = goal.expectationImportance + goal.expectationUrgency

                neglected.append(
                    NeglectedGoalSummary(
                        goalId: goal.id.uuidString,
                        title: goal.title ?? "Untitled Goal",
                        daysSinceLastAction: daysSinceAction,
                        importance: goal.expectationImportance,
                        urgency: goal.expectationUrgency,
                        urgencyScore: urgencyScore
                    )
                )
            }
        }

        // Return top 3 most urgent neglected goals
        return Array(
            neglected
                .sorted { $0.urgencyScore > $1.urgencyScore }
                .prefix(3)
        )
    }

    /// Determine time of day for greeting
    private func determineTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "morning"
        case 12..<17:
            return "afternoon"
        case 17..<22:
            return "evening"
        default:
            return "night"
        }
    }
}

// MARK: - Response Types

/// Complete context for greeting generation (all data needed in one call)
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct GreetingContext: Codable {
    @Guide(description: "Time of day: 'morning', 'afternoon', 'evening', or 'night'")
    public let timeOfDay: String

    @Guide(description: "User's highest-priority value (if any)")
    public let topValue: ValueSummaryCompact?

    @Guide(description: "Summary of recent activity (last 3 days)")
    public let recentActivity: RecentActivitySummary

    @Guide(description: "High-priority goals with no recent actions (max 3)")
    public let neglectedGoals: [NeglectedGoalSummary]

    public init(
        timeOfDay: String,
        topValue: ValueSummaryCompact?,
        recentActivity: RecentActivitySummary,
        neglectedGoals: [NeglectedGoalSummary]
    ) {
        self.timeOfDay = timeOfDay
        self.topValue = topValue
        self.recentActivity = recentActivity
        self.neglectedGoals = neglectedGoals
    }
}

/// Compact value summary (title only, no full description)
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct ValueSummaryCompact: Codable {
    public let title: String
    public let priority: Int
    public let lifeDomain: String?

    public init(title: String, priority: Int, lifeDomain: String?) {
        self.title = title
        self.priority = priority
        self.lifeDomain = lifeDomain
    }
}

/// Activity summary (counts only, no full action data)
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct RecentActivitySummary: Codable {
    public let totalActions: Int
    public let totalDurationMinutes: Int
    public let uniqueGoalsWorkedOn: Int
    public let daysLookedBack: Int

    public init(
        totalActions: Int,
        totalDurationMinutes: Int,
        uniqueGoalsWorkedOn: Int,
        daysLookedBack: Int
    ) {
        self.totalActions = totalActions
        self.totalDurationMinutes = totalDurationMinutes
        self.uniqueGoalsWorkedOn = uniqueGoalsWorkedOn
        self.daysLookedBack = daysLookedBack
    }
}

/// Neglected goal summary (minimal data for focus suggestion)
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct NeglectedGoalSummary: Codable {
    public let goalId: String
    public let title: String
    public let daysSinceLastAction: Int
    public let importance: Int
    public let urgency: Int

    // Internal field for sorting (not part of LLM response)
    let urgencyScore: Int

    public init(
        goalId: String,
        title: String,
        daysSinceLastAction: Int,
        importance: Int,
        urgency: Int,
        urgencyScore: Int
    ) {
        self.goalId = goalId
        self.title = title
        self.daysSinceLastAction = daysSinceLastAction
        self.importance = importance
        self.urgency = urgency
        self.urgencyScore = urgencyScore
    }
}
