//
//  GoalCoachViewModel.swift
//  ten-week-goal-app
//
//  Written by Claude Code on 2025-11-15
//
//  PURPOSE: Manage LLM conversation for goal coaching
//  PATTERN: @Observable ViewModel with LanguageModelSession
//

import Foundation
import FoundationModels
import Dependencies
import SQLiteData
import Services
import Models

/// Message in the conversation
@available(iOS 26.0, macOS 26.0, *)
public struct ChatMessage: Identifiable, Sendable {
    public let id = UUID()
    public let role: MessageRole
    public let content: String
    public let timestamp: Date

    public enum MessageRole: Sendable {
        case user
        case assistant
        case system
    }

    public init(role: MessageRole, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// ViewModel for AI goal coaching chat
@available(iOS 26.0, macOS 26.0, *)
@Observable
@MainActor
public final class GoalCoachViewModel {

    // MARK: - Observable State

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isThinking: Bool = false
    var errorMessage: String?
    var hasError: Bool { errorMessage != nil }

    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    // MARK: - LLM Session

    @ObservationIgnored
    private var llmSession: LanguageModelSession?

    // MARK: - Initialization

    public init() {}

    // MARK: - Session Management

    /// Start a new conversation session
    public func startConversation() async {
        isThinking = true
        errorMessage = nil

        print("🤖 GoalCoachViewModel: Starting conversation...")

        do {
            // Create all available tools
            let tools: [any Tool] = [
                GetGoalsTool(database: database),
                GetValuesTool(database: database),
                CreateGoalTool(database: database),
                CheckDuplicateGoalTool(database: database),
                GetMeasuresTool(database: database),
                GetRecentActionsTool(database: database),
                GetProgressTool(database: database),  // Placeholder
                AnalyzeAlignmentTool(database: database)  // Placeholder
            ]

            print("🛠️  Registered \(tools.count) tools:")
            for tool in tools {
                print("   - \(tool.name): \(tool.description)")
            }

            // System prompt for goal coaching
            let systemPrompt = """
            You are a thoughtful goal-setting coach helping users create meaningful, achievable goals.

            Your approach:
            - Ask clarifying questions to understand what truly matters to the user
            - Use the user's personal values to guide goal creation
            - Check for duplicate goals before creating new ones
            - Suggest specific, measurable targets when appropriate
            - Be encouraging but realistic

            Available tools:
            - getGoals: See the user's existing goals
            - getValues: Understand what matters most to the user
            - createGoal: Create a new goal after validation
            - checkDuplicateGoal: Check if a goal already exists
            - getMeasures: See what can be measured
            - getRecentActions: See what the user has been doing
            - getProgress: Analyze progress (placeholder)
            - analyzeAlignment: Check value alignment (placeholder)

            Start by greeting the user and asking what goal they'd like to work on.
            """

            // Log system prompt length
            let promptTokenEstimate = systemPrompt.split(separator: " ").count
            print("📝 System prompt: ~\(promptTokenEstimate) words (~\(promptTokenEstimate * 2) tokens estimated)")

            // Create LLM session
            llmSession = LanguageModelSession(
                tools: tools,
                instructions: systemPrompt
            )

            print("✅ LLM session created successfully")

            // Add welcome message
            let welcomeMessage = "👋 Hi! I'm your goal coach. I can help you create meaningful goals that align with your values. What would you like to work on today?"
            messages.append(ChatMessage(
                role: .assistant,
                content: welcomeMessage
            ))

            print("💬 Assistant: \(welcomeMessage)")

        } catch {
            errorMessage = "Failed to start conversation: \(error.localizedDescription)"
            print("❌ GoalCoachViewModel: Failed to start session: \(error)")
        }

        isThinking = false
    }

    /// Send a message to the LLM
    public func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let userMessage = inputText
        inputText = ""  // Clear input immediately

        print("\n" + String(repeating: "=", count: 80))
        print("📨 USER MESSAGE #\(messages.count + 1)")
        print(String(repeating: "=", count: 80))
        print(userMessage)
        print(String(repeating: "=", count: 80))

        // Add user message to chat
        messages.append(ChatMessage(
            role: .user,
            content: userMessage
        ))

        // Estimate current context size
        let totalMessageLength = messages.map { $0.content.count }.reduce(0, +)
        let estimatedTokens = totalMessageLength / 4  // Rough estimate: 1 token ≈ 4 chars
        print("📊 Context estimate: \(messages.count) messages, ~\(estimatedTokens) tokens")

        isThinking = true
        errorMessage = nil

        guard let session = llmSession else {
            errorMessage = "Session not started. Please restart the conversation."
            isThinking = false
            return
        }

        do {
            print("🔄 Sending to LLM...")

            // Send message to LLM
            let response = try await session.respond(to: userMessage)

            print("\n" + String(repeating: "=", count: 80))
            print("🤖 LLM RESPONSE")
            print(String(repeating: "=", count: 80))
            print("Content (\(response.content.count) chars):")

            // Show preview if content is huge
            if response.content.count > 1000 {
                let preview = String(response.content.prefix(500))
                print(preview)
                print("\n... [truncated \(response.content.count - 500) chars] ...\n")
                let ending = String(response.content.suffix(200))
                print(ending)
            } else {
                print(response.content)
            }

            // Try to log response details
            print("\nResponse type: \(type(of: response))")
            print("Mirror dump:")
            dump(response, maxDepth: 2)

            print(String(repeating: "=", count: 80) + "\n")

            // Add assistant response to chat
            messages.append(ChatMessage(
                role: .assistant,
                content: response.content
            ))

        } catch {
            errorMessage = "Failed to get response: \(error.localizedDescription)"
            print("\n" + String(repeating: "=", count: 80))
            print("❌ ERROR")
            print(String(repeating: "=", count: 80))
            print(error)
            print(String(repeating: "=", count: 80) + "\n")
        }

        isThinking = false
    }

    /// Clear conversation and restart
    public func restartConversation() async {
        messages.removeAll()
        inputText = ""
        errorMessage = nil
        llmSession = nil
        await startConversation()
    }
}
