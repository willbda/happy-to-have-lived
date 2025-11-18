// SampleDataLoader.swift
// Written by Claude Code on 2025-11-10
//
// PURPOSE: Load and parse schema_validation_data.json into FormData structures
//
// ARCHITECTURE:
// - Decodable structs mirror JSON structure (with array indices for cross-references)
// - Provides helpers to map indices → UUIDs after entity creation
// - Used by SchemaValidationTests for round-trip schema validation
//
// PATTERN:
// 1. Load JSON → SampleDataSet
// 2. Create entities layer-by-layer (capture UUIDs)
// 3. Map indices to UUIDs when creating dependent entities

import Foundation
import Models
import Services

// Import TermStatus enum
import enum Models.TermStatus

/// Complete sample dataset loaded from schema_validation_data.json
public struct SampleDataSet: Decodable, Sendable {
    public let measures: [MeasureData]
    public let personalValues: [PersonalValueData]
    public let goals: [GoalData]
    public let actions: [ActionData]
    public let terms: [TermData]
    public let expectedAggregations: ExpectedAggregations

    enum CodingKeys: String, CodingKey {
        case measures
        case personalValues
        case goals
        case actions
        case terms
        case expectedAggregations
    }
}

// MARK: - Measure Data

public struct MeasureData: Decodable, Sendable {
    public let title: String
    public let unit: String
    public let measureType: String
    public let canonicalUnit: String?
    public let conversionFactor: Double?

    public let detailedDescription: String?
    public let freeformNotes: String?

    /// Convert to Measure entity (generates new UUID)
    public func toMeasure() -> Measure {
        Measure(
            unit: unit,
            measureType: measureType,
            title: title,
            detailedDescription: detailedDescription,
            freeformNotes: freeformNotes,
            canonicalUnit: canonicalUnit,
            conversionFactor: conversionFactor,
            logTime: Date(),
            id: UUID()
        )
    }
}

// MARK: - PersonalValue Data

public struct PersonalValueData: Decodable, Sendable {
    public let title: String
    public let detailedDescription: String?
    public let freeformNotes: String?
    public let valueLevel: String
    public let priority: Int?
    public let lifeDomain: String?
    public let alignmentGuidance: String?

    /// Convert to PersonalValueFormData for coordinator
    public func toFormData() -> PersonalValueFormData {
        // Parse valueLevel string to enum
        let level = ValueLevel(rawValue: valueLevel) ?? .general

        return PersonalValueFormData(
            title: title,
            detailedDescription: detailedDescription ?? "",
            freeformNotes: freeformNotes ?? "",
            valueLevel: level,
            priority: priority ?? 50,
            lifeDomain: lifeDomain,
            alignmentGuidance: alignmentGuidance
        )
    }
}

// MARK: - Goal Data

public struct GoalData: Decodable, Sendable {
    public let title: String?
    public let detailedDescription: String?
    public let freeformNotes: String?
    public let expectationImportance: Int
    public let expectationUrgency: Int
    public let startDate: String?
    public let targetDate: String?
    public let actionPlan: String?
    public let expectedTermLength: Int?
    public let measureTargets: [MetricTargetData]
    public let valueAlignments: [ValueAlignmentData]

    /// Convert to GoalFormData, mapping indices to UUIDs
    public func toFormData(
        measureIds: [UUID],
        valueIds: [UUID]
    ) -> GoalFormData {
        GoalFormData(
            title: title ?? "",
            detailedDescription: detailedDescription ?? "",
            freeformNotes: freeformNotes ?? "",
            expectationImportance: expectationImportance,
            expectationUrgency: expectationUrgency,
            startDate: startDate.flatMap { ISO8601DateFormatter().date(from: $0) },
            targetDate: targetDate.flatMap { ISO8601DateFormatter().date(from: $0) },
            actionPlan: actionPlan,
            expectedTermLength: expectedTermLength,
            measureTargets: measureTargets.map { target in
                ExpectationMeasureFormData(
                    measureId: measureIds[target.measureIndex],
                    targetValue: target.targetValue,
                    notes: target.notes
                )
            },
            valueAlignments: valueAlignments.map { alignment in
                ValueAlignmentInput(
                    valueId: valueIds[alignment.valueIndex],
                    alignmentStrength: alignment.alignmentStrength ?? 5,
                    relevanceNotes: alignment.relevanceNotes
                )
            }
        )
    }
}

