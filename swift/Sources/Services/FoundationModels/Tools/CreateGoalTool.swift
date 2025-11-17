//
//  CreateGoalTool.swift
//  ten-week-goal-app
//
//  Written by Claude Code on 2025-11-14
//
//  PURPOSE: LLM tool for creating new goals through conversation
//  PATTERN: Foundation Models Tool protocol implementation
//

import Foundation
import FoundationModels
import SQLiteData
import Models
import Services
import Dependencies

/// Tool for creating new goals with validation and deduplication
@available(iOS 26.0, macOS 26.0, *)
public struct CreateGoalTool: Tool {
    // MARK: - Tool Protocol Requirements

    public let name = "createGoal"
    public let description = "Create a new goal after validating it doesn't duplicate existing goals"

    // MARK: - Arguments

    @Generable
    public struct Arguments: Codable {
        @Guide(description: "Goal title (required)")
        let title: String

        @Guide(description: "Detailed description of what success looks like")
        let description: String?

        @Guide(description: "Action plan with specific steps")
        let actionPlan: String?

        @Guide(description: "Start date in ISO8601 format (YYYY-MM-DD)")
        let startDate: String?

        @Guide(description: "Target completion date in ISO8601 format (YYYY-MM-DD)")
        let targetDate: String?

        @Guide(description: "Importance level", .range(1...10))
        let importance: Int

        @Guide(description: "Urgency level", .range(1...10))
        let urgency: Int

        @Guide(description: "Array of metric targets with measureId and targetValue")
        let metricTargets: [LLMMetricTargetInput]?

        @Guide(description: "Array of value alignments with valueId and strength")
        let valueAlignments: [LLMValueAlignmentInput]?

        @Guide(description: "Term ID to assign this goal to")
        let termId: String?

        @Guide(description: "Check for duplicates before creating (recommended)")
        let checkDuplicates: Bool

        public init(
            title: String,
            description: String? = nil,
            actionPlan: String? = nil,
            startDate: String? = nil,
            targetDate: String? = nil,
            importance: Int = 5,
            urgency: Int = 5,
            metricTargets: [LLMMetricTargetInput]? = nil,
            valueAlignments: [LLMValueAlignmentInput]? = nil,
            termId: String? = nil,
            checkDuplicates: Bool = true
        ) {
            self.title = title
            self.description = description
            self.actionPlan = actionPlan
            self.startDate = startDate
            self.targetDate = targetDate
            self.importance = importance
            self.urgency = urgency
            self.metricTargets = metricTargets
            self.valueAlignments = valueAlignments
            self.termId = termId
            self.checkDuplicates = checkDuplicates
        }
    }

    // MARK: - Dependencies

    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Tool Execution

    public func call(arguments: Arguments) async throws -> CreateGoalResponse {
        // Validate required fields
        guard !arguments.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolError.invalidInput("Goal title is required")
        }

        // Parse dates if provided
        let parsedStartDate = arguments.startDate.flatMap { ISO8601DateFormatter().date(from: $0) }
        let parsedTargetDate = arguments.targetDate.flatMap { ISO8601DateFormatter().date(from: $0) }

        // Validate date range
        if let start = parsedStartDate, let target = parsedTargetDate {
            guard start <= target else {
                throw ToolError.invalidInput("Start date must be before target date")
            }
        }

        // Check for duplicates if requested
        if arguments.checkDuplicates {
            let duplicateCheck = try await checkForDuplicates(
                title: arguments.title,
                description: arguments.description
            )
            if duplicateCheck.isDuplicate {
                return CreateGoalResponse(
                    success: false,
                    goalId: nil,
                    message: duplicateCheck.message ?? "A similar goal already exists",
                    duplicateFound: true,
                    similarGoalId: duplicateCheck.similarGoalId
                )
            }
        }

        // Convert inputs to form data
        let formData = GoalFormData(
            title: arguments.title,
            detailedDescription: arguments.description ?? "",
            freeformNotes: "",
            expectationImportance: arguments.importance,
            expectationUrgency: arguments.urgency,
            startDate: parsedStartDate,
            targetDate: parsedTargetDate,
            actionPlan: arguments.actionPlan,
            expectedTermLength: nil,
            metricTargets: convertMetricTargets(arguments.metricTargets ?? []),
            valueAlignments: convertValueAlignments(arguments.valueAlignments ?? []),
            termId: arguments.termId.flatMap { UUID(uuidString: $0) }
        )

