//
// EntityParsers.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// Convert CSV row dictionaries → canonical Data types.
//
// PATTERN:
// - One parser per entity type (parseActionData, parseGoalData, etc.)
// - Handle nested JSON (measurements, targets, alignments)
// - Handle semicolon-separated UUIDs (goals, values)
// - Use CSVParser helpers for date/UUID parsing
// - Mirror CSVFormatter's export format exactly
//

import Foundation
import Models

/// Entity-specific CSV parsers
///
/// **Pattern**: Parse [String: String] (CSV row) → canonical Data type
///
/// **Usage**:
/// ```swift
/// let csvParser = CSVParser()
/// let rows = try csvParser.parse(csvText)
/// let actions = try rows.map { try EntityParsers.parseActionData($0) }
/// ```
public enum EntityParsers {

    // MARK: - Action Parsing

    /// Parse CSV row → ActionData
    ///
    /// **CSV Format** (from CSVFormatter.formatActions):
    /// ```
    /// ID,Title,Description,Notes,LogTime,Duration(min),StartTime,Measurements,ContributingGoals
    /// ```
    ///
    /// - Measurements: JSON array of {id, measureId, title, unit, type, value, createdAt}
    /// - ContributingGoals: Semicolon-separated UUIDs
    public static func parseActionData(_ row: [String: String]) throws -> ActionData {
        // Required fields
        guard let idString = row["ID"], let id = UUID(uuidString: idString) else {
            throw ValidationError.databaseConstraint("Invalid or missing Action ID")
        }

        guard let logTimeString = row["LogTime"] else {
            throw ValidationError.missingRequiredField("LogTime is required")
        }
        let logTime = try CSVParser.parseDate(logTimeString)

        // Optional fields
        let title = row["Title"]
        let detailedDescription = row["Description"]
        let freeformNotes = row["Notes"]

        let durationMinutes: Double? = if let durationString = row["Duration(min)"], !durationString.isEmpty {
            Double(durationString)
        } else {
            nil
        }

        let startTime: Date? = try CSVParser.parseOptionalDate(row["StartTime"] ?? "")

        // Nested measurements (JSON array in CSV)
        let measurementsJson = row["Measurements"] ?? "[]"
        let measurements = try parseMeasurementsJSON(measurementsJson)

        // Contributing goals (semicolon-separated UUIDs)
        // Note: CSVFormatter exports goal IDs, not full contributions
        // We'll need to reconstruct contributions in FormDataTransformer
        let contributingGoalIds = try CSVParser.parseSemicolonUUIDs(row["ContributingGoals"] ?? "")
        let contributions = contributingGoalIds.map { goalId in
            ActionData.Contribution(
                id: UUID(),  // Generate new ID
                goalId: goalId,
                goalTitle: nil,  // Will be filled in by validator/transformer
                contributionAmount: nil,
                measureId: nil,
                createdAt: Date()  // Use current time
            )
        }

        return ActionData(
            id: id,
            title: title,
            detailedDescription: detailedDescription,
            freeformNotes: freeformNotes,
            logTime: logTime,
            durationMinutes: durationMinutes,
            startTime: startTime,
            measurements: measurements,
            contributions: contributions
        )
    }

    /// Parse measurements JSON from CSV field
    ///
    /// **JSON Format**:
    /// ```json
    /// [{"id":"uuid","measureId":"uuid","title":"Distance","unit":"miles","type":"continuous","value":5.0,"createdAt":"2025-11-16T12:00:00Z"}]
    /// ```
    private static func parseMeasurementsJSON(_ jsonString: String) throws -> [ActionData.Measurement] {
        struct MeasurementJSON: Decodable {
            let id: String
            let measureId: String
            let title: String?
            let unit: String
            let type: String
            let value: Double
            let createdAt: String
        }

        let measurements = try CSVParser.parseNestedJSON(jsonString, as: [MeasurementJSON].self)

        return try measurements.map { m in
            guard let id = UUID(uuidString: m.id),
                  let measureId = UUID(uuidString: m.measureId) else {
                throw ValidationError.databaseConstraint("Invalid UUID in measurement")
            }

            let createdAt = try CSVParser.parseDate(m.createdAt)

            return ActionData.Measurement(
                id: id,
                measureId: measureId,
                measureTitle: m.title,
                measureUnit: m.unit,
                measureType: m.type,
                value: m.value,
                createdAt: createdAt
            )
        }
    }

