//
// TimePeriodRepository.swift
// Written by Claude Code on 2025-11-08
// Implemented on 2025-11-10 following Swift 6 concurrency patterns
// Refactored to canonical TermData type on 2025-11-15
//
// PURPOSE:
// Read coordinator for TimePeriod/Term entities - centralizes query logic.
// Complements TimePeriodCoordinator (writes) by handling all read operations.
// Returns canonical TermData type for both display and export needs.
//
// RESPONSIBILITIES:
// 1. Read operations - fetchAll(), fetchCurrentTerm(), fetchByDateRange()
// 2. Existence checks - existsByTermNumber() for duplicate prevention
// 3. Error mapping - DatabaseError → ValidationError
//
// PATTERN:
// - Query builders for simple JOINs (GoalTerm + TimePeriod)
// - Bulk fetch goal assignments to avoid N+1
// - Returns TermData for all operations (canonical type)
// - TermData serves both display (via .asWithPeriod) and export (via Codable)
//

import Foundation
import Models
import SQLiteData

// MARK: - Canonical Data Type
//
// TermData is now defined in Models/CanonicalTypes/TermData.swift
// This repository returns TermData for both display and export needs.
// TermExport type is deprecated - use TermData instead.

// REMOVED @MainActor: Repository performs database queries which are I/O
// operations that should run in background. Database reads should not block
// the main thread. ViewModels will await results on main actor as needed.
//
// SENDABLE: Conforms to Sendable for Swift 6 strict concurrency.
// Safe because:
// - Only immutable property (private let database)
// - All methods are async (thread-safe by nature)
// - Can be safely passed from @MainActor ViewModels to background tasks
public final class TimePeriodRepository: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Read Operations

    /// Fetch all terms with their time periods
    ///
    /// Orders by term number descending (most recent first)
    /// Returns canonical TermData type (use .asWithPeriod if views need nested structure)
    public func fetchAll() async throws -> [TermData] {
        do {
            return try await database.read { db in
                try FetchAllTermsRequest().fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Fetch the current term (today's date falls within start/end)
    public func fetchCurrentTerm() async throws -> TermData? {
        do {
            return try await database.read { db in
                try FetchCurrentTermRequest().fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Fetch terms within a date range
    ///
    /// Returns terms whose time periods overlap with the given range
    public func fetchByDateRange(_ range: ClosedRange<Date>) async throws -> [TermData] {
        do {
            return try await database.read { db in
                try FetchTermsByDateRangeRequest(range: range).fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }


    // MARK: - Existence Checks

    /// Check if a term with this number already exists
    public func existsByTermNumber(_ termNumber: Int) async throws -> Bool {
        do {
            return try await database.read { db in
                try ExistsByTermNumberRequest(termNumber: termNumber).fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Check if a term exists by ID
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
        case .SQLITE_CONSTRAINT_UNIQUE:
            return .duplicateRecord("This term number already exists")
        case .SQLITE_CONSTRAINT_NOTNULL:
            return .missingRequiredField("Required field is missing")
        case .SQLITE_CONSTRAINT_FOREIGNKEY:
            return .foreignKeyViolation("Referenced time period not found")
        case .SQLITE_CONSTRAINT:
            return .databaseConstraint(dbError.message ?? "Database constraint violated")
        default:
            return .databaseConstraint(dbError.localizedDescription)
        }
    }
}

// MARK: - Fetch Requests

/// Fetch all terms with their time periods
///
/// Fetches terms + periods via JOIN, then bulk fetches goal assignments
private struct FetchAllTermsRequest: FetchKeyRequest {
    typealias Value = [TermData]

    func fetch(_ db: Database) throws -> [TermData] {
        // Step 1: Fetch terms + time periods (simple JOIN)
        let termPeriods = try GoalTerm.all
            .order { $0.termNumber.desc() }
            .join(TimePeriod.all) { $0.timePeriodId.eq($1.id) }
            .fetchAll(db)

        // Step 2: Bulk fetch goal assignments (avoid N+1)
        let termIds = termPeriods.map { $0.0.id }
        let allAssignments = try TermGoalAssignment.all
            .where { termIds.contains($0.termId) }
            .fetchAll(db)

        // Group by termId for O(1) lookup
        let assignmentsByTerm = Dictionary(
            grouping: allAssignments,
            by: { $0.termId }
        )

        // Step 3: Assemble TermData
        return termPeriods.map { (term, timePeriod) in
            let goalIds = assignmentsByTerm[term.id]?
                .map { $0.goalId }
                .sorted { $0.uuidString < $1.uuidString }

            return TermData(
                id: term.id,
                termNumber: term.termNumber,
                theme: term.theme,
                reflection: term.reflection,
                status: term.status?.rawValue,
                timePeriodId: timePeriod.id,
                timePeriodTitle: timePeriod.title,
                startDate: timePeriod.startDate,
                endDate: timePeriod.endDate,
                assignedGoalIds: goalIds
            )
        }
    }
}

/// Fetch current term (today's date within start/end range)
private struct FetchCurrentTermRequest: FetchKeyRequest {
    typealias Value = TermData?

    func fetch(_ db: Database) throws -> TermData? {
        let now = Date()

        // Fetch all terms + periods, then filter in Swift
        let termPeriods = try GoalTerm.all
            .join(TimePeriod.all) { $0.timePeriodId.eq($1.id) }
            .fetchAll(db)

        // Find term where now is between startDate and endDate
        guard let (term, timePeriod) = termPeriods.first(where: { (_, tp) in
            tp.startDate <= now && tp.endDate >= now
        }) else {
            return nil
        }

        // Fetch goal assignments for this term
        let assignments = try TermGoalAssignment.all
            .where { $0.termId == term.id }
            .fetchAll(db)

        let goalIds = assignments.map { $0.goalId }.sorted { $0.uuidString < $1.uuidString }

        return TermData(
            id: term.id,
            termNumber: term.termNumber,
            theme: term.theme,
            reflection: term.reflection,
            status: term.status?.rawValue,
            timePeriodId: timePeriod.id,
            timePeriodTitle: timePeriod.title,
            startDate: timePeriod.startDate,
            endDate: timePeriod.endDate,
            assignedGoalIds: goalIds.isEmpty ? nil : goalIds
        )
    }
}

/// Fetch terms within a date range
private struct FetchTermsByDateRangeRequest: FetchKeyRequest {
    typealias Value = [TermData]
    let range: ClosedRange<Date>

    func fetch(_ db: Database) throws -> [TermData] {
        // Fetch all terms + periods
        let termPeriods = try GoalTerm.all
            .join(TimePeriod.all) { $0.timePeriodId.eq($1.id) }
            .fetchAll(db)

        // Filter to terms whose periods overlap with the range
        let filteredTermPeriods = termPeriods.filter { (_, timePeriod) in
            timePeriod.startDate <= range.upperBound && timePeriod.endDate >= range.lowerBound
        }

        // Bulk fetch goal assignments
        let termIds = filteredTermPeriods.map { $0.0.id }
        let allAssignments = try TermGoalAssignment.all
            .where { termIds.contains($0.termId) }
            .fetchAll(db)

        let assignmentsByTerm = Dictionary(grouping: allAssignments, by: { $0.termId })

        // Assemble TermData
        return filteredTermPeriods
            .map { (term, timePeriod) in
                let goalIds = assignmentsByTerm[term.id]?
                    .map { $0.goalId }
                    .sorted { $0.uuidString < $1.uuidString }

                return TermData(
                    id: term.id,
                    termNumber: term.termNumber,
                    theme: term.theme,
                    reflection: term.reflection,
                    status: term.status?.rawValue,
                    timePeriodId: timePeriod.id,
                    timePeriodTitle: timePeriod.title,
                    startDate: timePeriod.startDate,
                    endDate: timePeriod.endDate,
                    assignedGoalIds: goalIds
                )
            }
            .sorted { $0.termNumber > $1.termNumber }
    }
}

/// Check if term number exists
private struct ExistsByTermNumberRequest: FetchKeyRequest {
    typealias Value = Bool
    let termNumber: Int

    func fetch(_ db: Database) throws -> Bool {
        let count = try #sql(
            """
            SELECT COUNT(*)
            FROM \(GoalTerm.self)
            WHERE \(GoalTerm.termNumber) = \(bind: termNumber)
            """,
            as: Int.self
        ).fetchOne(db) ?? 0
        return count > 0
    }
}

/// Check if term exists by ID
private struct ExistsByIdRequest: FetchKeyRequest {
    typealias Value = Bool
    let id: UUID

    func fetch(_ db: Database) throws -> Bool {
        try GoalTerm.find(id).fetchOne(db) != nil
    }
}


// MARK: - Implementation Notes

// QUERY PATTERN CHOICE
//
// TimePeriodRepository uses query builders for JOINs because:
// 1. Simple 1:1 relationship (GoalTerm + TimePeriod)
// 2. Query builder already optimal for this case
// 3. Type safety during development
// 4. Matches TermsQuery.swift pattern (proven in production)
//
// Uses #sql for:
// - Existence checks (COUNT queries)
// - Future aggregations if needed (goals per term, etc.)
//
// Date filtering done in Swift because:
// - Overlap logic is simpler to read in Swift
// - Query builder date comparison syntax is verbose
// - Performance fine for typical term counts (<100)
//
// SWIFT 6 CONCURRENCY
//
// - NO @MainActor: Database I/O should run in background
// - Repository is Sendable-safe (immutable state, final class)
// - ViewModels await results on main actor automatically
// - Pattern matches other repositories
