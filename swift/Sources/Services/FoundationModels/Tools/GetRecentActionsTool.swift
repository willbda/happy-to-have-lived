//
//  GetRecentActionsTool.swift
//  ten-week-goal-app
//
//  Written by Claude Code on 2025-11-14
//
//  PURPOSE: LLM tool for fetching recent actions for reflection
//  PATTERN: Foundation Models Tool protocol implementation
//

import Foundation
import FoundationModels
import SQLiteData
import Services

/// Tool for fetching recent actions to support reflection conversations
@available(iOS 26.0, macOS 26.0, *)
public struct GetRecentActionsTool: Tool {
    // MARK: - Tool Protocol Requirements

    public let name = "getRecentActions"
    public let description =
        "Fetch recent actions the user has taken, including measurements and goal contributions"

    // MARK: - Arguments

    @Generable
    public struct Arguments: Codable {
        @Guide(description: "Number of days to look back", .range(1...365))
        let daysBack: Int

        @Guide(description: "Filter by goal ID to see actions for a specific goal")
        let goalId: String?

        @Guide(description: "Maximum number of actions to return", .range(1...100))
        let limit: Int

        @Guide(description: "Include actions without measurements")
        let includeUnmeasured: Bool

        public init(
            daysBack: Int = 7,
            goalId: String? = nil,
            limit: Int = 20,
            includeUnmeasured: Bool = true
        ) {
            self.daysBack = daysBack
            self.goalId = goalId
            self.limit = limit
            self.includeUnmeasured = includeUnmeasured
        }
    }

    // MARK: - Dependencies

    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Tool Execution

    public func call(arguments: Arguments) async throws -> RecentActionsResponse {
        // Calculate date range
        let endDate = Date()
        let startDate =
            Calendar.current.date(
                byAdding: .day,
                value: -arguments.daysBack,
                to: endDate
            ) ?? endDate

        // Create repository
        let repository = ActionRepository(database: database)

        // Fetch all actions (repository doesn't have date filtering yet)
        var actions = try await repository.fetchAll()

        // Filter by date range
        actions = actions.filter { action in
            action.logTime >= startDate && action.logTime <= endDate
        }

        // Filter by goal if specified
        if let goalIdString = arguments.goalId,
            let goalUUID = UUID(uuidString: goalIdString)
        {
            actions = actions.filter { action in
                action.contributions.contains { contribution in
                    contribution.goalId == goalUUID
                }
            }
        }

        // Filter by measurement status if needed
        if !arguments.includeUnmeasured {
            actions = actions.filter { !$0.measurements.isEmpty }
        }

        // Sort by date (most recent first) and apply limit
        actions =
            actions
            .sorted { $0.logTime > $1.logTime }
            .prefix(arguments.limit)
            .map { $0 }

        // Map to response format
        let summaries = actions.map { action in
            ActionSummary(
                id: action.id.uuidString.lowercased(),
                title: action.title ?? "Untitled Action",
                description: action.detailedDescription,
                logTime: action.logTime.ISO8601Format(),
                durationMinutes: action.durationMinutes,
                measurements: action.measurements.map { measurement in
                    LLMActionMeasurement(
                        measureName: measurement.measureTitle ?? "Unknown",
                        value: measurement.value,
                        unit: measurement.measureUnit
                    )
                },
                goalContributions: action.contributions.map { contribution in
                    GoalContribution(
                        goalId: contribution.goalId.uuidString,
                        goalTitle: contribution.goalTitle
                            ?? "Goal \(contribution.goalId.uuidString.prefix(8))",
                        contributionAmount: contribution.contributionAmount
                    )
                }
            )
        }

        // Calculate summary statistics
        let totalActions = summaries.count
        let totalDuration = summaries.compactMap { $0.durationMinutes }.reduce(0, +)
        let goalsWorkedOn = Set(summaries.flatMap { $0.goalContributions.map { $0.goalId } }).count

        return RecentActionsResponse(
            actions: summaries,
            totalActions: totalActions,
            totalDurationMinutes: totalDuration,
            uniqueGoalsWorkedOn: goalsWorkedOn,
            dateRange: DateRange(
                start: startDate.ISO8601Format(),
                end: endDate.ISO8601Format()
            )
        )
    }
}

// MARK: - Response Types

/// Response containing recent action summaries
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct RecentActionsResponse: Codable {
    public let actions: [ActionSummary]
    public let totalActions: Int
    public let totalDurationMinutes: Double
    public let uniqueGoalsWorkedOn: Int
    public let dateRange: DateRange
}

/// Summary of an action
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct ActionSummary: Codable {
    public let id: String
    public let title: String
    public let description: String?
    public let logTime: String
    public let durationMinutes: Double?
    public let measurements: [LLMActionMeasurement]
    public let goalContributions: [GoalContribution]
}

/// Measurement recorded for an action (for LLM tool output)
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct LLMActionMeasurement: Codable {
    public let measureName: String
    public let value: Double
    public let unit: String
}

/// Goal contribution from an action
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct GoalContribution: Codable {
    public let goalId: String
    public let goalTitle: String
    public let contributionAmount: Double?
}

/// Date range for the query
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct DateRange: Codable {
    public let start: String
    public let end: String
}
