//
// DataImporter.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// Main import service - coordinates parse → validate → transform → create.
//
// RESPONSIBILITIES:
// - Parse files (CSV or JSON)
// - Validate records (duplicate detection, FK validation)
// - Return preview (NO database writes)
// - Confirm import (transform → coordinator → database)
//
// PATTERN:
// - Mirror DataExporter architecture
// - Two-phase: preview (read-only) then confirm (write)
// - Generic over entity types
// - Atomic transactions via coordinators
//

import Foundation
import Models
import SQLiteData

/// Main import service
///
/// **Usage**:
/// ```swift
/// let importer = DataImporter(database: database)
///
/// // Phase 1: Preview (validation, no writes)
/// let records = try await importer.previewActions(from: fileURL, format: .csv)
///
/// // Phase 2: Confirm import (writes to database)
/// let result = try await importer.confirmImport(records)
/// ```
public final class DataImporter: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Preview (Phase 1: Validation Only)

    /// Preview actions from import file
    ///
    /// **Returns**: ImportRecords with validation status
    /// **Side Effects**: None (read-only validation)
    public func previewActions(
        from fileURL: URL,
        format: ExportFormat
    ) async throws -> [ImportRecord<ActionData>] {
        // Parse file
        let actions: [ActionData]

        switch format {
        case .csv:
            let csvParser = CSVParser()
            let csvText = try String(contentsOf: fileURL, encoding: .utf8)
            let rows = try csvParser.parse(csvText)
            actions = try rows.map { try EntityParsers.parseActionData($0) }
        case .json:
            let jsonParser = JSONParser()
            actions = try jsonParser.parseActions(from: fileURL)
        }

        // Validate
        let validator = ImportValidator(database: database)
        return try await validator.validate(actions, rowOffset: 2)  // Skip header row
    }

    /// Preview goals from import file
    public func previewGoals(
        from fileURL: URL,
        format: ExportFormat
    ) async throws -> [ImportRecord<GoalData>] {
        let goals: [GoalData]

        switch format {
        case .csv:
            let csvParser = CSVParser()
            let csvText = try String(contentsOf: fileURL, encoding: .utf8)
            let rows = try csvParser.parse(csvText)
            goals = try rows.map { try EntityParsers.parseGoalData($0) }
        case .json:
            let jsonParser = JSONParser()
            goals = try jsonParser.parseGoals(from: fileURL)
        }

        let validator = ImportValidator(database: database)
        return try await validator.validate(goals, rowOffset: 2)
    }

    /// Preview personal values from import file
    public func previewPersonalValues(
        from fileURL: URL,
        format: ExportFormat
    ) async throws -> [ImportRecord<PersonalValueData>] {
        let values: [PersonalValueData]

        switch format {
        case .csv:
            let csvParser = CSVParser()
            let csvText = try String(contentsOf: fileURL, encoding: .utf8)
            let rows = try csvParser.parse(csvText)
            values = try rows.map { try EntityParsers.parsePersonalValueData($0) }
        case .json:
            let jsonParser = JSONParser()
            values = try jsonParser.parsePersonalValues(from: fileURL)
        }

        let validator = ImportValidator(database: database)
        return try await validator.validate(values, rowOffset: 2)
    }

    /// Preview time periods from import file
    public func previewTimePeriods(
        from fileURL: URL,
        format: ExportFormat
    ) async throws -> [ImportRecord<TimePeriodData>] {
        let periods: [TimePeriodData]

        switch format {
        case .csv:
            let csvParser = CSVParser()
            let csvText = try String(contentsOf: fileURL, encoding: .utf8)
            let rows = try csvParser.parse(csvText)
            periods = try rows.map { try EntityParsers.parseTimePeriodData($0) }
        case .json:
            let jsonParser = JSONParser()
            periods = try jsonParser.parseTimePeriods(from: fileURL)
        }

        let validator = ImportValidator(database: database)
        return try await validator.validate(periods, rowOffset: 2)
    }

    // MARK: - Confirm Import (Phase 2: Database Writes)

    /// Confirm import of actions (writes to database)
    ///
    /// **Pattern**:
    /// 1. Filter checked records
    /// 2. Transform Data → FormData
    /// 3. Create via ActionCoordinator (atomic transaction)
    /// 4. Return detailed result
    public func confirmImportActions(
        _ records: [ImportRecord<ActionData>]
    ) async throws -> ImportResult {
        let recordsToImport = records.filter { $0.shouldImport }
        let transformer = FormDataTransformer()
        let coordinator = ActionCoordinator(database: database)

        var imported = 0
        var failed: [(rowNumber: Int, error: String)] = []

        for record in recordsToImport {
            do {
                let formData = transformer.transformAction(record.data)
                _ = try await coordinator.create(from: formData)
                imported += 1
            } catch let error as ValidationError {
                failed.append((record.rowNumber, error.userMessage))
            } catch {
                failed.append((record.rowNumber, error.localizedDescription))
            }
        }

        let skipped = records.count - recordsToImport.count

        return ImportResult(
            totalRecords: records.count,
            imported: imported,
            skipped: skipped,
            failed: failed
        )
    }

    /// Confirm import of goals
    public func confirmImportGoals(
        _ records: [ImportRecord<GoalData>]
    ) async throws -> ImportResult {
        let recordsToImport = records.filter { $0.shouldImport }
        let transformer = FormDataTransformer()
        let coordinator = GoalCoordinator(database: database)

        var imported = 0
        var failed: [(rowNumber: Int, error: String)] = []

        for record in recordsToImport {
            do {
                let formData = transformer.transformGoal(record.data)
                _ = try await coordinator.create(from: formData)
                imported += 1
            } catch let error as ValidationError {
                failed.append((record.rowNumber, error.userMessage))
            } catch {
                failed.append((record.rowNumber, error.localizedDescription))
            }
        }

        let skipped = records.count - recordsToImport.count

        return ImportResult(
            totalRecords: records.count,
            imported: imported,
            skipped: skipped,
            failed: failed
        )
    }

    /// Confirm import of personal values
    public func confirmImportPersonalValues(
        _ records: [ImportRecord<PersonalValueData>]
    ) async throws -> ImportResult {
        let recordsToImport = records.filter { $0.shouldImport }
        let transformer = FormDataTransformer()
        let coordinator = PersonalValueCoordinator(database: database)

        var imported = 0
        var failed: [(rowNumber: Int, error: String)] = []

        for record in recordsToImport {
            do {
                let formData = transformer.transformPersonalValue(record.data)
                _ = try await coordinator.create(from: formData)
                imported += 1
            } catch let error as ValidationError {
                failed.append((record.rowNumber, error.userMessage))
            } catch {
                failed.append((record.rowNumber, error.localizedDescription))
            }
        }

        let skipped = records.count - recordsToImport.count

        return ImportResult(
            totalRecords: records.count,
            imported: imported,
            skipped: skipped,
            failed: failed
        )
    }

    /// Confirm import of time periods
    public func confirmImportTimePeriods(
        _ records: [ImportRecord<TimePeriodData>]
    ) async throws -> ImportResult {
        let recordsToImport = records.filter { $0.shouldImport }
        let transformer = FormDataTransformer()
        let coordinator = TimePeriodCoordinator(database: database)

        var imported = 0
        var failed: [(rowNumber: Int, error: String)] = []

        for record in recordsToImport {
            do {
                let formData = transformer.transformTimePeriod(record.data)
                _ = try await coordinator.create(from: formData)
                imported += 1
            } catch let error as ValidationError {
                failed.append((record.rowNumber, error.userMessage))
            } catch {
                failed.append((record.rowNumber, error.localizedDescription))
            }
        }

        let skipped = records.count - recordsToImport.count

        return ImportResult(
            totalRecords: records.count,
            imported: imported,
            skipped: skipped,
            failed: failed
        )
    }
}
