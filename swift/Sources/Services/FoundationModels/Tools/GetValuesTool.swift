//
//  GetValuesTool.swift
//  ten-week-goal-app
//
//  Written by Claude Code on 2025-11-14
//
//  PURPOSE: LLM tool for fetching user's personal values
//  PATTERN: Foundation Models Tool protocol implementation
//

import Foundation
import FoundationModels
import SQLiteData
import Services
import Models
import Database

/// Tool for fetching user's personal values
@available(iOS 26.0, macOS 26.0, *)
public struct GetValuesTool: Tool {
    // MARK: - Tool Protocol Requirements

    public let name = "getValues"
    public let description = "Fetch the user's personal values and life areas to understand what matters most to them"

    // MARK: - Arguments

    @Generable
    public struct Arguments: Codable {
        @Guide(description: "Filter by value level (general, major, highest_order, life_area)")
        let valueLevel: String?

        @Guide(description: "Filter by life domain (e.g., 'career', 'relationships', 'health')")
        let lifeDomain: String?

        @Guide(description: "Minimum priority level", .range(1...10))
        let minPriority: Int?

        @Guide(description: "Maximum number of values to return", .range(1...100))
        let limit: Int

        public init(
            valueLevel: String? = nil,
            lifeDomain: String? = nil,
            minPriority: Int? = nil,
            limit: Int = 20
        ) {
            self.valueLevel = valueLevel
            self.lifeDomain = lifeDomain
            self.minPriority = minPriority
            self.limit = limit
        }
    }

    // MARK: - Dependencies

    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Tool Execution

    public func call(arguments: Arguments) async throws -> ValuesResponse {
        // Create repository
        let repository = PersonalValueRepository(database: database)

        // Fetch all values
        var values = try await repository.fetchAll()

        // Apply filters
        if let level = arguments.valueLevel {
            // PersonalValueData stores valueLevel as String (not enum)
            values = values.filter { $0.valueLevel == level }
        }

        if let domain = arguments.lifeDomain {
            values = values.filter { $0.lifeDomain == domain }
        }

        if let minPriority = arguments.minPriority {
            values = values.filter { $0.priority >= minPriority }
        }

        // Sort by priority (highest first) and apply limit
        values = values
            .sorted { $0.priority > $1.priority }
            .prefix(arguments.limit)
            .map { $0 }

        // Map to response format
        let summaries = values.map { value in
            ValueSummary(
                id: value.id.uuidString,
                title: value.title,
                description: value.detailedDescription,
                priority: value.priority,
                valueLevel: value.valueLevel,  // Already a String
                lifeDomain: value.lifeDomain,
                alignmentGuidance: value.alignmentGuidance
            )
        }

        // Group by level for better organization
        var valueGroups: [ValueGroup] = []
        let grouped = Dictionary(grouping: summaries) { $0.valueLevel }
        for (level, values) in grouped {
            valueGroups.append(ValueGroup(level: level, values: values))
        }

        return ValuesResponse(
            values: summaries,
            totalCount: summaries.count,
            highestPriority: summaries.first,
            valueGroups: valueGroups
        )
    }
}

// MARK: - Response Types

/// Group of values by level
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct ValueGroup: Codable {
    public let level: String
    public let values: [ValueSummary]
}

/// Response containing personal value summaries
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct ValuesResponse: Codable {
    public let values: [ValueSummary]
    public let totalCount: Int
    public let highestPriority: ValueSummary?
    public let valueGroups: [ValueGroup]  // Changed from dictionary
}

/// Summary of a personal value
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct ValueSummary: Codable {
    public let id: String
    public let title: String
    public let description: String?
    public let priority: Int
    public let valueLevel: String
    public let lifeDomain: String?
    public let alignmentGuidance: String?
}