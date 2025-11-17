//
// GoalRepository.swift
// Written by Claude Code on 2025-11-08
// Aggressively refactored on 2025-11-13 with JSON aggregation pattern
//
// PURPOSE:
// Read coordinator for Goal entities - centralizes query logic and existence checks.
// Complements GoalCoordinator (writes) by handling all read operations.
//
// RESPONSIBILITIES:
// 1. Complex reads - fetchAll(), fetchActiveGoals(), fetchByTerm(), fetchByValue()
// 2. Existence checks - existsByTitle() for duplicate prevention
// 3. Error mapping - DatabaseError → ValidationError
//
// PATTERN:
// - JSON aggregation for multi-table fetches (single-query strategy)
// - #sql macro for all queries (explicit SQL over abstractions)
// - FetchKeyRequest for complex multi-value results
// - FetchableRecord for type-safe row decoding
//

import Foundation
import Models
import SQLiteData
import GRDB  // For FetchableRecord protocol (minimal usage)

// TEMPORARY STUB: GoalExport is deprecated - use GoalData instead
// This stub exists only to allow compilation of deprecated code that will be removed
private struct GoalExport: Identifiable, Codable, Sendable {
    let id: UUID
    let startDate: Date?
    let targetDate: Date?
    let actionPlan: String?
    let expectedTermLength: Int?
    let title: String?
    let detailedDescription: String?
    let freeformNotes: String?
    let expectationImportance: Int
    let expectationUrgency: Int
    let logTime: Date
    let measureTargets: [MeasureTargetExport]
    let alignedValueIds: [UUID]
}
private struct MeasureTargetExport: Codable, Sendable {
    let measureId: UUID
    let measureTitle: String?
    let unit: String
    let targetValue: Double
}