    // MARK: - Goal Parsing

    /// Parse CSV row → GoalData
    ///
    /// **CSV Format** (from CSVFormatter.formatGoals):
    /// ```
    /// ID,Title,Description,Notes,LogTime,Importance,Urgency,StartDate,TargetDate,ActionPlan,TermLength,MeasureTargets,AlignedValues
    /// ```
    ///
    /// - MeasureTargets: JSON array of {id, measureId, title, unit, type, targetValue, createdAt}
    /// - AlignedValues: Semicolon-separated UUIDs
    public static func parseGoalData(_ row: [String: String]) throws -> GoalData {
        // Required fields
        guard let idString = row["ID"], let id = UUID(uuidString: idString) else {
            throw ValidationError.databaseConstraint("Invalid or missing Goal ID")
        }

        guard let logTimeString = row["LogTime"] else {
            throw ValidationError.missingRequiredField("LogTime is required")
        }
        let logTime = try CSVParser.parseDate(logTimeString)

        guard let importanceString = row["Importance"], let importance = Int(importanceString) else {
            throw ValidationError.missingRequiredField("Importance is required")
        }

        guard let urgencyString = row["Urgency"], let urgency = Int(urgencyString) else {
            throw ValidationError.missingRequiredField("Urgency is required")
        }

        // Optional fields
        let title = row["Title"]
        let detailedDescription = row["Description"]
        let freeformNotes = row["Notes"]
        let actionPlan = row["ActionPlan"]

        let startDate: Date? = try CSVParser.parseOptionalDate(row["StartDate"] ?? "")
        let targetDate: Date? = try CSVParser.parseOptionalDate(row["TargetDate"] ?? "")

        let expectedTermLength: Int? = if let termString = row["TermLength"], !termString.isEmpty {
            Int(termString)
        } else {
            nil
        }

        // Nested measure targets (JSON array)
        let targetsJson = row["MeasureTargets"] ?? "[]"
        let measureTargets = try parseMeasureTargetsJSON(targetsJson)

        // Aligned values (semicolon-separated UUIDs)
        let alignedValueIds = try CSVParser.parseSemicolonUUIDs(row["AlignedValues"] ?? "")
        let valueAlignments = alignedValueIds.map { valueId in
            GoalData.ValueAlignment(
                id: UUID(),  // Generate new ID
                valueId: valueId,
                valueTitle: "",  // Empty string (will be filled by validator/transformer)
                alignmentStrength: nil,
                relevanceNotes: nil,
                createdAt: Date()
            )
        }

        return GoalData(
            id: id,
            startDate: startDate,
            targetDate: targetDate,
            actionPlan: actionPlan,
            expectedTermLength: expectedTermLength,
            expectationId: UUID(),  // Generate new expectation ID
            title: title,
            detailedDescription: detailedDescription,
            freeformNotes: freeformNotes,
            expectationImportance: importance,
            expectationUrgency: urgency,
            logTime: logTime,
            measureTargets: measureTargets,
            valueAlignments: valueAlignments,
            termAssignment: nil  // Not included in CSV export
        )
    }

    /// Parse measure targets JSON from CSV field
    private static func parseMeasureTargetsJSON(_ jsonString: String) throws -> [GoalData.MeasureTarget] {
        struct MeasureTargetJSON: Decodable {
            let id: String
            let measureId: String
            let title: String?
            let unit: String
            let type: String
            let targetValue: Double
            let createdAt: String
        }

        let targets = try CSVParser.parseNestedJSON(jsonString, as: [MeasureTargetJSON].self)

        return try targets.map { t in
            guard let id = UUID(uuidString: t.id),
                  let measureId = UUID(uuidString: t.measureId) else {
                throw ValidationError.databaseConstraint("Invalid UUID in measure target")
            }

            let createdAt = try CSVParser.parseDate(t.createdAt)

            return GoalData.MeasureTarget(
                id: id,
                measureId: measureId,
                measureTitle: t.title,
                measureUnit: t.unit,
                measureType: t.type,
                targetValue: t.targetValue,
                freeformNotes: nil,  // Not exported in CSV
                createdAt: createdAt
            )
        }
    }

