//
//  ConversationRepository.swift
//  ten-week-goal-app
//
//  Written by Claude Code on 2025-11-14
//
//  PURPOSE: Repository for managing LLM conversation persistence
//  PATTERN: Standard repository pattern for conversation and message storage
//
//  RESPONSIBILITIES:
//  - CRUD operations for llmConversations and llmMessages tables
//  - Session management for context window overflow
//  - Conversation archival and retrieval
//  - Message history management
//

import Foundation
import GRDB  // For Row type in raw SQL queries
import SQLiteData

/// Repository for managing LLM conversation data
/// Handles both conversation headers and individual messages
public final class ConversationRepository: Sendable {
    // MARK: - Properties

    private let database: any DatabaseWriter

    // MARK: - Initialization

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Conversation Management

    /// Create a new conversation
    public func createConversation(
        userId: String = "default",
        conversationType: ConversationType
    ) async throws -> ConversationHeader {
        let now = Date()
        let conversationId = UUID()

        try await database.write { db in
            let sql = """
                    INSERT INTO llmConversations (
                        id, userId, conversationType, startedAt, lastMessageAt,
                        sessionNumber, status, logTime
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """

            try db.execute(
                sql: sql,
                arguments: [
                    conversationId.uuidString,
                    userId,
                    conversationType.rawValue,
                    now.ISO8601Format(),
                    now.ISO8601Format(),
                    1,
                    "active",
                    now.ISO8601Format(),
                ]
            )
        }

        return ConversationHeader(
            id: conversationId,
            userId: userId,
            conversationType: conversationType,
            startedAt: now,
            lastMessageAt: now,
            sessionNumber: 1,
            status: .active
        )
    }

    /// Fetch a conversation by ID
    public func fetchConversation(_ id: UUID) async throws -> ConversationHeader? {
        try await database.read { db in
            let sql = """
                    SELECT id, userId, conversationType, startedAt, lastMessageAt,
                           sessionNumber, status, logTime
                    FROM llmConversations
                    WHERE id = ?
                """

            guard let row = try Row.fetchOne(db, sql: sql, arguments: [id.uuidString.lowercased()])
            else {
                return nil
            }

            return try mapRowToConversation(row)
        }
    }

    /// Fetch all active conversations for a user
    public func fetchActiveConversations(
        userId: String = "default",
        conversationType: ConversationType? = nil
    ) async throws -> [ConversationHeader] {
        try await database.read { db in
            var sql = """
                    SELECT id, userId, conversationType, startedAt, lastMessageAt,
                           sessionNumber, status, logTime
                    FROM llmConversations
                    WHERE userId = ? AND status = 'active'
                """

            var arguments: [DatabaseValueConvertible] = [userId]

            if let type = conversationType {
                sql += " AND conversationType = ?"
                arguments.append(type.rawValue)
            }

            sql += " ORDER BY lastMessageAt DESC"

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return try rows.compactMap { try mapRowToConversation($0) }
        }
    }

    /// Archive a conversation
    public func archiveConversation(_ id: UUID) async throws {
        try await database.write { db in
            let sql = """
                    UPDATE llmConversations
                    SET status = 'archived'
                    WHERE id = ?
                """
            try db.execute(sql: sql, arguments: [id.uuidString.lowercased()])
        }
    }

    /// Update the last message timestamp
    public func updateLastMessageTime(_ conversationId: UUID) async throws {
        let now = Date()
        try await database.write { db in
            let sql = """
                    UPDATE llmConversations
                    SET lastMessageAt = ?
                    WHERE id = ?
                """
            try db.execute(sql: sql, arguments: [now.ISO8601Format(), conversationId.uuidString])
        }
    }

    /// Increment session number (for context window management)
    public func incrementSessionNumber(_ conversationId: UUID) async throws -> Int {
        try await database.write { db in
            // Get current session number
            let fetchSql = """
                    SELECT sessionNumber FROM llmConversations WHERE id = ?
                """
            let currentSession =
                try Int.fetchOne(
                    db,
                    sql: fetchSql,
                    arguments: [conversationId.uuidString]
                ) ?? 1

            let newSession = currentSession + 1

            // Update session number
            let updateSql = """
                    UPDATE llmConversations
                    SET sessionNumber = ?
                    WHERE id = ?
                """
            try db.execute(
                sql: updateSql,
                arguments: [newSession, conversationId.uuidString]
            )

            return newSession
        }
    }

    // MARK: - Message Management

