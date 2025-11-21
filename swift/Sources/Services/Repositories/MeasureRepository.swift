//
// MeasureRepository.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// Repository for Measure entities using canonical MeasureData type.
// Simplest repository - catalog table with no relationships to aggregate.
//
// DESIGN DECISIONS:
// - Extends BaseRepository<MeasureData> (no separate export type)
// - Simple SELECT queries (no JSON aggregation needed - Measure has no outbound relationships)
// - Compound uniqueness check: (unit, measureType) for duplicate prevention
// - Fuzzy matching for UI suggestions (findSimilar with LIKE)
// - Inherits: error mapping, read/write wrappers, date filtering, pagination
//
// INTERACTION WITH CORE:
// - BaseRepository: Provides read/write wrappers, error mapping, pagination helpers
// - QueryStrategies: Direct SELECT (simplest pattern - no relationships)
// - ExportSupport: Date filtering via DateFilter helper
// - RepositoryProtocols: Conforms to Repository protocol (single DataType)
//

import Foundation
import Models
import SQLiteData
import GRDB

/// Repository for managing Measure entities
///
/// **Architecture Pattern**:
/// ```
/// MeasureRepository → BaseRepository<MeasureData> → Repository protocol
///                   ↓
///            Direct SELECT (no relationships)
/// ```
///
/// **Simplicity vs Other Repositories**:
/// - Measure is a pure catalog/lookup table
/// - NO relationships to aggregate (measures are referenced BY other entities)
/// - Simple SELECT queries (no JSON aggregation, no JOINs)
/// - Compound uniqueness: (unit, measureType)
///
/// **What BaseRepository Provides**:
/// - ✅ Error mapping (mapDatabaseError)
/// - ✅ Read/write wrappers with automatic error handling
/// - ✅ Date filtering helpers (DateFilter)
/// - ✅ Pagination (fetch(limit:offset:), fetchRecent(limit:))
///
/// **What This Repository Adds**:
/// - Compound uniqueness checks (exists(unit:measureType:))
/// - Fuzzy matching for UI suggestions (findSimilar)
/// - Type-based filtering (fetchByMeasureType)
/// - Unit conversion queries (fetchConvertible)
///
public final class MeasureRepository: BaseRepository<MeasureData> {

    // MARK: - Required Overrides

    /// Fetch all measures (synchronous, required by BaseRepository)
    ///
    /// **Implementation Strategy**: Simple SELECT query
    /// - No JSON aggregation needed (Measure has no relationships)
    /// - Single query (no joins)
    /// - Returns MeasureData (canonical type)
    ///
    /// **SQL Pattern**:
    /// ```sql
    /// SELECT id, title, detailedDescription, freeformNotes, logTime,
    ///        unit, measureType, canonicalUnit, conversionFactor
    /// FROM measures
    /// ORDER BY measureType ASC, unit ASC
    /// ```
    public override func fetchAll(_ db: Database) throws -> [MeasureData] {
        let sql = """
            SELECT
                m.id,
                m.title,
                m.detailedDescription,
                m.freeformNotes,
                m.logTime,
                m.unit,
                m.measureType,
                m.canonicalUnit,
                m.conversionFactor
            FROM measures m
            ORDER BY m.measureType ASC, m.unit ASC
            """

        let rows = try MeasureQueryRow.fetchAll(db, sql: sql)
        return rows.map { self.assembleMeasureData(from: $0) }
    }

    /// Check if measure exists by ID
    ///
    /// **Implementation**: Simple COUNT query
    /// Uses inherited `read` wrapper for automatic error mapping.
    public override func exists(_ id: UUID) async throws -> Bool {
        try await read { db in
            let sql = "SELECT 1 FROM measures WHERE id = ? LIMIT 1"
            return try Row.fetchOne(db, sql: sql, arguments: [id]) != nil
        }
    }

    /// Fetch measures with optional date filtering (for export)
    ///
    /// **Implementation**: Same as fetchAll() + WHERE clause on logTime
    /// Uses DateFilter helper from ExportSupport for consistent date filtering.
    public override func fetchForExport(from startDate: Date?, to endDate: Date?) async throws -> [MeasureData] {
        try await read { db in
            let dateFilter = DateFilter(startDate: startDate, endDate: endDate)
            let (whereClause, arguments) = dateFilter.buildWhereClause(dateColumn: "m.logTime")

            let sql = """
                SELECT
                    m.id,
                    m.title,
                    m.detailedDescription,
                    m.freeformNotes,
                    m.logTime,
                    m.unit,
                    m.measureType,
                    m.canonicalUnit,
                    m.conversionFactor
                FROM measures m
                \(whereClause)
                ORDER BY m.measureType ASC, m.unit ASC
                """

            let rows = try MeasureQueryRow.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return rows.map { self.assembleMeasureData(from: $0) }
        }
    }

