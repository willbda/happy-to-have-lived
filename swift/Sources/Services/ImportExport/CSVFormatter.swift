//
// CSVFormatter.swift
// Written by Claude Code on 2025-11-15
//
// PURPOSE:
// CSV encoding service for export data types.
// Converts denormalized Export structs to CSV format.
//
// PATTERN:
// - Pure formatting logic (no database access)
// - Works with Export types from repositories
// - Handles CSV escaping and structure
//

import Foundation
import Models

/// CSV formatting service for export data
///
/// USAGE:
/// ```swift
/// let formatter = CSVFormatter()
/// let actions = try await repository.fetchForExport()
/// let csvData = try formatter.formatActions(actions)
/// ```
public struct CSVFormatter {

    public init() {}

    // MARK: - Actions CSV

    /// Encode actions to CSV format
    ///
    /// **Format**: One row per action, measurements as JSON column
    public func formatActions(_ actions: [ActionData]) throws -> Data {
        var csv =
            "ID,Title,Description,Notes,LogTime,Duration(min),StartTime,Measurements,ContributingGoals\n"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        for action in actions {
            let measurementsJson = try encoder.encode(action.measurements)
            let measurementsString =
                String(data: measurementsJson, encoding: .utf8)?
                .replacingOccurrences(of: "\"", with: "\"\"") ?? ""

            let goalsString = action.contributingGoalIds
                .map { $0.uuidString }
                .joined(separator: ";")

            let row = [
                action.id.uuidString,
                escapeCSV(action.title ?? ""),
                escapeCSV(action.detailedDescription ?? ""),
                escapeCSV(action.freeformNotes ?? ""),
                ISO8601DateFormatter().string(from: action.logTime),
                action.durationMinutes.map { String($0) } ?? "",
                action.startTime.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                "\"\(measurementsString)\"",
                goalsString,
            ].joined(separator: ",")

            csv.append(row + "\n")
        }

        return csv.data(using: .utf8) ?? Data()
    }

    // MARK: - Goals CSV

    /// Encode goals to CSV format
    /// Now uses canonical GoalData type directly
    public func formatGoals(_ goals: [GoalData]) throws -> Data {
        var csv =
            "ID,Title,Description,Notes,LogTime,Importance,Urgency,StartDate,TargetDate,ActionPlan,TermLength,MeasureTargets,AlignedValues\n"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let formatter = ISO8601DateFormatter()

        for goal in goals {
            // Use GoalData's measureTargets directly
            let measuresJson = try encoder.encode(goal.measureTargets)
            let measuresString =
                String(data: measuresJson, encoding: .utf8)?
                .replacingOccurrences(of: "\"", with: "\"\"") ?? ""

            // Use GoalData's convenience accessor for value IDs
            let valuesString = goal.alignedValueIds
                .map { $0.uuidString }
                .joined(separator: ";")

            var rowComponents = [String]()
            rowComponents.append(goal.id.uuidString)
            rowComponents.append(escapeCSV(goal.title ?? ""))
            rowComponents.append(escapeCSV(goal.detailedDescription ?? ""))
            rowComponents.append(escapeCSV(goal.freeformNotes ?? ""))
            rowComponents.append(formatter.string(from: goal.logTime))
            rowComponents.append(String(goal.expectationImportance))
            rowComponents.append(String(goal.expectationUrgency))
            rowComponents.append(goal.startDate.map { formatter.string(from: $0) } ?? "")
            rowComponents.append(goal.targetDate.map { formatter.string(from: $0) } ?? "")
            rowComponents.append(escapeCSV(goal.actionPlan ?? ""))
            rowComponents.append(goal.expectedTermLength.map { String($0) } ?? "")
            rowComponents.append("\"\(measuresString)\"")
            rowComponents.append(valuesString)

            let row = rowComponents.joined(separator: ",")
            csv.append(row + "\n")
        }

        return csv.data(using: .utf8) ?? Data()
    }

    // MARK: - Values CSV

    /// Encode personal values to CSV format using canonical PersonalValueData
    ///
    /// **CANONICAL PATTERN**: Uses PersonalValueData.csvRow and PersonalValueData.csvHeader
    /// for consistent formatting across the app.
    public func formatValues(_ values: [PersonalValueData]) throws -> Data {
        // Use canonical CSV header from PersonalValueData
        var csv = PersonalValueData.csvHeader.joined(separator: ",") + "\n"

        for value in values {
            // Use canonical CSV row from PersonalValueData
            let row = value.csvRow.map { escapeCSV($0) }.joined(separator: ",")
            csv.append(row + "\n")
        }

        return csv.data(using: .utf8) ?? Data()
    }

    // MARK: - Terms CSV

    /// Encode terms to CSV format
    public func formatTerms(_ terms: [TimePeriodData]) throws -> Data {
        var csv =
            "ID,TermNumber,Theme,Reflection,Status,PeriodID,PeriodTitle,StartDate,EndDate,AssignedGoals\n"

        let formatter = ISO8601DateFormatter()

        for term in terms {
            let goalsString =
                term.assignedGoalIds?
                .map { $0.uuidString }
                .joined(separator: ";") ?? ""

            let row = [
                term.id.uuidString,
                String(term.termNumber),
                escapeCSV(term.theme ?? ""),
                escapeCSV(term.reflection ?? ""),
                escapeCSV(term.status ?? ""),
                term.timePeriodId.uuidString,
                escapeCSV(term.timePeriodTitle ?? ""),
                formatter.string(from: term.startDate),
                formatter.string(from: term.endDate),
                goalsString,
            ].joined(separator: ",")

            csv.append(row + "\n")
        }

        return csv.data(using: .utf8) ?? Data()
    }

    // MARK: - CSV Helpers

    /// Escape special characters for CSV format
    ///
    /// **Rules**:
    /// - If value contains comma, newline, or quote → wrap in quotes
    /// - Double any quotes within the value ("" for ")
    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\n") || value.contains("\"") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