    /// Add a message to a conversation
    public func addMessage(
        conversationId: UUID,
        role: MessageRole,
        content: String,
        toolName: String? = nil,
        structuredData: String? = nil,
        sessionNumber: Int = 1
    ) async throws -> ConversationMessage {
        let messageId = UUID()
        let now = Date()

        try await database.write { db in
            let sql = """
                    INSERT INTO llmMessages (
                        id, conversationId, role, content, structuredDataJSON,
                        toolName, timestamp, sessionNumber, isArchived
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """

            try db.execute(
                sql: sql,
                arguments: [
                    messageId.uuidString,
                    conversationId.uuidString,
                    role.rawValue,
                    content,
                    structuredData,
                    toolName,
                    now.ISO8601Format(),
                    sessionNumber,
                    0,
                ]
            )
        }

        // Update conversation's last message time
        try await updateLastMessageTime(conversationId)

        return ConversationMessage(
            id: messageId,
            conversationId: conversationId,
            role: role,
            content: content,
            structuredDataJSON: structuredData,
            toolName: toolName,
            timestamp: now,
            sessionNumber: sessionNumber,
            isArchived: false
        )
    }

    /// Fetch active messages for a conversation
    public func fetchActiveMessages(_ conversationId: UUID) async throws -> [ConversationMessage] {
        try await database.read { db in
            let sql = """
                    SELECT id, conversationId, role, content, structuredDataJSON,
                           toolName, timestamp, sessionNumber, isArchived
                    FROM llmMessages
                    WHERE conversationId = ? AND isArchived = 0
                    ORDER BY timestamp ASC
                """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [conversationId.uuidString])
            return try rows.compactMap { try mapRowToMessage($0) }
        }
    }

    /// Fetch messages for a specific session
    public func fetchSessionMessages(
        conversationId: UUID,
        sessionNumber: Int
    ) async throws -> [ConversationMessage] {
        try await database.read { db in
            let sql = """
                    SELECT id, conversationId, role, content, structuredDataJSON,
                           toolName, timestamp, sessionNumber, isArchived
                    FROM llmMessages
                    WHERE conversationId = ? AND sessionNumber = ?
                    ORDER BY timestamp ASC
                """

            let rows = try Row.fetchAll(
                db,
                sql: sql,
                arguments: [conversationId.uuidString, sessionNumber]
            )
            return try rows.compactMap { try mapRowToMessage($0) }
        }
    }

    /// Archive old messages (for context window management)
    public func archiveMessagesBeforeSession(
        conversationId: UUID,
        sessionNumber: Int
    ) async throws -> Int {
        try await database.write { db in
            let sql = """
                    UPDATE llmMessages
                    SET isArchived = 1
                    WHERE conversationId = ? AND sessionNumber < ?
                """

            let statement = try db.makeStatement(sql: sql)
            try statement.setArguments([conversationId.uuidString, sessionNumber])
            try statement.execute()

            return db.changesCount
        }
    }

    /// Count messages in a conversation
    public func countMessages(
        conversationId: UUID,
        archived: Bool? = nil
    ) async throws -> Int {
        try await database.read { db in
            var sql = """
                    SELECT COUNT(*) FROM llmMessages
                    WHERE conversationId = ?
                """

            var arguments: [DatabaseValueConvertible] = [conversationId.uuidString]

            if let archived = archived {
                sql += " AND isArchived = ?"
                arguments.append(archived ? 1 : 0)
            }

            return try Int.fetchOne(db, sql: sql, arguments: StatementArguments(arguments)) ?? 0
        }
    }

    /// Generate a summary of archived messages for context preservation
    public func generateConversationSummary(_ conversationId: UUID) async throws -> String? {
        let messages = try await fetchActiveMessages(conversationId)

        guard !messages.isEmpty else { return nil }

        // Build a summary of the conversation
        var summary = "Previous conversation summary:\n"

        for message in messages.prefix(10) {  // Summarize first 10 messages
            switch message.role {
            case .user:
                summary += "User: \(message.content.prefix(100))...\n"
            case .assistant:
                summary += "Assistant: \(message.content.prefix(100))...\n"
            case .toolCall:
                summary += "Tool called: \(message.toolName ?? "unknown")\n"
            case .toolResponse:
                summary += "Tool response received\n"
            case .system:
                summary += "System: \(message.content.prefix(100))...\n"
            }
        }

        return summary
    }

    // MARK: - Cleanup Operations

    /// Delete old archived conversations
    public func deleteArchivedConversationsOlderThan(_ date: Date) async throws -> Int {
        try await database.write { db in
            let sql = """
                    DELETE FROM llmConversations
                    WHERE status = 'archived' AND lastMessageAt < ?
                """

            let statement = try db.makeStatement(sql: sql)
            try statement.setArguments([date.ISO8601Format()])
            try statement.execute()

            return db.changesCount
        }
    }

    /// Get conversation statistics
    public func getStatistics(userId: String = "default") async throws -> ConversationStatistics {
        try await database.read { db in
            // Count by type and status
            let sql = """
                    SELECT
                        conversationType,
                        status,
                        COUNT(*) as count,
                        MAX(lastMessageAt) as lastActivity
                    FROM llmConversations
                    WHERE userId = ?
                    GROUP BY conversationType, status
                """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [userId])

            var totalConversations = 0
            var activeConversations = 0
            var byType: [String: Int] = [:]
            var lastActivity: Date?

            for row in rows {
                let count = (row["count"] as? Int) ?? 0
                let type = (row["conversationType"] as? String) ?? ""
                let status = (row["status"] as? String) ?? ""

                totalConversations += count

                if status == "active" {
                    activeConversations += count
                }

                byType[type, default: 0] += count

                if let lastActivityStr = row["lastActivity"] as? String,
                    let date = ISO8601DateFormatter().date(from: lastActivityStr)
                {
                    if lastActivity == nil || date > lastActivity! {
                        lastActivity = date
                    }
                }
            }

            // Count total messages
            let messageSql = """
                    SELECT COUNT(*) FROM llmMessages
                    WHERE conversationId IN (
                        SELECT id FROM llmConversations WHERE userId = ?
                    )
                """
            let totalMessages =
                try Int.fetchOne(
                    db,
                    sql: messageSql,
                    arguments: [userId]
                ) ?? 0

            return ConversationStatistics(
                totalConversations: totalConversations,
                activeConversations: activeConversations,
                totalMessages: totalMessages,
                conversationsByType: byType,
                lastActivity: lastActivity
            )
        }
    }

    // MARK: - Private Helpers

    private func mapRowToConversation(_ row: Row) throws -> ConversationHeader? {
        guard let idString = row["id"] as? String,
            let id = UUID(uuidString: idString),
            let userId = row["userId"] as? String,
            let typeString = row["conversationType"] as? String,
            let conversationType = ConversationType(rawValue: typeString),
            let startedAtString = row["startedAt"] as? String,
            let startedAt = ISO8601DateFormatter().date(from: startedAtString),
            let lastMessageAtString = row["lastMessageAt"] as? String,
            let lastMessageAt = ISO8601DateFormatter().date(from: lastMessageAtString),
            let sessionNumber = row["sessionNumber"] as? Int,
            let statusString = row["status"] as? String,
            let status = ConversationStatus(rawValue: statusString)
        else {
            return nil
        }

        return ConversationHeader(
            id: id,
            userId: userId,
            conversationType: conversationType,
            startedAt: startedAt,
            lastMessageAt: lastMessageAt,
            sessionNumber: sessionNumber,
            status: status
        )
    }

    private func mapRowToMessage(_ row: Row) throws -> ConversationMessage? {
        guard let idString = row["id"] as? String,
            let id = UUID(uuidString: idString),
            let conversationIdString = row["conversationId"] as? String,
            let conversationId = UUID(uuidString: conversationIdString),
            let roleString = row["role"] as? String,
            let role = MessageRole(rawValue: roleString),
            let content = row["content"] as? String,
            let timestampString = row["timestamp"] as? String,
            let timestamp = ISO8601DateFormatter().date(from: timestampString),
            let sessionNumber = row["sessionNumber"] as? Int,
            let isArchived = row["isArchived"] as? Int
        else {
            return nil
        }

        return ConversationMessage(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            structuredDataJSON: row["structuredDataJSON"] as? String,
            toolName: row["toolName"] as? String,
            timestamp: timestamp,
            sessionNumber: sessionNumber,
            isArchived: isArchived != 0
        )
    }
}