        // Create goal using coordinator
        let coordinator = GoalCoordinator(database: database)

        do {
            let goal = try await coordinator.create(from: formData)

            return CreateGoalResponse(
                success: true,
                goalId: goal.id.uuidString,
                message: "Goal '\(arguments.title)' created successfully",
                duplicateFound: false,
                similarGoalId: nil
            )
        } catch let error as ValidationError {
            // Convert validation errors to user-friendly messages
            return CreateGoalResponse(
                success: false,
                goalId: nil,
                message: error.userMessage,
                duplicateFound: false,
                similarGoalId: nil
            )
        } catch {
            throw ToolError.executionFailed("Failed to create goal: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    /// Check for duplicate goals
    private func checkForDuplicates(
        title: String,
        description: String?
    ) async throws -> DuplicateCheckResult {
        // Fetch existing goals (canonical GoalData)
        let repository = GoalRepository_v3(database: database)
        let existingGoals = try await repository.fetchAll()

        // Try semantic checking first
        let semanticService = SemanticService(database: database, configuration: .default)

        // Convert GoalData to GoalWithExpectation for detector
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

        do {
            // Use semantic similarity checking
            let detector = SemanticGoalDetector(
                semanticService: semanticService,
                config: .goals
            )

            let matches = try await detector.findDuplicates(
                for: title,
                in: goalsForDetection,
                threshold: nil  // Use default from config
            )

            if let bestMatch = matches.first {
                return DuplicateCheckResult(
                    isDuplicate: true,
                    message: "Similar goal already exists: \(bestMatch.title)",
                    similarGoalId: bestMatch.entityId.uuidString
                )
            }

            return DuplicateCheckResult(isDuplicate: false, message: nil, similarGoalId: nil)
        } catch {
            // Fall back to exact title matching if semantic check fails
            let exactMatch = existingGoals.first { goal in
                goal.title?.lowercased() == title.lowercased()
            }

            if let match = exactMatch {
                return DuplicateCheckResult(
                    isDuplicate: true,
                    message: "A goal with this exact title already exists",
                    similarGoalId: match.id.uuidString
                )
            }

            return DuplicateCheckResult(isDuplicate: false, message: nil, similarGoalId: nil)
        }
    }

    /// Convert metric target inputs from LLM (String IDs) to form data (UUID)
    private func convertMetricTargets(_ inputs: [LLMMetricTargetInput]) -> [Services.MetricTargetInput] {
        inputs.compactMap { input in
            guard let measureId = UUID(uuidString: input.measureId) else { return nil }
            return Services.MetricTargetInput(
                measureId: measureId,
                targetValue: input.targetValue,
                notes: input.notes
            )
        }
    }

    /// Convert value alignment inputs from LLM (String IDs) to form data (UUID)
    private func convertValueAlignments(_ inputs: [LLMValueAlignmentInput]) -> [Services.ValueAlignmentInput] {
        inputs.compactMap { input in
            guard let valueId = UUID(uuidString: input.valueId) else { return nil }
            return Services.ValueAlignmentInput(
                valueId: valueId,
                alignmentStrength: input.alignmentStrength ?? 5,
                relevanceNotes: input.notes
            )
        }
    }
}

// MARK: - Input Types

/// Input for metric targets (LLM-generated, uses String IDs)
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct LLMMetricTargetInput: Codable {
    public let measureId: String
    public let targetValue: Double
    public let notes: String?
}

/// Input for value alignments (LLM-generated, uses String IDs)
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct LLMValueAlignmentInput: Codable {
    public let valueId: String
    public let alignmentStrength: Int?
    public let notes: String?
}

// MARK: - Response Types

/// Response from goal creation
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct CreateGoalResponse: Codable {
    public let success: Bool
    public let goalId: String?
    public let message: String
    public let duplicateFound: Bool
    public let similarGoalId: String?
}

/// Result from duplicate checking
private struct DuplicateCheckResult {
    let isDuplicate: Bool
    let message: String?
    let similarGoalId: String?
}

// MARK: - Errors

fileprivate enum ToolError: LocalizedError {
    case invalidInput(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        }
    }
}