    // MARK: - PersonalValue Parsing

    /// Parse CSV row → PersonalValueData
    ///
    /// **CSV Format** (from CSVFormatter.formatValues):
    /// ```
    /// ID,Title,Description,Notes,Priority,Value Level,Life Domain,Alignment Guidance,Log Time,Aligned Goal Count,Aligned Goal IDs
    /// ```
    ///
    /// - Aligned Goal IDs: Semicolon-separated UUIDs
    public static func parsePersonalValueData(_ row: [String: String]) throws -> PersonalValueData {
        // Required fields
        guard let idString = row["ID"], let id = UUID(uuidString: idString) else {
            throw ValidationError.databaseConstraint("Invalid or missing PersonalValue ID")
        }

        guard let title = row["Title"], !title.isEmpty else {
            throw ValidationError.missingRequiredField("Title is required")
        }

        guard let priorityString = row["Priority"], let priority = Int(priorityString) else {
            throw ValidationError.missingRequiredField("Priority is required")
        }

        guard let valueLevel = row["Value Level"] else {
            throw ValidationError.missingRequiredField("Value Level is required")
        }

        guard let logTimeString = row["Log Time"] else {
            throw ValidationError.missingRequiredField("Log Time is required")
        }
        let logTime = try CSVParser.parseDate(logTimeString)

        // Optional fields
        let detailedDescription = row["Description"]
        let freeformNotes = row["Notes"]
        let lifeDomain = row["Life Domain"]
        let alignmentGuidance = row["Alignment Guidance"]

        // Aligned goal IDs (semicolon-separated)
        let alignedGoalIds = try CSVParser.parseSemicolonUUIDs(row["Aligned Goal IDs"] ?? "")

        return PersonalValueData(
            id: id,
            title: title,
            detailedDescription: detailedDescription,
            freeformNotes: freeformNotes,
            logTime: logTime,
            priority: priority,
            valueLevel: valueLevel,
            lifeDomain: lifeDomain,
            alignmentGuidance: alignmentGuidance,
            alignedGoalIds: alignedGoalIds
        )
    }

    // MARK: - TimePeriod Parsing

    /// Parse CSV row → TimePeriodData
    ///
    /// **CSV Format** (from CSVFormatter.formatTerms):
    /// ```
    /// ID,TermNumber,Theme,Reflection,Status,PeriodID,PeriodTitle,StartDate,EndDate,AssignedGoals
    /// ```
    ///
    /// - AssignedGoals: Semicolon-separated UUIDs
    public static func parseTimePeriodData(_ row: [String: String]) throws -> TimePeriodData {
        // Required fields
        guard let idString = row["ID"], let id = UUID(uuidString: idString) else {
            throw ValidationError.databaseConstraint("Invalid or missing Term ID")
        }

        guard let termNumberString = row["TermNumber"], let termNumber = Int(termNumberString) else {
            throw ValidationError.missingRequiredField("TermNumber is required")
        }

        guard let periodIdString = row["PeriodID"], let periodId = UUID(uuidString: periodIdString) else {
            throw ValidationError.databaseConstraint("Invalid or missing Period ID")
        }

        guard let startDateString = row["StartDate"] else {
            throw ValidationError.missingRequiredField("StartDate is required")
        }
        let startDate = try CSVParser.parseDate(startDateString)

        guard let endDateString = row["EndDate"] else {
            throw ValidationError.missingRequiredField("EndDate is required")
        }
        let endDate = try CSVParser.parseDate(endDateString)

        // Optional fields
        let theme = row["Theme"]
        let reflection = row["Reflection"]
        let status = row["Status"]
        let periodTitle = row["PeriodTitle"]

        // Assigned goals (semicolon-separated)
        let assignedGoalIds = try CSVParser.parseSemicolonUUIDs(row["AssignedGoals"] ?? "")

        return TimePeriodData(
            id: id,                    // GoalTerm.id
            termNumber: termNumber,
            theme: theme,
            reflection: reflection,
            status: status,
            timePeriodId: periodId,
            timePeriodTitle: periodTitle,
            startDate: startDate,
            endDate: endDate,
            assignedGoalIds: assignedGoalIds.isEmpty ? nil : assignedGoalIds
        )
    }
}