// MARK: - Supporting Types

/// Types of conversations
public enum ConversationType: String, Sendable, CaseIterable {
    case goalSetting = "goal_setting"
    case reflection = "reflection"
    case valuesAlignment = "values_alignment"
    case general = "general"
}

/// Conversation status
public enum ConversationStatus: String, Sendable {
    case active = "active"
    case archived = "archived"
    case deleted = "deleted"
}

/// Message roles in conversation
public enum MessageRole: String, Sendable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    case toolCall = "tool_call"
    case toolResponse = "tool_response"
}

/// Conversation header information
public struct ConversationHeader: Sendable, Identifiable {
    public let id: UUID
    public let userId: String
    public let conversationType: ConversationType
    public let startedAt: Date
    public let lastMessageAt: Date
    public let sessionNumber: Int
    public let status: ConversationStatus
}

/// Individual message in a conversation
public struct ConversationMessage: Sendable, Identifiable {
    public let id: UUID
    public let conversationId: UUID
    public let role: MessageRole
    public let content: String
    public let structuredDataJSON: String?
    public let toolName: String?
    public let timestamp: Date
    public let sessionNumber: Int
    public let isArchived: Bool
}

/// Statistics about conversations
public struct ConversationStatistics: Sendable {
    public let totalConversations: Int
    public let activeConversations: Int
    public let totalMessages: Int
    public let conversationsByType: [String: Int]
    public let lastActivity: Date?
}
