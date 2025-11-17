//
//  CheckDuplicateGoalTool.swift
//  ten-week-goal-app
//
//  Written by Claude Code on 2025-11-14
//
//  PURPOSE: LLM tool for checking if a goal title would be a duplicate
//  PATTERN: Foundation Models Tool protocol implementation
//

import Foundation
import FoundationModels
import SQLiteData
import Services
import Models

/// Tool for checking if a goal would be a duplicate before creation
@available(iOS 26.0, macOS 26.0, *)
public struct CheckDuplicateGoalTool: Tool {
    // MARK: - Tool Protocol Requirements

    public let name = "checkDuplicateGoal"
    public let description = "Check if a goal title would duplicate an existing goal using semantic similarity"

    // MARK: - Arguments

    @Generable
    public struct Arguments: Codable {
        @Guide(description: "Goal title to check for duplicates")
        let title: String

        @Guide(description: "Goal description to include in similarity check")
        let description: String?

        @Guide(description: "Similarity threshold (0.0-1.0, default 0.75)")
        let threshold: Double

        @Guide(description: "Maximum similar goals to return", .range(1...20))
        let maxResults: Int

        public init(
            title: String,
            description: String? = nil,
            threshold: Double = 0.75,
            maxResults: Int = 5
        ) {
            self.title = title
            self.description = description
            self.threshold = threshold
            self.maxResults = maxResults
        }
    }

    // MARK: - Dependencies

    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Tool Execution

    public func call(arguments: Arguments) async throws -> DuplicateCheckResponse {
        // Validate input
        guard !arguments.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolError.invalidInput("Goal title is required")
        }

        // Validate threshold
        let validThreshold = max(0.0, min(1.0, arguments.threshold))

        // Fetch existing goals (canonical GoalData)
        let repository = GoalRepository_v3(database: database)
        let existingGoals = try await repository.fetchAll()

        // Check if no existing goals
        if existingGoals.isEmpty {
            return DuplicateCheckResponse(
                isDuplicate: false,
                similarGoals: [],
                recommendedAction: "No existing goals found. Safe to create new goal."
            )
        }

        // Try semantic checking first
        let semanticService = SemanticService(database: database, configuration: .default)

        do {
            return try await performSemanticCheck(
                semanticService: semanticService,
                existingGoals: existingGoals,
                threshold: validThreshold,
                title: arguments.title,
                description: arguments.description,
                maxResults: arguments.maxResults
            )
        } catch {
            // Fall back to exact matching if semantic check fails
            return performExactCheck(
                existingGoals: existingGoals,
                title: arguments.title,
                maxResults: arguments.maxResults
            )
        }
    }

    // MARK: - Private Methods

    /// Perform semantic similarity checking
    private func performSemanticCheck(
        semanticService: SemanticService,
        existingGoals: [GoalData],
        threshold: Double,
        title: String,
        description: String?,
        maxResults: Int
    ) async throws -> DuplicateCheckResponse {
        // Convert GoalData to GoalWithExpectation for detector
        // This is necessary because SemanticGoalDetector expects Goal + Expectation entities
        let goalsForDetection = existingGoals.map { goalData in
            GoalWithExpectation(
                goal: Goal(
                    expectationId: goalData.expectationId,
                    startDate: goalData.startDate,
                    targetDate: goalData.targetDate,
                    actionPlan: goalData.actionPlan,
                    expectedTermLength: goalData.expectedTermLength,
                    id: goalData.id
                ),
                expectation: Expectation(
                    title: goalData.title,
                    detailedDescription: goalData.detailedDescription,
                    freeformNotes: goalData.freeformNotes,
                    expectationType: .goal,
                    expectationImportance: goalData.expectationImportance,
                    expectationUrgency: goalData.expectationUrgency,
                    logTime: goalData.logTime,
                    id: goalData.expectationId
                )
            )
        }

        // Create duplication detector
        let detector = SemanticGoalDetector(
            semanticService: semanticService,
            config: DeduplicationConfig(
                minimumThreshold: threshold,
                blockOnHighSeverity: true,
                maxMatches: maxResults
            )
        )

        // Check for duplicates
        let matches = try await detector.findDuplicates(
            for: title,
            in: goalsForDetection,
            threshold: threshold
        )

        // Map similar goals
        let similarGoals = matches.prefix(maxResults).map { match in
            SimilarGoal(
                id: match.entityId.uuidString,
                title: match.title,
                description: nil,  // Description not available in DuplicateMatch
                similarityScore: match.similarity,
                similarityPercentage: Int(match.similarity * 100),
                matchType: match.severity.rawValue
            )
        }

        // Determine if duplicate
        let isDuplicate = matches.first?.similarity ?? 0.0 >= threshold

        // Determine recommended action
        let recommendedAction: String
        if isDuplicate, let best = matches.first {
            recommendedAction = "High similarity (\(best.similarityPercentage)) with '\(best.title)'. Consider editing the existing goal instead."
        } else if !matches.isEmpty {
            recommendedAction = "Possible similarity detected. Review the similar goals below before creating."
        } else {
            recommendedAction = "No significant duplicates found. Safe to create new goal."
        }

        return DuplicateCheckResponse(
            isDuplicate: isDuplicate,
            similarGoals: Array(similarGoals),
            recommendedAction: recommendedAction
        )
    }

    /// Perform exact title matching
    private func performExactCheck(
        existingGoals: [GoalData],
        title: String,
        maxResults: Int
    ) -> DuplicateCheckResponse {
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let exactMatches = existingGoals.filter { goal in
            goal.title?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedTitle
        }

        if !exactMatches.isEmpty {
            let similarGoals = exactMatches.prefix(maxResults).map { goal in
                SimilarGoal(
                    id: goal.id.uuidString,
                    title: goal.title ?? "Untitled",
                    description: goal.detailedDescription,
                    similarityScore: 1.0,
                    similarityPercentage: 100,
                    matchType: "exact"
                )
            }

            return DuplicateCheckResponse(
                isDuplicate: true,
                similarGoals: Array(similarGoals),
                recommendedAction: "Exact title match found. This goal already exists."
            )
        }

        // No exact matches
        return DuplicateCheckResponse(
            isDuplicate: false,
            similarGoals: [],
            recommendedAction: "No exact matches found. Semantic checking unavailable. Proceed with caution."
        )
    }
}

// MARK: - Response Types

/// Response from duplicate checking
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct DuplicateCheckResponse: Codable {
    public let isDuplicate: Bool
    public let similarGoals: [SimilarGoal]
    public let recommendedAction: String
}

/// Information about a similar goal
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct SimilarGoal: Codable {
    public let id: String
    public let title: String
    public let description: String?
    public let similarityScore: Double
    public let similarityPercentage: Int
    public let matchType: String
}

// MARK: - Errors

fileprivate enum ToolError: LocalizedError {
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}