public struct MetricTargetData: Decodable, Sendable {
    public let measureIndex: Int
    public let targetValue: Double
    public let notes: String?
}

public struct ValueAlignmentData: Decodable, Sendable {
    public let valueIndex: Int
    public let alignmentStrength: Int?
    public let relevanceNotes: String?
}

// MARK: - Action Data

public struct ActionData: Decodable, Sendable {
    public let title: String?
    public let detailedDescription: String?
    public let freeformNotes: String?
    public let durationMinutes: Double?
    public let startTime: String
    public let measurements: [MeasurementData]
    public let goalIndices: [Int]

    /// Convert to ActionFormData, mapping indices to UUIDs
    public func toFormData(
        measureIds: [UUID],
        goalIds: [UUID]
    ) -> ActionFormData {
        let iso8601 = ISO8601DateFormatter()
        let parsedStartTime = iso8601.date(from: startTime) ?? Date()

        return ActionFormData(
            title: title ?? "",
            detailedDescription: detailedDescription ?? "",
            freeformNotes: freeformNotes ?? "",
            durationMinutes: durationMinutes ?? 0,
            startTime: parsedStartTime,
            measurements: measurements.map { measurement in
                MeasurementInput(
                    measureId: measureIds[measurement.measureIndex],
                    value: measurement.value
                )
            },
            goalContributions: Set(goalIndices.map { goalIds[$0] })
        )
    }
}

public struct MeasurementData: Decodable, Sendable {
    public let measureIndex: Int
    public let value: Double
}

// MARK: - Term Data

public struct TermData: Decodable, Sendable {
    public let title: String?
    public let detailedDescription: String?
    public let freeformNotes: String?
    public let startDate: String
    public let targetDate: String  // JSON uses "targetDate" not "endDate"
    public let specialization: TermSpecializationData?
    public let goalIndices: [Int]?

    /// Convert to TimePeriodFormData for creating the underlying TimePeriod
    public func toTimePeriodFormData() -> TimePeriodFormData {
        let iso8601 = ISO8601DateFormatter()
        let start = iso8601.date(from: startDate) ?? Date()
        let end = iso8601.date(from: targetDate) ?? Date()

        return TimePeriodFormData(
            title: title ?? "",
            detailedDescription: detailedDescription ?? "",
            freeformNotes: freeformNotes ?? "",
            startDate: start,
            targetDate: end,
            specialization: .term(number: termNumber),
            theme: title,
            reflection: nil,
            status: .planned
        )
    }

    /// Get term number for creating GoalTerm
    public var termNumber: Int {
        specialization?.termNumber ?? 1
    }
}

public struct TermSpecializationData: Decodable, Sendable {
    public let termNumber: Int  // JSON uses "termNumber" not "term"

    enum CodingKeys: String, CodingKey {
        case termNumber
    }
}

// MARK: - Expected Aggregations

public struct ExpectedAggregations: Decodable, Sendable {
    public let totalKilometers: Double
    public let totalRunningKilometers: Double
    public let totalStudyHours: Double
    public let totalSavings: Double
    public let totalMeditationMinutes: Double
    public let totalMeditationSessions: Int
    public let actionsCount: Int
    public let actionsWithMeasurements: Int
    public let actionsContributingToGoals: Int
    public let strengthTrainingSessions: Int
    public let familyCallsCount: Int
    public let goalsByImportanceHigh: Int
    public let goalsAlignedToPhysicalHealth: Int
    public let goalsAlignedToProfessionalGrowth: Int
}

// MARK: - Loader

public enum SampleDataLoader {

    /// Load schema_validation_data.json from bundle
    public static func load() throws -> SampleDataSet {
        // For Xcode test target, use Bundle(for:) to find test bundle
        // Note: Bundle.module only works for SPM, not Xcode test targets
        let bundle = Bundle(for: BundleToken.self)

        guard let url = bundle.url(
            forResource: "schema_validation_data",
            withExtension: "json"
        ) else {
            throw SampleDataError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(SampleDataSet.self, from: data)
    }

    /// Token class for Bundle.init(for:) - must be in same module as test bundle
    private class BundleToken {}

    enum SampleDataError: Error {
        case fileNotFound
    }
}
