//
// TimePeriodRepository.swift
// Written by Claude Code on 2025-11-16
//
// PURPOSE:
// Repository for TimePeriod entities using canonical TimePeriodData type.
// Refactored from TimePeriodRepository.swift to extend BaseRepository<TimePeriodData>.
//
// DESIGN DECISIONS:
// - Extends BaseRepository<TimePeriodData> (single generic parameter)
// - Simple 1:1 JOIN (GoalTerm + TimePeriod) - no JSON aggregation needed
// - Bulk fetches goal assignments to avoid N+1
// - Eliminates FetchKeyRequest wrappers (direct SQL methods)
// - Inherits: error mapping, read/write wrappers, date filtering, pagination helpers
//
// SIMPLICITY FACTORS:
// - Simplest repository in the v3 series
// - No nested JSON structures (unlike Goal/Action)
// - Straightforward query builder pattern for JOIN
// - Good validation case for BaseRepository infrastructure
//

import Foundation
import Models
import SQLiteData
import GRDB

/// Repository for managing TimePeriod/Term entities using canonical TimePeriodData
///
/// **Architecture**:
/// ```
/// TimePeriodRepository → BaseRepository<TimePeriodData> → Repository protocol
///                      ↓
///              Simple 1:1 JOIN (GoalTerm + TimePeriod)
/// ```
///
/// **Simplicity vs Other Repositories**:
/// - No JSON aggregation (GoalRepository has 3, ActionRepository has 2)
/// - Simple 1:1 JOIN instead of complex multi-table queries
/// - Bulk fetch pattern for goal assignments (proven in current implementation)
/// - Direct SQL for date filtering and overlap detection
///
/// **What BaseRepository Provides**:
/// - ✅ Error mapping (mapDatabaseError) - uses base implementation
/// - ✅ Read/write wrappers with automatic error handling
/// - ✅ Date filtering helpers (buildDateFilter)
/// - ✅ Pagination (fetch(limit:offset:), fetchRecent(limit:))
///
/// **What This Repository Adds**:
/// - GoalTerm + TimePeriod JOIN (1:1 flattening)
/// - Goal assignment bulk loading (avoid N+1)
/// - Term number uniqueness checks
/// - Date overlap detection (prevent conflicting terms)
/// - Current term lookup (which term contains today?)
///
public final class TimePeriodRepository: BaseRepository<TimePeriodData> {

    // MARK: - Required Overrides (BaseRepository)