    // MARK: - Entity-Specific Queries (Duplicate Prevention)

    /// Check if measure with (unit, measureType) already exists (case-insensitive)
    ///
    /// **Use Case**: Prevent duplicate "km" + "distance" measures in validation
    /// **Implementation**: SELECT COUNT WHERE LOWER(unit) = LOWER(?) AND LOWER(measureType) = LOWER(?)
    ///
    /// **Compound Uniqueness**: (unit, measureType) - both required for duplicate check
    /// This is the PRIMARY duplicate prevention method for measures.
    ///
    /// **Example**:
    /// ```swift
    /// // Prevent duplicate "km" distance measure
    /// let isDuplicate = try await repository.exists(unit: "km", measureType: "distance")
    /// ```
    public func exists(unit: String, measureType: String) async throws -> Bool {
        try await read { db in
            let sql = """
                SELECT 1 FROM measures
                WHERE LOWER(unit) = LOWER(?)
                  AND LOWER(measureType) = LOWER(?)
                LIMIT 1
                """
            return try Row.fetchOne(db, sql: sql, arguments: [unit, measureType]) != nil
        }
    }

    /// Find measures with similar units (fuzzy matching for UI suggestions)
    ///
    /// **Use Case**: User types "killometers" → suggest "km" (existing measure)
    /// **Implementation**: SELECT WHERE LOWER(unit) LIKE LOWER(?)
    ///
    /// **Fuzzy Matching Strategy**:
    /// - Case-insensitive LIKE with wildcards
    /// - Matches partial unit names (e.g., "kilo" matches "kilometers", "km")
    /// - Returns all matches sorted by measure type
    ///
    /// **Example**:
    /// ```swift
    /// // User types "kilo" in unit field
    /// let suggestions = try await repository.findSimilar(unit: "kilo")
    /// // Returns: [MeasureData(unit: "km", measureType: "distance"),
    /// //           MeasureData(unit: "kilometers", measureType: "distance")]
    /// ```
    public func findSimilar(unit: String) async throws -> [MeasureData] {
        try await read { db in
            let sql = """
                SELECT
                    m.id,
                    m.title,
                    m.detailedDescription,
                    m.freeformNotes,
                    m.logTime,
                    m.unit,
                    m.measureType,
                    m.canonicalUnit,
                    m.conversionFactor
                FROM measures m
                WHERE LOWER(m.unit) LIKE LOWER(?)
                ORDER BY m.measureType ASC, m.unit ASC
                """

            let searchPattern = "%\(unit)%"
            let rows = try MeasureQueryRow.fetchAll(db, sql: sql, arguments: [searchPattern])
            return rows.map { self.assembleMeasureData(from: $0) }
        }
    }

    // MARK: - Entity-Specific Queries (Filtering)

    /// Fetch measures by measure type
    ///
    /// **Use Case**: "Show all distance measures" or "Show all time measures"
    /// **Implementation**: WHERE measureType = ?
    ///
    /// **Measure Types**: distance, time, count, weight, volume, etc.
    ///
    /// **Example**:
    /// ```swift
    /// let distanceMeasures = try await repository.fetchByMeasureType("distance")
    /// // Returns: [km, miles, meters, etc.]
    /// ```
    public func fetchByMeasureType(_ measureType: String) async throws -> [MeasureData] {
        try await read { db in
            let sql = """
                SELECT
                    m.id,
                    m.title,
                    m.detailedDescription,
                    m.freeformNotes,
                    m.logTime,
                    m.unit,
                    m.measureType,
                    m.canonicalUnit,
                    m.conversionFactor
                FROM measures m
                WHERE m.measureType = ?
                ORDER BY m.unit ASC
                """

            let rows = try MeasureQueryRow.fetchAll(db, sql: sql, arguments: [measureType])
            return rows.map { self.assembleMeasureData(from: $0) }
        }
    }

    /// Fetch measures that support unit conversion (have canonicalUnit and conversionFactor)
    ///
    /// **Use Case**: "Show all measures that can be converted to canonical units"
    /// **Implementation**: WHERE canonicalUnit IS NOT NULL AND conversionFactor IS NOT NULL
    ///
    /// **Example**:
    /// ```swift
    /// let convertibleMeasures = try await repository.fetchConvertible()
    /// // Returns: [km (→ meters, 1000), miles (→ meters, 1609.34), etc.]
    /// ```
    public func fetchConvertible() async throws -> [MeasureData] {
        try await read { db in
            let sql = """
                SELECT
                    m.id,
                    m.title,
                    m.detailedDescription,
                    m.freeformNotes,
                    m.logTime,
                    m.unit,
                    m.measureType,
                    m.canonicalUnit,
                    m.conversionFactor
                FROM measures m
                WHERE m.canonicalUnit IS NOT NULL
                  AND m.conversionFactor IS NOT NULL
                ORDER BY m.measureType ASC, m.unit ASC
                """

            let rows = try MeasureQueryRow.fetchAll(db, sql: sql)
            return rows.map { self.assembleMeasureData(from: $0) }
        }
    }

