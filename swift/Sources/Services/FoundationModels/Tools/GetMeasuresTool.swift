//
//  GetMeasuresTool.swift
//  ten-week-goal-app
//
//  Written by Claude Code on 2025-11-14
//
//  PURPOSE: LLM tool for fetching available measurement types
//  PATTERN: Foundation Models Tool protocol implementation
//

import Foundation
import FoundationModels
import Models
import SQLiteData

/// Tool for fetching available measurement types
@available(iOS 26.0, macOS 26.0, *)
public struct GetMeasuresTool: Tool {
    // MARK: - Tool Protocol Requirements

    public let name = "getMeasures"
    public let description =
        "Fetch available measurement types that can be used for tracking goals and actions"

    // MARK: - Arguments

    @Generable
    public struct Arguments: Codable, Sendable {
        @Guide(
            description: "Filter by measure type (e.g., 'duration', 'count', 'distance', 'weight')")
        let measureType: String?

        @Guide(description: "Search for measures by keyword in title")
        let searchKeyword: String?

        @Guide(description: "Maximum number of measures to return", .range(1...100))
        let limit: Int

        public init(
            measureType: String? = nil,
            searchKeyword: String? = nil,
            limit: Int = 30
        ) {
            self.measureType = measureType
            self.searchKeyword = searchKeyword
            self.limit = limit
        }
    }

    // MARK: - Dependencies

    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Tool Execution

    public func call(arguments: Arguments) async throws -> MeasuresResponse {
        // Fetch all measures directly from database
        let measures = try await database.read { db in
            var query = Measure.all

            // Apply measure type filter if provided
            if let type = arguments.measureType {
                query = query.where { $0.measureType.eq(type) }
            }

            // Apply search filter if provided
            if let keyword = arguments.searchKeyword?.lowercased() {
                // Note: SQLiteData doesn't have LIKE operator in the same way
                // We'll fetch all and filter in memory
                let allMeasures = try query.fetchAll(db)
                return allMeasures.filter { measure in
                    (measure.title?.lowercased().contains(keyword) ?? false)
                        || (measure.detailedDescription?.lowercased().contains(keyword) ?? false)
                }
            } else {
                return try query.fetchAll(db)
            }
        }

        // Apply limit
        let limitedMeasures = Array(measures.prefix(arguments.limit))

        // Map to response format
        let summaries = limitedMeasures.map { measure in
            MeasureSummary(
                id: measure.id.uuidString.lowercased(),
                title: measure.title ?? "Unnamed Measure",
                description: measure.detailedDescription,
                unit: measure.unit,
                measureType: measure.measureType,
                canonicalUnit: measure.canonicalUnit,
                conversionFactor: measure.conversionFactor
            )
        }

        return MeasuresResponse(
            measures: summaries,
            totalCount: summaries.count
        )
    }
}

// MARK: - Response Types

/// Response containing measure summaries
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct MeasuresResponse: Codable {
    @Guide(description: "List of available measurement types")
    public let measures: [MeasureSummary]

    @Guide(description: "Total number of measures returned")
    public let totalCount: Int
}

/// Summary of a measurement type
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct MeasureSummary: Codable {
    public let id: String
    public let title: String
    public let description: String?
    public let unit: String
    public let measureType: String
    public let canonicalUnit: String?
    public let conversionFactor: Double?
}