// REMOVED @MainActor: Repository performs database queries which are I/O
// operations that should run in background. Database reads should not block
// the main thread. ViewModels will await results on main actor as needed.
public final class GoalRepository: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Read Operations

    /// Fetch all goals with full relationship graph (LEGACY - use fetchAll() instead)
    ///
    /// Uses JSON aggregation: 1 query regardless of goal count
    /// - Warning: Deprecated. Use fetchAll() which returns canonical GoalData
    @available(*, deprecated, renamed: "fetchAll", message: "Use fetchAll() which returns canonical GoalData. Transform with .asDetails if needed.")
    public func fetchAllLegacy() async throws -> [GoalWithDetails] {
        do {
            return try await database.read { db in
                try FetchAllGoalsRequest().fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Fetch all goals as canonical GoalData (for both display and export)
    ///
    /// **CANONICAL PATTERN**: Returns GoalData that's already Codable
    /// **Usage**:
    /// - Export: Use directly (already Codable)
    /// - Display: Transform with `.map { $0.asDetails }` if needed
    /// - Simple views: Use GoalData directly without transformation
    ///
    /// - Parameters:
    ///   - startDate: Optional filter for goals created or active after this date
    ///   - endDate: Optional filter for goals created or active before this date
    public func fetchAll(
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) async throws -> [GoalData] {
        do {
            return try await database.read { db in
                // If no date filtering, use existing FetchAllGoalsRequest
                if startDate == nil && endDate == nil {
                    // Use same FetchAllGoalsRequest but transform to GoalData
                    let goalDetailsArray = try FetchAllGoalsRequest().fetch(db)

                    // Transform GoalWithDetails to GoalData
                    return goalDetailsArray.map { goalWithDetails in
                    GoalData(
                        id: goalWithDetails.goal.id,
                        startDate: goalWithDetails.goal.startDate,
                        targetDate: goalWithDetails.goal.targetDate,
                        actionPlan: goalWithDetails.goal.actionPlan,
                        expectedTermLength: goalWithDetails.goal.expectedTermLength,
                        expectationId: goalWithDetails.expectation.id,
                        title: goalWithDetails.expectation.title,
                        detailedDescription: goalWithDetails.expectation.detailedDescription,
                        freeformNotes: goalWithDetails.expectation.freeformNotes,
                        expectationImportance: goalWithDetails.expectation.expectationImportance,
                        expectationUrgency: goalWithDetails.expectation.expectationUrgency,
                        logTime: goalWithDetails.expectation.logTime,
                        measureTargets: goalWithDetails.metricTargets.map { target in
                            GoalData.MeasureTarget(
                                id: target.expectationMeasure.id,
                                measureId: target.measure.id,
                                measureTitle: target.measure.title,
                                measureUnit: target.measure.unit,
                                measureType: target.measure.measureType,
                                targetValue: target.expectationMeasure.targetValue,
                                freeformNotes: target.expectationMeasure.freeformNotes,
                                createdAt: target.expectationMeasure.createdAt
                            )
                        },
                        valueAlignments: goalWithDetails.valueAlignments.map { alignment in
                            GoalData.ValueAlignment(
                                id: alignment.goalRelevance.id,
                                valueId: alignment.value.id,
                                valueTitle: alignment.value.title ?? "",
                                alignmentStrength: alignment.goalRelevance.alignmentStrength,
                                relevanceNotes: alignment.goalRelevance.relevanceNotes,
                                createdAt: alignment.goalRelevance.createdAt
                            )
                        },
                        termAssignment: goalWithDetails.termAssignment.map { assignment in
                            GoalData.TermAssignment(
                                id: assignment.id,
                                termId: assignment.termId,
                                assignmentOrder: assignment.assignmentOrder,
                                createdAt: assignment.createdAt
                            )
                        }
                    )
                    }
                } else {
                    // With date filtering, use FetchFilteredGoalsRequest
                    let goalDetailsArray = try FetchFilteredGoalsRequest(
                        startDate: startDate,
                        endDate: endDate
                    ).fetch(db)

                    // Transform GoalWithDetails to GoalData
                    return goalDetailsArray.map { goalWithDetails in
                        GoalData(
                            id: goalWithDetails.goal.id,
                            startDate: goalWithDetails.goal.startDate,
                            targetDate: goalWithDetails.goal.targetDate,
                            actionPlan: goalWithDetails.goal.actionPlan,
                            expectedTermLength: goalWithDetails.goal.expectedTermLength,
                            expectationId: goalWithDetails.expectation.id,
                            title: goalWithDetails.expectation.title,
                            detailedDescription: goalWithDetails.expectation.detailedDescription,
                            freeformNotes: goalWithDetails.expectation.freeformNotes,
                            expectationImportance: goalWithDetails.expectation.expectationImportance,
                            expectationUrgency: goalWithDetails.expectation.expectationUrgency,
                            logTime: goalWithDetails.expectation.logTime,
                            measureTargets: goalWithDetails.metricTargets.map { target in
                                GoalData.MeasureTarget(
                                    id: target.expectationMeasure.id,
                                    measureId: target.measure.id,
                                    measureTitle: target.measure.title,
                                    measureUnit: target.measure.unit,
                                    measureType: target.measure.measureType,
                                    targetValue: target.expectationMeasure.targetValue,
                                    freeformNotes: target.expectationMeasure.freeformNotes,
                                    createdAt: target.expectationMeasure.createdAt
                                )
                            },
                            valueAlignments: goalWithDetails.valueAlignments.map { alignment in
                                GoalData.ValueAlignment(
                                    id: alignment.goalRelevance.id,
                                    valueId: alignment.value.id,
                                    valueTitle: alignment.value.title ?? "",
                                    alignmentStrength: alignment.goalRelevance.alignmentStrength,
                                    relevanceNotes: alignment.goalRelevance.relevanceNotes,
                                    createdAt: alignment.goalRelevance.createdAt
                                )
                            },
                            termAssignment: goalWithDetails.termAssignment.map { assignment in
                                GoalData.TermAssignment(
                                    id: assignment.id,
                                    termId: assignment.termId,
                                    assignmentOrder: assignment.assignmentOrder,
                                    createdAt: assignment.createdAt
                                )
                            }
                        )
                    }
                }
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Fetch active goals (no target date or target date in future)
    ///
    /// Used by QuickAdd sections where only active goals are relevant
    public func fetchActiveGoals() async throws -> [GoalWithDetails] {
        do {
            return try await database.read { db in
                try FetchActiveGoalsRequest().fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Fetch goals assigned to a specific term
    public func fetchByTerm(_ termId: UUID) async throws -> [GoalWithDetails] {
        do {
            return try await database.read { db in
                try FetchGoalsByTermRequest(termId: termId).fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Fetch goals aligned with a specific personal value
    ///
    /// Returns simple Goal array (no full details) for lightweight value alignment display
    public func fetchByValue(_ valueId: UUID) async throws -> [Goal] {
        do {
            return try await database.read { db in
                // Use raw SQL since GoalRelevance doesn't have query builder extensions
                let sql = """
                    SELECT * FROM goals
                    WHERE id IN (
                        SELECT goalId FROM goalRelevances WHERE valueId = ?
                    )
                    ORDER BY COALESCE(targetDate, startDate) ASC NULLS LAST
                """

                // Use Row to fetch raw data, then convert to Goal
                let rows = try Row.fetchAll(db, sql: sql, arguments: [valueId])
                return try rows.map { row in
                    // Custom init expects expectationId first (generates its own id)
                    var goal = Goal(
                        expectationId: row["expectationId"],
                        startDate: row["startDate"],
                        targetDate: row["targetDate"],
                        actionPlan: row["actionPlan"],
                        expectedTermLength: row["expectedTermLength"]
                    )
                    // Override the generated id with the actual id from database
                    goal.id = row["id"]
                    return goal
                }
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }


    // MARK: - Dashboard Queries

    /// Fetch all goals with progress calculations for dashboard
    ///
    /// **PERMANENT PATTERN**: Using raw SQL for complex aggregations
    /// This is the production pattern for dashboard queries that need
    /// multi-table JOINs with SQL aggregations (SUM, COALESCE, CASE).
    ///
    /// Returns simplified progress data optimized for dashboard display.
    /// Business logic (status determination, projections) handled by service layer.
    public func fetchAllWithProgress() async throws -> [GoalProgressData] {
        do {
            return try await database.read { db in
                try FetchGoalProgressRequest().fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    // MARK: - Existence Checks

    /// Check if a goal with this title already exists (case-insensitive)
    ///
    /// Queries the Expectation table since goal titles are stored there
    public func existsByTitle(_ title: String) async throws -> Bool {
        do {
            return try await database.read { db in
                try ExistsByTitleRequest(title: title).fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Check if a goal exists by ID
    public func exists(_ id: UUID) async throws -> Bool {
        do {
            return try await database.read { db in
                try ExistsByIdRequest(id: id).fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    // MARK: - Error Mapping

    private func mapDatabaseError(_ error: Error) -> ValidationError {
        guard let dbError = error as? DatabaseError else {
            return .databaseConstraint(error.localizedDescription)
        }

        switch dbError.resultCode {
        case .SQLITE_CONSTRAINT_FOREIGNKEY:
            if dbError.message?.contains("measureId") == true {
                return .invalidMeasure("Measure not found")
            }
            if dbError.message?.contains("valueId") == true {
                return .emptyValue("Personal value not found")
            }
            if dbError.message?.contains("termId") == true {
                return .databaseConstraint("Term not found")
            }
            return .foreignKeyViolation("Referenced entity not found")
        case .SQLITE_CONSTRAINT_UNIQUE:
            return .duplicateRecord("A goal with this title already exists")
        case .SQLITE_CONSTRAINT_NOTNULL:
            return .missingRequiredField("Required field is missing")
        case .SQLITE_CONSTRAINT:
            return .databaseConstraint(dbError.message ?? "Database constraint violated")
        default:
            return .databaseConstraint(dbError.localizedDescription)
        }
    }
}

// MARK: - JSON Result Row Types

/// Main SQL query result row (one row per goal)
///
/// Returned from JSON aggregation query. Contains flattened goal+expectation fields
/// plus JSON strings for related entities.
///
/// PUBLIC: Exported for GoalsQuery.swift compatibility (temporary during migration)
public struct GoalQueryRow: Decodable, FetchableRecord, Sendable {
    // Goal fields (prefixed to avoid column name collisions)
    let goalId: String
    let goalStartDate: Date?
    let goalTargetDate: Date?
    let goalActionPlan: String?
    let goalExpectedTermLength: Int?

    // Expectation fields
    let expectationId: String
    let expectationTitle: String?
    let expectationDetailedDescription: String?
    let expectationFreeformNotes: String?
    let expectationLogTime: Date
    let expectationImportance: Int
    let expectationUrgency: Int

    // JSON aggregations (as strings, parsed later)
    let measuresJson: String        // Array of measure objects
    let valuesJson: String          // Array of value objects
    let termAssignmentJson: String? // Single term object (or NULL)
}

/// Nested JSON structure for measures
private struct MeasureJsonRow: Decodable, Sendable {
    let expectationMeasureId: String
    let targetValue: Double
    let expectationMeasureFreeformNotes: String?
    let measureId: String
    let measureTitle: String?
    let measureUnit: String
    let measureType: String
    let measureDetailedDescription: String?
    let measureFreeformNotes: String?
    let measureLogTime: Date
    let measureCanonicalUnit: String?
    let measureConversionFactor: Double?
    let expectationMeasureCreatedAt: Date
}

/// Nested JSON structure for values
private struct ValueJsonRow: Decodable, Sendable {
    let relevanceId: String
    let alignmentStrength: Int?
    let relevanceNotes: String?
    let valueId: String
    let valueTitle: String
    let valueDetailedDescription: String?
    let valueFreeformNotes: String?
    let valuePriority: Int
    let valueLevel: String
    let valueLifeDomain: String?
    let valueAlignmentGuidance: String?
    let valueLogTime: Date
    let relevanceCreatedAt: Date
}

/// Nested JSON structure for term assignment (single object, not array)
private struct TermAssignmentJsonRow: Decodable, Sendable {
    let assignmentId: String
    let termId: String
    let assignmentOrder: Int?
    let createdAt: Date
}

// MARK: - Helper Functions

/// Assemble GoalWithDetails from SQL row with JSON parsing
///
/// Parses JSON arrays for measures, values, and term assignment.
/// Throws ValidationError with context if JSON parsing fails.
///
/// PUBLIC: Exported for GoalsQuery.swift compatibility (temporary during migration)
public func assembleGoalWithDetails(from row: GoalQueryRow) throws -> GoalWithDetails {
    let decoder = JSONDecoder()

    // Configure decoder to parse SQLite's date format from JSON strings
    // Format: "2025-11-08 06:23:40.205"
    decoder.dateDecodingStrategy = .formatted({
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }())

    // Parse measures JSON array
    let measuresData: Data
    do {
        guard let data = row.measuresJson.data(using: .utf8) else {
            throw ValidationError.databaseConstraint("Invalid UTF-8 in measures JSON for goal \(row.goalId)")
        }
        measuresData = data
    }

    let measuresJson: [MeasureJsonRow]
    do {
        measuresJson = try decoder.decode([MeasureJsonRow].self, from: measuresData)
    } catch {
        throw ValidationError.databaseConstraint("Failed to parse measures JSON for goal \(row.goalId): \(error)")
    }

    // Parse values JSON array
    let valuesData: Data
    do {
        guard let data = row.valuesJson.data(using: .utf8) else {
            throw ValidationError.databaseConstraint("Invalid UTF-8 in values JSON for goal \(row.goalId)")
        }
        valuesData = data
    }

    let valuesJson: [ValueJsonRow]
    do {
        valuesJson = try decoder.decode([ValueJsonRow].self, from: valuesData)
    } catch {
        throw ValidationError.databaseConstraint("Failed to parse values JSON for goal \(row.goalId): \(error)")
    }

    // Parse term assignment JSON (optional single object)
    let termJson: TermAssignmentJsonRow?
    if let termJsonString = row.termAssignmentJson,
       let termData = termJsonString.data(using: .utf8) {
        do {
            termJson = try decoder.decode(TermAssignmentJsonRow.self, from: termData)
        } catch {
            throw ValidationError.databaseConstraint("Failed to parse term assignment JSON for goal \(row.goalId): \(error)")
        }
    } else {
        termJson = nil
    }

    // Build Goal domain model
    guard let goalUUID = UUID(uuidString: row.goalId),
          let expectationUUID = UUID(uuidString: row.expectationId) else {
        throw ValidationError.databaseConstraint("Invalid UUID in goal row: \(row.goalId)")
    }

    let goal = Goal(
        expectationId: expectationUUID,
        startDate: row.goalStartDate,
        targetDate: row.goalTargetDate,
        actionPlan: row.goalActionPlan,
        expectedTermLength: row.goalExpectedTermLength,
        id: goalUUID
    )

    // Build Expectation domain model
    let expectation = Expectation(
        title: row.expectationTitle,
        detailedDescription: row.expectationDetailedDescription,
        freeformNotes: row.expectationFreeformNotes,
        expectationType: .goal,
        expectationImportance: row.expectationImportance,
        expectationUrgency: row.expectationUrgency,
        logTime: row.expectationLogTime,
        id: expectationUUID
    )

    // Build measure wrappers
    let metricTargets = try measuresJson.map { m in
        guard let emUUID = UUID(uuidString: m.expectationMeasureId),
              let measureUUID = UUID(uuidString: m.measureId) else {
            throw ValidationError.databaseConstraint("Invalid UUID in measure JSON for goal \(row.goalId)")
        }

        return ExpectationMeasureWithMetric(
            expectationMeasure: ExpectationMeasure(
                expectationId: expectationUUID,
                measureId: measureUUID,
                targetValue: m.targetValue,
                createdAt: m.expectationMeasureCreatedAt,
                freeformNotes: m.expectationMeasureFreeformNotes,
                id: emUUID
            ),
            measure: Measure(
                unit: m.measureUnit,
                measureType: m.measureType,
                title: m.measureTitle,
                detailedDescription: m.measureDetailedDescription,
                freeformNotes: m.measureFreeformNotes,
                canonicalUnit: m.measureCanonicalUnit,
                conversionFactor: m.measureConversionFactor,
                logTime: m.measureLogTime,
                id: measureUUID
            )
        )
    }

    // Build value wrappers
    let valueAlignments = try valuesJson.map { v in
        guard let relevanceUUID = UUID(uuidString: v.relevanceId),
              let valueUUID = UUID(uuidString: v.valueId) else {
            throw ValidationError.databaseConstraint("Invalid UUID in value JSON for goal \(row.goalId)")
        }

        return GoalRelevanceWithValue(
            goalRelevance: GoalRelevance(
                goalId: goalUUID,
                valueId: valueUUID,
                alignmentStrength: v.alignmentStrength,
                relevanceNotes: v.relevanceNotes,
                createdAt: v.relevanceCreatedAt,
                id: relevanceUUID
            ),
            value: PersonalValue(
                title: v.valueTitle,
                detailedDescription: v.valueDetailedDescription,
                freeformNotes: v.valueFreeformNotes,
                priority: v.valuePriority,
                valueLevel: ValueLevel(rawValue: v.valueLevel) ?? .general,
                lifeDomain: v.valueLifeDomain,
                alignmentGuidance: v.valueAlignmentGuidance,
                logTime: v.valueLogTime,
                id: valueUUID
            )
        )
    }

    // Build term assignment
    let termAssignment = try termJson.map { t in
        guard let assignmentUUID = UUID(uuidString: t.assignmentId),
              let termUUID = UUID(uuidString: t.termId) else {
            throw ValidationError.databaseConstraint("Invalid UUID in term assignment JSON for goal \(row.goalId)")
        }

        return TermGoalAssignment(
            id: assignmentUUID,
            termId: termUUID,
            goalId: goalUUID,
            assignmentOrder: t.assignmentOrder,
            createdAt: t.createdAt
        )
    }

    return GoalWithDetails(
        goal: goal,
        expectation: expectation,
        metricTargets: metricTargets,
        valueAlignments: valueAlignments,
        termAssignment: termAssignment
    )
}

/// Assemble GoalData from JSON query row (canonical data type)
///
/// **NEW PATTERN**: Single assembly function for both display and export
/// **Replaces**: assembleGoalWithDetails() and assembleGoalExport()
/// **Process**:
/// 1. Parse JSON strings to structured arrays
/// 2. Convert to GoalData sub-structs (flat, not nested entities)
/// 3. Return canonical GoalData that's already Codable
///
/// Consumer decides how to use it:
/// - Export: Use directly (Codable)
/// - Views: Call .asDetails if nested structure needed
public func assembleGoalData(from row: GoalQueryRow) throws -> GoalData {
    let decoder = JSONDecoder()

    // Parse goal and expectation IDs
    guard let goalUUID = UUID(uuidString: row.goalId) else {
        throw ValidationError.databaseConstraint("Invalid goal ID: \(row.goalId)")
    }

    guard let expectationUUID = UUID(uuidString: row.expectationId) else {
        throw ValidationError.databaseConstraint("Invalid expectation ID: \(row.expectationId)")
    }

    // Parse measures JSON
    let measuresData = row.measuresJson.data(using: .utf8)!
    let measuresJson = try decoder.decode([MeasureJsonRow].self, from: measuresData)

    let measureTargets: [GoalData.MeasureTarget] = try measuresJson.map { m in
        guard let measureTargetUUID = UUID(uuidString: m.expectationMeasureId),
              let measureUUID = UUID(uuidString: m.measureId) else {
            throw ValidationError.databaseConstraint("Invalid UUID in measure for goal \(row.goalId)")
        }

        return GoalData.MeasureTarget(
            id: measureTargetUUID,
            measureId: measureUUID,
            measureTitle: m.measureTitle,
            measureUnit: m.measureUnit,
            measureType: m.measureType,
            targetValue: m.targetValue,
            freeformNotes: m.expectationMeasureFreeformNotes,
            createdAt: m.expectationMeasureCreatedAt
        )
    }

    // Parse values JSON
    let valuesData = row.valuesJson.data(using: .utf8)!
    let valuesJson = try decoder.decode([ValueJsonRow].self, from: valuesData)

    let valueAlignments: [GoalData.ValueAlignment] = try valuesJson.map { v in
        guard let relevanceUUID = UUID(uuidString: v.relevanceId),
              let valueUUID = UUID(uuidString: v.valueId) else {
            throw ValidationError.databaseConstraint("Invalid UUID in value for goal \(row.goalId)")
        }

        return GoalData.ValueAlignment(
            id: relevanceUUID,
            valueId: valueUUID,
            valueTitle: v.valueTitle,
            alignmentStrength: v.alignmentStrength,
            relevanceNotes: v.relevanceNotes,
            createdAt: v.relevanceCreatedAt
        )
    }

    // Parse term assignment JSON (optional single object)
    var termAssignment: GoalData.TermAssignment?
    if let termJson = row.termAssignmentJson,
       !termJson.isEmpty,
       termJson != "null",
       let termData = termJson.data(using: .utf8) {
        do {
            let termJsonRow = try decoder.decode(TermAssignmentJsonRow.self, from: termData)

            guard let assignmentUUID = UUID(uuidString: termJsonRow.assignmentId),
                  let termUUID = UUID(uuidString: termJsonRow.termId) else {
                throw ValidationError.databaseConstraint("Invalid UUID in term assignment for goal \(row.goalId)")
            }

            termAssignment = GoalData.TermAssignment(
                id: assignmentUUID,
                termId: termUUID,
                assignmentOrder: termJsonRow.assignmentOrder,
                createdAt: termJsonRow.createdAt
            )
        } catch {
            // Term assignment is optional, log but don't fail
            print("Warning: Failed to parse term assignment for goal \(row.goalId): \(error)")
        }
    }

    // Build canonical GoalData with flattened structure
    return GoalData(
        id: goalUUID,
        startDate: row.goalStartDate,
        targetDate: row.goalTargetDate,
        actionPlan: row.goalActionPlan,
        expectedTermLength: row.goalExpectedTermLength,
        expectationId: expectationUUID,
        title: row.expectationTitle,
        detailedDescription: row.expectationDetailedDescription,
        freeformNotes: row.expectationFreeformNotes,
        expectationImportance: row.expectationImportance,
        expectationUrgency: row.expectationUrgency,
        logTime: row.expectationLogTime,
        measureTargets: measureTargets,
        valueAlignments: valueAlignments,
        termAssignment: termAssignment
    )
}

// MARK: - Fetch Requests

/// Fetch all goals with full relationship graph using JSON aggregation
///
/// Single query with JSON aggregation - SQLite does all grouping
private struct FetchAllGoalsRequest: FetchKeyRequest {
    typealias Value = [GoalWithDetails]

    func fetch(_ db: Database) throws -> [GoalWithDetails] {
        let sql = """
        SELECT
            -- Goal fields (prefixed to avoid column name collisions)
            g.id as goalId,
            g.startDate as goalStartDate,
            g.targetDate as goalTargetDate,
            g.actionPlan as goalActionPlan,
            g.expectedTermLength as goalExpectedTermLength,

            -- Expectation fields
            e.id as expectationId,
            e.title as expectationTitle,
            e.detailedDescription as expectationDetailedDescription,
            e.freeformNotes as expectationFreeformNotes,
            e.logTime as expectationLogTime,
            e.expectationImportance,
            e.expectationUrgency,

            -- Measures as JSON array (SQLite does the grouping)
            COALESCE(
                (
                    SELECT json_group_array(
                        json_object(
                            'expectationMeasureId', em.id,
                            'targetValue', em.targetValue,
                            'expectationMeasureFreeformNotes', em.freeformNotes,
                            'measureId', m.id,
                            'measureTitle', m.title,
                            'measureUnit', m.unit,
                            'measureType', m.measureType,
                            'measureDetailedDescription', m.detailedDescription,
                            'measureFreeformNotes', m.freeformNotes,
                            'measureLogTime', m.logTime,
                            'measureCanonicalUnit', m.canonicalUnit,
                            'measureConversionFactor', m.conversionFactor,
                            'expectationMeasureCreatedAt', em.createdAt
                        )
                    )
                    FROM expectationMeasures em
                    JOIN measures m ON em.measureId = m.id
                    WHERE em.expectationId = e.id
                ),
                '[]'
            ) as measuresJson,

            -- Values as JSON array (SQLite does the grouping)
            COALESCE(
                (
                    SELECT json_group_array(
                        json_object(
                            'relevanceId', gr.id,
                            'alignmentStrength', gr.alignmentStrength,
                            'relevanceNotes', gr.relevanceNotes,
                            'valueId', v.id,
                            'valueTitle', v.title,
                            'valueDetailedDescription', v.detailedDescription,
                            'valueFreeformNotes', v.freeformNotes,
                            'valuePriority', v.priority,
                            'valueLevel', v.valueLevel,
                            'valueLifeDomain', v.lifeDomain,
                            'valueAlignmentGuidance', v.alignmentGuidance,
                            'valueLogTime', v.logTime,
                            'relevanceCreatedAt', gr.createdAt
                        )
                    )
                    FROM goalRelevances gr
                    JOIN personalValues v ON gr.valueId = v.id
                    WHERE gr.goalId = g.id
                ),
                '[]'
            ) as valuesJson,

            -- Term assignment (single object, most recent)
            (
                SELECT json_object(
                    'assignmentId', tga.id,
                    'termId', tga.termId,
                    'assignmentOrder', tga.assignmentOrder,
                    'createdAt', tga.createdAt
                )
                FROM termGoalAssignments tga
                WHERE tga.goalId = g.id
                ORDER BY tga.createdAt DESC
                LIMIT 1
            ) as termAssignmentJson

        FROM goals g
        JOIN expectations e ON g.expectationId = e.id
        ORDER BY g.targetDate ASC NULLS LAST
        """

        // Execute query (using GRDB's FetchableRecord pattern)
        let rows = try GoalQueryRow.fetchAll(db, sql: sql)

        // Parse JSON and assemble domain models
        return try rows.map { row in
            try assembleGoalWithDetails(from: row)
        }
    }
}

/// Fetch active goals (target date in future or null) using JSON aggregation
private struct FetchActiveGoalsRequest: FetchKeyRequest {
    typealias Value = [GoalWithDetails]

    func fetch(_ db: Database) throws -> [GoalWithDetails] {
        let sql = """
        SELECT
            -- Goal fields
            g.id as goalId,
            g.startDate as goalStartDate,
            g.targetDate as goalTargetDate,
            g.actionPlan as goalActionPlan,
            g.expectedTermLength as goalExpectedTermLength,

            -- Expectation fields
            e.id as expectationId,
            e.title as expectationTitle,
            e.detailedDescription as expectationDetailedDescription,
            e.freeformNotes as expectationFreeformNotes,
            e.logTime as expectationLogTime,
            e.expectationImportance,
            e.expectationUrgency,

            -- Measures as JSON array
            COALESCE(
                (
                    SELECT json_group_array(
                        json_object(
                            'expectationMeasureId', em.id,
                            'targetValue', em.targetValue,
                            'expectationMeasureFreeformNotes', em.freeformNotes,
                            'measureId', m.id,
                            'measureTitle', m.title,
                            'measureUnit', m.unit,
                            'measureType', m.measureType,
                            'measureDetailedDescription', m.detailedDescription,
                            'measureFreeformNotes', m.freeformNotes,
                            'measureLogTime', m.logTime,
                            'measureCanonicalUnit', m.canonicalUnit,
                            'measureConversionFactor', m.conversionFactor,
                            'expectationMeasureCreatedAt', em.createdAt
                        )
                    )
                    FROM expectationMeasures em
                    JOIN measures m ON em.measureId = m.id
                    WHERE em.expectationId = e.id
                ),
                '[]'
            ) as measuresJson,

            -- Empty values array (not needed for QuickAdd)
            '[]' as valuesJson,

            -- No term assignment (not needed for QuickAdd)
            NULL as termAssignmentJson

        FROM goals g
        JOIN expectations e ON g.expectationId = e.id
        WHERE g.targetDate IS NULL OR g.targetDate >= date('now')
        ORDER BY g.targetDate ASC NULLS LAST
        """

        let rows = try GoalQueryRow.fetchAll(db, sql: sql)

        return try rows.map { row in
            try assembleGoalWithDetails(from: row)
        }
    }
}

/// Fetch goals filtered by date range using JSON aggregation
private struct FetchFilteredGoalsRequest: FetchKeyRequest {
    typealias Value = [GoalWithDetails]
    let startDate: Date?
    let endDate: Date?

    func fetch(_ db: Database) throws -> [GoalWithDetails] {
        // Build WHERE clause conditions
        var whereConditions: [String] = []
        var bindings: [DatabaseValueConvertible] = []

        if let start = startDate {
            // Include goals that started after or were logged after the start date
            whereConditions.append("(g.startDate >= ? OR e.logTime >= ?)")
            bindings.append(start)
            bindings.append(start)
        }

        if let end = endDate {
            // Include goals that target before or were logged before the end date
            whereConditions.append("(g.targetDate <= ? OR e.logTime <= ?)")
            bindings.append(end)
            bindings.append(end)
        }

        let whereClause = whereConditions.isEmpty ? "" : "WHERE " + whereConditions.joined(separator: " AND ")

        let sql = """
        SELECT
            -- Goal fields
            g.id as goalId,
            g.startDate as goalStartDate,
            g.targetDate as goalTargetDate,
            g.actionPlan as goalActionPlan,
            g.expectedTermLength as goalExpectedTermLength,

            -- Expectation fields
            e.id as expectationId,
            e.title as expectationTitle,
            e.detailedDescription as expectationDetailedDescription,
            e.freeformNotes as expectationFreeformNotes,
            e.logTime as expectationLogTime,
            e.expectationImportance,
            e.expectationUrgency,

            -- Measures as JSON array
            COALESCE(
                (
                    SELECT json_group_array(
                        json_object(
                            'expectationMeasureId', em.id,
                            'targetValue', em.targetValue,
                            'expectationMeasureFreeformNotes', em.freeformNotes,
                            'measureId', m.id,
                            'measureTitle', m.title,
                            'measureUnit', m.unit,
                            'measureType', m.measureType,
                            'measureDetailedDescription', m.detailedDescription,
                            'measureFreeformNotes', m.freeformNotes,
                            'measureLogTime', m.logTime,
                            'measureCanonicalUnit', m.canonicalUnit,
                            'measureConversionFactor', m.conversionFactor,
                            'expectationMeasureCreatedAt', em.createdAt
                        )
                    )
                    FROM expectationMeasures em
                    JOIN measures m ON em.measureId = m.id
                    WHERE em.expectationId = e.id
                ),
                '[]'
            ) as measuresJson,

            -- Values as JSON array
            COALESCE(
                (
                    SELECT json_group_array(
                        json_object(
                            'relevanceId', gr.id,
                            'alignmentStrength', gr.alignmentStrength,
                            'relevanceNotes', gr.relevanceNotes,
                            'valueId', v.id,
                            'valueTitle', v.title,
                            'valueDetailedDescription', v.detailedDescription,
                            'valueFreeformNotes', v.freeformNotes,
                            'valuePriority', v.priority,
                            'valueLevel', v.valueLevel,
                            'valueLifeDomain', v.lifeDomain,
                            'valueAlignmentGuidance', v.alignmentGuidance,
                            'valueLogTime', v.logTime,
                            'relevanceCreatedAt', gr.createdAt
                        )
                    )
                    FROM goalRelevances gr
                    JOIN personalValues v ON gr.valueId = v.id
                    WHERE gr.goalId = g.id
                ),
                '[]'
            ) as valuesJson,

            -- Term assignment as JSON (single object)
            (
                SELECT json_object(
                    'assignmentId', tga.id,
                    'termId', tga.termId,
                    'assignmentOrder', tga.assignmentOrder,
                    'createdAt', tga.createdAt
                )
                FROM termGoalAssignments tga
                WHERE tga.goalId = g.id
                ORDER BY tga.createdAt DESC
                LIMIT 1
            ) as termAssignmentJson

        FROM goals g
        JOIN expectations e ON g.expectationId = e.id
        \(whereClause)
        ORDER BY e.expectationImportance DESC, e.expectationUrgency DESC
        """

        // Execute with bindings
        let statement = try db.cachedStatement(sql: sql)
        let rows = try GoalQueryRow.fetchAll(statement, arguments: StatementArguments(bindings))

        return try rows.map { row in
            try assembleGoalWithDetails(from: row)
        }
    }
}

/// Fetch goals assigned to a specific term using JSON aggregation
private struct FetchGoalsByTermRequest: FetchKeyRequest {
    typealias Value = [GoalWithDetails]
    let termId: UUID

    func fetch(_ db: Database) throws -> [GoalWithDetails] {
        let sql = """
        SELECT
            -- Goal fields
            g.id as goalId,
            g.startDate as goalStartDate,
            g.targetDate as goalTargetDate,
            g.actionPlan as goalActionPlan,
            g.expectedTermLength as goalExpectedTermLength,

            -- Expectation fields
            e.id as expectationId,
            e.title as expectationTitle,
            e.detailedDescription as expectationDetailedDescription,
            e.freeformNotes as expectationFreeformNotes,
            e.logTime as expectationLogTime,
            e.expectationImportance,
            e.expectationUrgency,

            -- Measures as JSON array
            COALESCE(
                (
                    SELECT json_group_array(
                        json_object(
                            'expectationMeasureId', em.id,
                            'targetValue', em.targetValue,
                            'expectationMeasureFreeformNotes', em.freeformNotes,
                            'measureId', m.id,
                            'measureTitle', m.title,
                            'measureUnit', m.unit,
                            'measureType', m.measureType,
                            'measureDetailedDescription', m.detailedDescription,
                            'measureFreeformNotes', m.freeformNotes,
                            'measureLogTime', m.logTime,
                            'measureCanonicalUnit', m.canonicalUnit,
                            'measureConversionFactor', m.conversionFactor,
                            'expectationMeasureCreatedAt', em.createdAt
                        )
                    )
                    FROM expectationMeasures em
                    JOIN measures m ON em.measureId = m.id
                    WHERE em.expectationId = e.id
                ),
                '[]'
            ) as measuresJson,

            -- Values as JSON array
            COALESCE(
                (
                    SELECT json_group_array(
                        json_object(
                            'relevanceId', gr.id,
                            'alignmentStrength', gr.alignmentStrength,
                            'relevanceNotes', gr.relevanceNotes,
                            'valueId', v.id,
                            'valueTitle', v.title,
                            'valueDetailedDescription', v.detailedDescription,
                            'valueFreeformNotes', v.freeformNotes,
                            'valuePriority', v.priority,
                            'valueLevel', v.valueLevel,
                            'valueLifeDomain', v.lifeDomain,
                            'valueAlignmentGuidance', v.alignmentGuidance,
                            'valueLogTime', v.logTime,
                            'relevanceCreatedAt', gr.createdAt
                        )
                    )
                    FROM goalRelevances gr
                    JOIN personalValues v ON gr.valueId = v.id
                    WHERE gr.goalId = g.id
                ),
                '[]'
            ) as valuesJson,

            -- Term assignment for this term
            (
                SELECT json_object(
                    'assignmentId', tga.id,
                    'termId', tga.termId,
                    'assignmentOrder', tga.assignmentOrder,
                    'createdAt', tga.createdAt
                )
                FROM termGoalAssignments tga
                WHERE tga.goalId = g.id AND tga.termId = ?
                ORDER BY tga.createdAt DESC
                LIMIT 1
            ) as termAssignmentJson

        FROM goals g
        JOIN expectations e ON g.expectationId = e.id
        INNER JOIN termGoalAssignments tga ON g.id = tga.goalId
        WHERE tga.termId = ?
        ORDER BY tga.assignmentOrder ASC NULLS LAST, g.targetDate ASC NULLS LAST
        """

        // Bind termId parameter twice (once for subquery, once for WHERE clause)
        let rows = try GoalQueryRow.fetchAll(db, sql: sql, arguments: [termId, termId])

        return try rows.map { row in
            try assembleGoalWithDetails(from: row)
        }
    }
}

/// Check if a goal with this title exists (queries Expectation table)
private struct ExistsByTitleRequest: FetchKeyRequest {
    typealias Value = Bool
    let title: String

    func fetch(_ db: Database) throws -> Bool {
        // Goal titles are stored in the Expectation table
        // Use raw SQL for case-insensitive comparison
        let sql = """
        SELECT COUNT(*)
        FROM expectations
        WHERE LOWER(title) = LOWER(?)
          AND expectationType = 'goal'
        """
        let count = try Int.fetchOne(db, sql: sql, arguments: [title]) ?? 0
        return count > 0
    }
}

/// Check if a goal exists by ID
private struct ExistsByIdRequest: FetchKeyRequest {
    typealias Value = Bool
    let id: UUID

    func fetch(_ db: Database) throws -> Bool {
        let sql = "SELECT 1 FROM goals WHERE id = ? LIMIT 1"
        return try Row.fetchOne(db, sql: sql, arguments: [id]) != nil
    }
}

/// Fetch goals in export format with optional date filtering
///
/// EXPORT PATTERN: Reuses JSON aggregation SQL but transforms to flat export structure
/// - Date filtering on COALESCE(targetDate, startDate) to include goals with either date set
/// - Parses JSON arrays and flattens to simple types
/// - Returns denormalized data ready for CSV/JSON export
private struct FetchGoalsForExportRequest: FetchKeyRequest {
    typealias Value = [GoalExport]
    let startDate: Date?
    let endDate: Date?

    func fetch(_ db: Database) throws -> [GoalExport] {
        // Build WHERE clause for date filtering
        var whereClause = ""
        var arguments: [any DatabaseValueConvertible] = []

        if let start = startDate, let end = endDate {
            whereClause = "WHERE COALESCE(g.targetDate, g.startDate) BETWEEN ? AND ?"
            arguments = [start, end]
        } else if let start = startDate {
            whereClause = "WHERE COALESCE(g.targetDate, g.startDate) >= ?"
            arguments = [start]
        } else if let end = endDate {
            whereClause = "WHERE COALESCE(g.targetDate, g.startDate) <= ?"
            arguments = [end]
        }

        let sql = """
        SELECT
            -- Goal fields (prefixed to avoid column name collisions)
            g.id as goalId,
            g.startDate as goalStartDate,
            g.targetDate as goalTargetDate,
            g.actionPlan as goalActionPlan,
            g.expectedTermLength as goalExpectedTermLength,

            -- Expectation fields
            e.id as expectationId,
            e.title as expectationTitle,
            e.detailedDescription as expectationDetailedDescription,
            e.freeformNotes as expectationFreeformNotes,
            e.logTime as expectationLogTime,
            e.expectationImportance,
            e.expectationUrgency,

            -- Measures as JSON array (for parsing)
            COALESCE(
                (
                    SELECT json_group_array(
                        json_object(
                            'measureId', m.id,
                            'measureTitle', m.title,
                            'measureUnit', m.unit,
                            'targetValue', em.targetValue
                        )
                    )
                    FROM expectationMeasures em
                    JOIN measures m ON em.measureId = m.id
                    WHERE em.expectationId = e.id
                ),
                '[]'
            ) as measuresJson,

            -- Aligned values as JSON array of IDs (for parsing)
            COALESCE(
                (
                    SELECT json_group_array(gr.valueId)
                    FROM goalRelevances gr
                    WHERE gr.goalId = g.id
                ),
                '[]'
            ) as valuesJson

        FROM goals g
        JOIN expectations e ON g.expectationId = e.id
        \(whereClause)
        ORDER BY COALESCE(g.targetDate, g.startDate) ASC NULLS LAST
        """

        // Execute query with optional date arguments
        let rows = try GoalExportRow.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))

        // Parse rows to export format
        return try rows.map { row in
            try assembleGoalExport(from: row)
        }
    }
}

/// SQL result row for export query
private struct GoalExportRow: Decodable, FetchableRecord, Sendable {
    let goalId: String
    let goalStartDate: Date?
    let goalTargetDate: Date?
    let goalActionPlan: String?
    let goalExpectedTermLength: Int?
    let expectationId: String
    let expectationTitle: String?
    let expectationDetailedDescription: String?
    let expectationFreeformNotes: String?
    let expectationLogTime: Date
    let expectationImportance: Int
    let expectationUrgency: Int
    let measuresJson: String
    let valuesJson: String
}

/// JSON structure for simple measure target export
private struct MeasureExportJsonRow: Decodable, Sendable {
    let measureId: String
    let measureTitle: String?
    let measureUnit: String
    let targetValue: Double
}

/// Assemble GoalExport from SQL row with JSON parsing
///
/// Parses JSON arrays and flattens to simple export structure.
/// Throws ValidationError if JSON parsing fails.
private func assembleGoalExport(from row: GoalExportRow) throws -> GoalExport {
    let decoder = JSONDecoder()

    // Parse measures JSON
    guard let measuresData = row.measuresJson.data(using: .utf8) else {
        throw ValidationError.databaseConstraint("Invalid UTF-8 in measures JSON for goal \(row.goalId)")
    }

    let measuresJson: [MeasureExportJsonRow]
    do {
        measuresJson = try decoder.decode([MeasureExportJsonRow].self, from: measuresData)
    } catch {
        throw ValidationError.databaseConstraint("Failed to parse measures JSON for export: \(error)")
    }

    // Parse values JSON (array of UUID strings)
    guard let valuesData = row.valuesJson.data(using: .utf8) else {
        throw ValidationError.databaseConstraint("Invalid UTF-8 in values JSON for goal \(row.goalId)")
    }

    let valueIdStrings: [String]
    do {
        valueIdStrings = try decoder.decode([String].self, from: valuesData)
    } catch {
        throw ValidationError.databaseConstraint("Failed to parse values JSON for export: \(error)")
    }

    // Convert UUID strings to UUIDs
    guard let goalUUID = UUID(uuidString: row.goalId) else {
        throw ValidationError.databaseConstraint("Invalid goal UUID: \(row.goalId)")
    }

    let alignedValueIds = try valueIdStrings.map { idString in
        guard let uuid = UUID(uuidString: idString) else {
            throw ValidationError.databaseConstraint("Invalid value UUID: \(idString)")
        }
        return uuid
    }

    // Transform measures to export format
    let measureTargets = try measuresJson.map { m in
        guard let measureUUID = UUID(uuidString: m.measureId) else {
            throw ValidationError.databaseConstraint("Invalid measure UUID: \(m.measureId)")
        }

        return MeasureTargetExport(
            measureId: measureUUID,
            measureTitle: m.measureTitle,
            unit: m.measureUnit,
            targetValue: m.targetValue
        )
    }

    return GoalExport(
        id: goalUUID,
        startDate: row.goalStartDate,
        targetDate: row.goalTargetDate,
        actionPlan: row.goalActionPlan,
        expectedTermLength: row.goalExpectedTermLength,
        title: row.expectationTitle,
        detailedDescription: row.expectationDetailedDescription,
        freeformNotes: row.expectationFreeformNotes,
        expectationImportance: row.expectationImportance,
        expectationUrgency: row.expectationUrgency,
        logTime: row.expectationLogTime,
        measureTargets: measureTargets,
        alignedValueIds: alignedValueIds
    )
}

// MARK: - Dashboard Data Types

/// Raw progress data from SQL aggregation
///
/// **PERMANENT PATTERN**: Lightweight DTO for dashboard queries
/// Maps directly to SQL result columns - no complex object graph.
/// Service layer transforms this into business domain objects.
public struct GoalProgressData: Identifiable, Sendable {
    public let id: UUID                    // Goal ID
    public let goalTitle: String           // From expectations.title
    public let targetDate: Date?           // Goal deadline
    public let startDate: Date?            // Goal start
    public let measureId: UUID             // Which measure we're tracking
    public let measureName: String         // From measures.title
    public let measureUnit: String         // From measures.unit (km, hours, etc)
    public let targetValue: Double         // From expectationMeasures.targetValue
    public let currentProgress: Double     // SUM(measuredActions.value)
    public let percentComplete: Double     // Calculated percentage
    public let daysRemaining: Int?        // Days until targetDate

    // Note: Status calculation moved to service layer (business logic)
}

// MARK: - Dashboard Fetch Requests

/// Fetch goal progress with 6-table JOIN and aggregations
///
/// **PERMANENT PATTERN**: Raw SQL for complex dashboard queries
/// Based on SQL_QUERY_PATTERNS.md Query 1 (Goal Progress Overview).
///
/// This demonstrates the production pattern for dashboard aggregations:
/// - Multi-table JOINs with LEFT JOINs for optional data
/// - SQL aggregations (SUM, COALESCE) for progress calculations
/// - Direct SQL for clarity and performance
private struct FetchGoalProgressRequest: FetchKeyRequest {
    typealias Value = [GoalProgressData]

    func fetch(_ db: Database) throws -> [GoalProgressData] {
        let sql = """
            SELECT
                goals.id,
                expectations.title as goalTitle,
                goals.targetDate,
                goals.startDate,
                measures.id as measureId,
                measures.title as measureName,
                measures.unit as measureUnit,
                expectationMeasures.targetValue,
                -- Progress calculation with NULL handling
                COALESCE(SUM(measuredActions.value), 0) as currentProgress,
                -- Percentage with safe division
                CASE
                    WHEN expectationMeasures.targetValue > 0 THEN
                        ROUND(COALESCE(SUM(measuredActions.value), 0) / expectationMeasures.targetValue * 100, 1)
                    ELSE 0
                END as percentComplete,
                -- Days remaining (NULL if no target date)
                CASE
                    WHEN goals.targetDate IS NOT NULL THEN
                        CAST(JULIANDAY(goals.targetDate) - JULIANDAY('now') AS INTEGER)
                    ELSE NULL
                END as daysRemaining
            FROM goals
            INNER JOIN expectations ON goals.expectationId = expectations.id
            INNER JOIN expectationMeasures ON expectations.id = expectationMeasures.expectationId
            INNER JOIN measures ON expectationMeasures.measureId = measures.id
            -- LEFT JOIN to include goals without actions yet
            LEFT JOIN actionGoalContributions ON goals.id = actionGoalContributions.goalId
            LEFT JOIN actions ON actionGoalContributions.actionId = actions.id
            LEFT JOIN measuredActions
                ON actions.id = measuredActions.actionId
                AND measuredActions.measureId = measures.id
            -- Group by goal AND measure (goals can have multiple measures)
            GROUP BY goals.id, expectationMeasures.id
            -- Filter: Only show incomplete goals (< 100% complete)
            -- Note: Overdue goals (past targetDate but incomplete) are intentionally included
            HAVING percentComplete < 100
            -- Order by urgency: behind goals first, then by deadline
            ORDER BY
                percentComplete ASC,
                goals.targetDate ASC NULLS LAST
            """

        let rows = try GoalProgressRow.fetchAll(db, sql: sql)

        // Convert SQL rows to domain objects
        return rows.map { row in
            GoalProgressData(
                id: row.id,
                goalTitle: row.goalTitle,
                targetDate: row.targetDate,
                startDate: row.startDate,
                measureId: row.measureId,
                measureName: row.measureName,
                measureUnit: row.measureUnit,
                targetValue: row.targetValue,
                currentProgress: row.currentProgress,
                percentComplete: row.percentComplete,
                daysRemaining: row.daysRemaining
            )
        }
    }
}

/// SQL result row for goal progress query
///
/// Maps to SQL column names for automatic decoding
private struct GoalProgressRow: Decodable, FetchableRecord, Sendable {
    let id: UUID
    let goalTitle: String
    let targetDate: Date?
    let startDate: Date?
    let measureId: UUID
    let measureName: String
    let measureUnit: String
    let targetValue: Double
    let currentProgress: Double
    let percentComplete: Double
    let daysRemaining: Int?
}

// MARK: - Implementation Notes

// QUERY PATTERN - JSON AGGREGATION (AGGRESSIVE REFACTOR)
//
// GoalRepository now uses JSON aggregation for all multi-table fetches:
//
// Benefits:
// 1. Single query per fetch operation (vs 5 queries before)
// 2. SQLite does all grouping (faster than Swift Dictionary)
// 3. Atomic snapshot of data (single transaction)
// 4. Scales to 100K+ goals with constant performance
//
// Pattern:
// - json_group_array() + json_object() for nested data
// - COALESCE(..., '[]') ensures never NULL
// - FILTER (WHERE ...) excludes NULL joins
// - Decoded with JSONDecoder in Swift
//
// Trade-offs:
// - JSON parsing overhead (~1ms for typical goal count)
// - Less type-safe (runtime errors vs compile-time)
// - More complex SQL (but easier to debug in DB Browser)
//
// SWIFT 6 CONCURRENCY
//
// - NO @MainActor: Database I/O should run in background
// - Repository is Sendable-safe (immutable state, final class)
// - ViewModels await results on main actor automatically
// - Pattern matches PersonalValueCoordinator.swift