    // MARK: - Error Mapping Override

    /// Map database errors to user-friendly validation errors
    ///
    /// **Measure-specific mappings**:
    /// - CHECK constraint on unit/measureType → custom validation message
    /// - All other constraints handled by BaseRepository
    ///
    /// **PATTERN**: Override only measure-specific error cases, delegate rest to BaseRepository
    public override func mapDatabaseError(_ error: Error) -> ValidationError {
        guard let dbError = error as? DatabaseError else {
            return super.mapDatabaseError(error)  // Delegate non-DB errors to base
        }

        // Handle measure-specific CHECK constraints
        if dbError.resultCode == .SQLITE_CONSTRAINT_CHECK {
            if dbError.message?.contains("unit") == true {
                return .databaseConstraint("Unit is required and cannot be empty")
            }
            if dbError.message?.contains("measureType") == true {
                return .databaseConstraint("Measure type is required and cannot be empty")
            }
        }

        // All other errors handled by base implementation
        // (UNIQUE, NOTNULL, FOREIGNKEY, BUSY, LOCKED, etc.)
        return super.mapDatabaseError(error)
    }

    // MARK: - Private Helpers

    /// Assemble MeasureData from query row
    ///
    /// **Pattern**: Simple mapping (no relationships to assemble)
    ///
    /// **Simplest Repository**: No JSON parsing, no nested structures.
    /// Just direct field mapping from SQL row to MeasureData.
    ///
    /// - Parameter row: MeasureQueryRow with all Measure fields
    /// - Returns: Assembled MeasureData
    private func assembleMeasureData(from row: MeasureQueryRow) -> MeasureData {
        MeasureData(
            id: row.id,
            title: row.title,
            detailedDescription: row.detailedDescription,
            freeformNotes: row.freeformNotes,
            logTime: row.logTime,
            unit: row.unit,
            measureType: row.measureType,
            canonicalUnit: row.canonicalUnit,
            conversionFactor: row.conversionFactor
        )
    }

    /// Query row structure matching SQL SELECT columns
    ///
    /// **Fields**: All Measure columns (no relationship data)
    ///
    /// **Usage**: Intermediate struct for SQL → MeasureData transformation
    private struct MeasureQueryRow: Decodable, FetchableRecord, Sendable {
        // Measure fields (from measures table)
        let id: UUID
        let title: String?
        let detailedDescription: String?
        let freeformNotes: String?
        let logTime: Date
        let unit: String
        let measureType: String
        let canonicalUnit: String?
        let conversionFactor: Double?
    }
}

// MARK: - Sendable Conformance

// MeasureRepository is Sendable because:
// - Inherits from BaseRepository (already Sendable)
// - No additional mutable state
// - Safe to pass between actor boundaries
extension MeasureRepository: @unchecked Sendable {}

// =============================================================================
// IMPLEMENTATION NOTES
// =============================================================================
//
// SIMPLICITY - SIMPLEST REPOSITORY:
// Measure is the simplest repository in the codebase:
// - Pure catalog/lookup table (referenced BY other entities, not the other way)
// - NO relationships to aggregate
// - NO JSON aggregation needed
// - NO JOINs required
// - Simple SELECT queries only
//
// This makes the implementation straightforward:
// 1. SELECT measure fields directly
// 2. Map to MeasureData (no relationship assembly)
// 3. Return results
//
// DUPLICATE PREVENTION STRATEGY:
// Measures use compound uniqueness: (unit, measureType)
// - Not just unit alone (e.g., "km" could be distance OR speed)
// - Not just measureType alone (many measures per type)
// - Both together form unique key
//
// Examples:
// - ("km", "distance") - kilometers for distance
// - ("km/h", "speed") - kilometers per hour for speed
// - ("hours", "time") - hours for time duration
//
// FUZZY MATCHING:
// findSimilar(unit:) helps prevent user typos:
// - "killometers" → suggests "km", "kilometers"
// - "mins" → suggests "minutes"
// - "occassions" → suggests "occasions"
//
// QUERY STRATEGY:
// Uses direct SELECT (simplest pattern) because:
// - No relationships to aggregate
// - No nested data structures
// - No N+1 problem (Measure is leaf node in entity graph)
// - Consistent with PersonalValueRepository approach (but even simpler)
//
// ERROR MAPPING:
// Measure has minimal constraints:
// - NOT NULL on unit/measureType (required fields)
// - No UNIQUE constraints (duplicates prevented at application level)
// - No complex foreign key cascades (Measure is referenced, not referencing)
//
// =============================================================================
