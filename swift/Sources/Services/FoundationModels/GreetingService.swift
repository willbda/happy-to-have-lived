//
//  GreetingService.swift
//  ten-week-goal-app
//
//  Written by Claude Code on 2025-11-20
//
//  PURPOSE: Generate personalized HomeView greetings using on-device LLM
//  PATTERN: LanguageModelSession with guided generation (@Generable output)
//
//  DESIGN:
//  - Single-shot generation (no conversation state needed)
//  - Minimal context window usage (via GetGreetingContextTool)
//  - Structured output (GreetingData) guaranteed by @Generable
//  - Fast execution (async/await, parallel queries in tool)
//
//  USAGE:
//  let service = GreetingService(database: database)
//  let greeting = try await service.generateGreeting()
//

import Database
import Foundation
import FoundationModels
import GRDB

/// Service for generating personalized HomeView greetings using on-device LLM
@available(iOS 26.0, macOS 26.0, *)
@MainActor
public final class GreetingService {

    // MARK: - Dependencies

    private let database: any DatabaseWriter

    // MARK: - Initializer

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Public API

    /// Generate personalized greeting based on user's current context
    /// - Returns: GreetingData structure with 3-line greeting + optional focus suggestion
    /// - Throws: If LLM session fails or if Apple Intelligence is unavailable
    public func generateGreeting() async throws -> GreetingData {
        // Register the context tool
        let contextTool = GetGreetingContextTool(database: database)

        // Create LLM session with instructions and tools
        let session = LanguageModelSession(
            model: .default,
            tools: [contextTool],
            instructions: greetingInstructions
        )

        // Create the prompt
        let prompt = """
            Generate a personalized 3-line greeting for the user's home dashboard. \
            First, call getGreetingContext to learn about their recent activity and goals. \
            Then create a greeting that is:
            - Encouraging and motivational
            - Specific to their situation (not generic)
            - Concise (each line under 8 words)
            - Aligned with their top value if available

            Choose the greeting type based on context:
            - 'momentum': Recent high activity (5+ actions in 3 days)
            - 'values_driven': Show connection to their highest value
            - 'focus_suggestion': Suggest attention to a neglected high-priority goal
            - 'welcome_back': Low recent activity (0-1 actions in 3 days)
            - 'balanced': Default when nothing specific stands out

            If there's a neglected high-priority goal, include a FocusSuggestion.
            """

        // Use guided generation to get structured GreetingData
        // The LLM will automatically call the tool, then generate the structure
        let response = try await session.respond(
            to: prompt,
            generating: GreetingData.self
        )

        // Response<T> wraps the generated value - extract it
        return response.content
    }

    // MARK: - Instructions

    /// System instructions for greeting generation
    private var greetingInstructions: String {
        """
        You are a personal productivity coach providing encouraging, personalized greetings.

        Your role:
        - Motivate users by recognizing their efforts and progress
        - Gently redirect attention when important goals are being neglected
        - Connect daily actions to deeper personal values
        - Keep messages concise, warm, and actionable

        Style guidelines:
        - Use natural, conversational language
        - Be specific (use actual goal titles, values, and numbers)
        - Avoid clichés and generic motivational phrases
        - Balance encouragement with gentle accountability
        - Keep each line under 8 words for visual impact

        Context awareness:
        - Respect time of day (morning vs afternoon vs evening)
        - Acknowledge recent effort (or lack thereof) honestly
        - Prioritize urgent/important goals in suggestions
        - Connect actions to user's stated values when possible

        Remember: The user sees this greeting every time they open the app. \
        Make it meaningful, not repetitive.
        """
    }
}