    /// Fetch all terms with time periods and goal assignments
    ///
    /// **Pattern**: Simple JOIN + bulk fetch for assignments
    /// **Performance**: O(2) queries (terms+periods, then assignments)
    /// **Source**: Adapted from TimePeriodRepository.swift FetchAllTermsRequest (lines 143-184)
    public override func fetchAll() async throws -> [TimePeriodData] {
        try await read { db in
            // Step 1: Fetch terms + time periods via 1:1 JOIN
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

            // Step 3: Assemble TimePeriodData from (GoalTerm, TimePeriod) tuples
            return termPeriods.map { (term, timePeriod) in
                let goalIds = assignmentsByTerm[term.id]?
                    .map { $0.goalId }
                    .sorted { $0.uuidString < $1.uuidString }

                return TimePeriodData(
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

    /// Check if term exists by ID
    ///
    /// **Implementation**: Simple GoalTerm.find() query
    /// **Source**: Copied from TimePeriodRepository.swift ExistsByIdRequest (lines 295-301)
    public override func exists(_ id: UUID) async throws -> Bool {
        try await read { db in
            try GoalTerm.find(id).fetchOne(db) != nil
        }
    }

    /// Fetch terms with optional date filtering (for export)
    ///
    /// **Date Filter Strategy**: Filter on TimePeriod date range overlap
    /// **Note**: Unlike Goal (filters on logTime), Terms filter on period overlap
    /// **Source**: Adapted from TimePeriodRepository.swift FetchTermsByDateRangeRequest (lines 229-273)
    public override func fetchForExport(from startDate: Date?, to endDate: Date?) async throws -> [TimePeriodData] {
        // If no date filter, use fetchAll
        guard startDate != nil || endDate != nil else {
            return try await fetchAll()
        }

        return try await read { db in
            // Fetch all terms + periods
            let termPeriods = try GoalTerm.all
                .join(TimePeriod.all) { $0.timePeriodId.eq($1.id) }
                .fetchAll(db)

            // Filter to terms whose periods overlap with the range
            let rangeStart = startDate ?? Date.distantPast
            let rangeEnd = endDate ?? Date.distantFuture

            let filteredTermPeriods = termPeriods.filter { (_, timePeriod) in
                timePeriod.startDate <= rangeEnd && timePeriod.endDate >= rangeStart
            }

            // Bulk fetch goal assignments for filtered terms
            let termIds = filteredTermPeriods.map { $0.0.id }
            let allAssignments = try TermGoalAssignment.all
                .where { termIds.contains($0.termId) }
                .fetchAll(db)

            let assignmentsByTerm = Dictionary(grouping: allAssignments, by: { $0.termId })

            // Assemble TimePeriodData
            return filteredTermPeriods
                .map { (term, timePeriod) in
                    let goalIds = assignmentsByTerm[term.id]?
                        .map { $0.goalId }
                        .sorted { $0.uuidString < $1.uuidString }

                    return TimePeriodData(
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

    // MARK: - Pagination Overrides (Optional but Recommended)

    /// Fetch paginated terms with SQL-level efficiency
    ///
    /// **Optimization**: Uses query builder LIMIT/OFFSET support
    /// **Note**: Terms typically small (<100), but good practice for consistency
    public override func fetch(limit: Int, offset: Int = 0) async throws -> [TimePeriodData] {
        try await read { db in
            // Fetch terms + periods with LIMIT/OFFSET
            let termPeriods = try GoalTerm.all
                .order { $0.termNumber.desc() }
                .join(TimePeriod.all) { $0.timePeriodId.eq($1.id) }
                .limit(limit, offset: offset)
                .fetchAll(db)

            // Bulk fetch assignments only for these terms
            let termIds = termPeriods.map { $0.0.id }
            let allAssignments = try TermGoalAssignment.all
                .where { termIds.contains($0.termId) }
                .fetchAll(db)

            let assignmentsByTerm = Dictionary(grouping: allAssignments, by: { $0.termId })

            return termPeriods.map { (term, timePeriod) in
                let goalIds = assignmentsByTerm[term.id]?
                    .map { $0.goalId }
                    .sorted { $0.uuidString < $1.uuidString }

                return TimePeriodData(
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

    /// Fetch most recent terms by term number
    ///
    /// **Sort Order**: termNumber DESC (higher term numbers are more recent)
    /// **Note**: Not by logTime - term numbers define recency for terms
    public override func fetchRecent(limit: Int) async throws -> [TimePeriodData] {
        // Same as fetch(limit:offset:) but with offset=0
        try await fetch(limit: limit, offset: 0)
    }

    // MARK: - Entity-Specific Queries

    /// Fetch the current term (today's date falls within period)
    ///
    /// **Use Case**: Dashboard showing "Current Term: Term 5"
    /// **Implementation**: WHERE startDate <= NOW AND endDate >= NOW
    /// **Source**: Adapted from TimePeriodRepository.swift FetchCurrentTermRequest (lines 188-225)
    public func fetchCurrentTerm() async throws -> TimePeriodData? {
        try await read { db in
            let now = Date()

            // Fetch all terms + periods, then filter in Swift
            // (More readable than SQL date comparison in query builder)
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

            return TimePeriodData(
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

    /// Fetch terms by status (planned, active, completed, etc.)
    ///
    /// **Use Case**: "Show all completed terms" or "Show active term"
    /// **Implementation**: WHERE status = ?
    /// **Statuses**: planned, active, completed, delayed, on_hold, cancelled
    public func fetchByStatus(_ status: String) async throws -> [TimePeriodData] {
        try await read { db in
            // Parse status string to TermStatus enum for validation
            guard let termStatus = TermStatus(rawValue: status) else {
                throw ValidationError.databaseConstraint("Invalid status: \(status)")
            }

            // Fetch terms with matching status
            let termPeriods = try GoalTerm.all
                .where { $0.status == termStatus }
                .order { $0.termNumber.desc() }
                .join(TimePeriod.all) { $0.timePeriodId.eq($1.id) }
                .fetchAll(db)

            // Bulk fetch assignments
            let termIds = termPeriods.map { $0.0.id }
            let allAssignments = try TermGoalAssignment.all
                .where { termIds.contains($0.termId) }
                .fetchAll(db)

            let assignmentsByTerm = Dictionary(grouping: allAssignments, by: { $0.termId })

            return termPeriods.map { (term, timePeriod) in
                let goalIds = assignmentsByTerm[term.id]?
                    .map { $0.goalId }
                    .sorted { $0.uuidString < $1.uuidString }

                return TimePeriodData(
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

    /// Check if overlapping terms exist (for validation)
    ///
    /// **Use Case**: Prevent creating Term 6 that overlaps with Term 5's dates
    /// **Implementation**: Find terms where period overlaps with given range
    /// **Note**: Optionally exclude a specific term ID (for update validation)
    public func hasOverlap(start: Date, end: Date, excluding termId: UUID? = nil) async throws -> Bool {
        try await read { db in
            // Fetch all terms + periods
            let termPeriods = try GoalTerm.all
                .join(TimePeriod.all) { $0.timePeriodId.eq($1.id) }
                .fetchAll(db)

            // Filter to overlapping terms (excluding the specified ID if provided)
            let overlapping = termPeriods.filter { (term, timePeriod) in
                // Skip if this is the term being updated
                if let excludeId = termId, term.id == excludeId {
                    return false
                }

                // Check overlap: periods overlap if NOT (end < otherStart OR start > otherEnd)
                return !(end < timePeriod.startDate || start > timePeriod.endDate)
            }

            return !overlapping.isEmpty
        }
    }

    // MARK: - Uniqueness Checks

    /// Check if a term with this number already exists
    ///
    /// **Use Case**: Prevent duplicate "Term 5" entries
    /// **Implementation**: SELECT COUNT WHERE termNumber = ?
    /// **Source**: Adapted from TimePeriodRepository.swift ExistsByTermNumberRequest (lines 277-291)
    public func exists(termNumber: Int) async throws -> Bool {
        try await read { db in
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
}

// MARK: - Sendable Conformance

// TimePeriodRepository_v3 is Sendable because:
// - Inherits from BaseRepository (already Sendable)
// - No additional mutable state
// - All methods are async (thread-safe)
// - Safe to pass between actor boundaries
extension TimePeriodRepository: @unchecked Sendable {}

// =============================================================================
// IMPLEMENTATION NOTES
// =============================================================================
//
// QUERY PATTERN CHOICE:
//
// Uses Query Builder (not JSON aggregation) because:
// 1. Simple 1:1 relationship (GoalTerm + TimePeriod)
// 2. No nested structures to parse
// 3. Type-safe at compile time
// 4. Matches proven pattern from TimePeriodRepository.swift
//
// Bulk Fetch Pattern:
// - Fetches all terms first
// - Then bulk fetches assignments (WHERE termId IN (...))
// - Avoids N+1 query problem
// - O(2) queries regardless of term count
//
// Date Filtering Strategy:
// - Overlap logic done in Swift (more readable than SQL)
// - Performance fine for typical term counts (<100)
// - Could optimize with SQL if needed: WHERE NOT (end < startDate OR start > endDate)
//
// Pagination:
// - Query builder .limit() / .offset() support
// - Simpler than Goal's manual SQL LIMIT/OFFSET
//
// =============================================================================
