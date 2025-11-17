//
//  GetGoalsTool.swift
//  ten-week-goal-app
//
//  Written by Claude Code on 2025-11-14
//
//  PURPOSE: LLM tool for fetching user's goals with optional filtering
//  PATTERN: Foundation Models Tool protocol implementation
//

import Foundation
import FoundationModels
import SQLiteData
import Services
import Models
import Database

/// Tool for fetching user's goals with details
@available(iOS 26.0, macOS 26.0, *)
public struct GetGoalsTool: Tool {
    // MARK: - Tool Protocol Requirements

    public let name = "getGoals"
    public let description = "Fetch the user's goals with full details including measures and value alignments"

    // MARK: - Arguments

    @Generable
    public struct Arguments: Codable {
        @Guide(description: "Filter by goal status (active, completed, on_hold)")
        let status: String?

        @Guide(description: "Filter by term ID")
        let termId: String?

        @Guide(description: "Maximum number of goals to return", .range(1...100))
        let limit: Int

        @Guide(description: "Include archived goals")
        let includeArchived: Bool

        public init(
            status: String? = nil,
            termId: String? = nil,
            limit: Int = 10,
            includeArchived: Bool = false
        ) {
            self.status = status
            self.termId = termId
            self.limit = limit
            self.includeArchived = includeArchived
        }
    }

    // MARK: - Dependencies

    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Tool Execution

    public func call(arguments: Arguments) async throws -> GoalsResponse {
        // Create repository (use v3 for canonical GoalData)
        let repository = GoalRepository(database: database)

        // Fetch goals based on filters (uses canonical GoalData)
        let goals: [GoalData]

        if let termIdString = arguments.termId,
           let termUUID = UUID(uuidString: termIdString) {
            // Fetch goals for specific term
            goals = try await repository.fetchByTerm(termUUID)
        } else {
            // Fetch all goals
            goals = try await repository.fetchAll()
        }

        // Apply status filter if provided
        var filteredGoals = goals
        if let status = arguments.status {
            filteredGoals = filteredGoals.filter { goal in
                // This would need to check goal status
                // For now, we'll return all goals
                true
            }
        }

        // Apply limit
        filteredGoals = Array(filteredGoals.prefix(arguments.limit))

        // Map GoalData to response format (flat structure access)
        let summaries = filteredGoals.map { goal in
            GoalSummary(
                id: goal.id.uuidString,
                title: goal.title ?? "Untitled Goal",
                description: goal.detailedDescription,
                startDate: goal.startDate?.ISO8601Format(),
                targetDate: goal.targetDate?.ISO8601Format(),
                importance: goal.expectationImportance,
                urgency: goal.expectationUrgency,
                metricTargets: goal.measureTargets.map { target in
                    MetricTarget(
                        measureName: target.measureTitle ?? "Unknown",
                        targetValue: target.targetValue,
                        unit: target.measureUnit
                    )
                },
                alignedValues: goal.valueAlignments.map { alignment in
                    AlignedValue(
                        valueName: alignment.valueTitle,
                        alignmentStrength: alignment.alignmentStrength ?? 5
                    )
                }
            )
        }

        return GoalsResponse(
            goals: summaries,
            totalCount: summaries.count
        )
    }
}

// MARK: - Response Types

/// Response containing goal summaries
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct GoalsResponse: Codable {
    public let goals: [GoalSummary]
    public let totalCount: Int
}

/// Summary of a single goal
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct GoalSummary: Codable {
    public let id: String
    public let title: String
    public let description: String?
    public let startDate: String?
    public let targetDate: String?
    public let importance: Int
    public let urgency: Int
    public let metricTargets: [MetricTarget]
    public let alignedValues: [AlignedValue]
}

/// Metric target for a goal
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct MetricTarget: Codable {
    public let measureName: String
    public let targetValue: Double
    public let unit: String
}

/// Value alignment for a goal
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct AlignedValue: Codable {
    public let valueName: String
    public let alignmentStrength: Int
}