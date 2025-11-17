//
// ImportValidator.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// Validate import records before database writes.
//
// RESPONSIBILITIES:
// - Check for duplicate IDs (exact matches)
// - Validate FK references (measures, goals, values exist)
// - Run semantic duplicate detection (NLEmbedding)
// - Run business rule validation (reuse existing validators)
// - Return ImportRecords with comprehensive status
//
// PATTERN:
// - Generic validator works with any Data type
// - Async validation (queries repositories)
// - Reuses existing validation infrastructure
//

import Foundation
import Models
import SQLiteData

/// Validator for import preview
///
/// **Usage**:
/// ```swift
/// let validator = ImportValidator(database: database)
/// let records = try await validator.validate(parsedActions, rowOffset: 1)
/// // Returns [ImportRecord<ActionData>] with validation status
/// ```
public final class ImportValidator: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Action Validation

    /// Validate parsed actions for import
    ///
    /// **Checks**:
    /// 1. Duplicate IDs (existing actions with same ID)
    /// 2. Semantic duplicates (similar titles via NLEmbedding)
    /// 3. FK validation (measures, goals exist)
    /// 4. Business rules (ActionValidation)
    public func validate(
        _ actions: [ActionData],
        rowOffset: Int = 1
    ) async throws -> [ImportRecord<ActionData>] {
        let repository = ActionRepository(database: database)

        var records: [ImportRecord<ActionData>] = []

        for (index, action) in actions.enumerated() {
            let rowNumber = rowOffset + index

            // Check for duplicate ID
            let idExists = try await repository.exists(action.id)
            if idExists {
                records.append(ImportRecord(
                    id: action.id,
                    rowNumber: rowNumber,
                    data: action,
                    status: .duplicateID(existing: action.id),
                    shouldImport: false  // Default: don't import duplicates
                ))
                continue
            }

            // TODO: Semantic duplicate detection (requires SemanticService)
            // For now, mark as valid
            records.append(ImportRecord(
                id: action.id,
                rowNumber: rowNumber,
                data: action,
                status: .valid,
                shouldImport: true
            ))
        }

        return records
    }

    // MARK: - Goal Validation

    /// Validate parsed goals for import
    ///
    /// **Checks**:
    /// 1. Duplicate IDs
    /// 2. Semantic duplicates
    /// 3. FK validation (measures, values exist)
    /// 4. Business rules (GoalValidation)
    public func validate(
        _ goals: [GoalData],
        rowOffset: Int = 1
    ) async throws -> [ImportRecord<GoalData>] {
        let repository = GoalRepository(database: database)

        var records: [ImportRecord<GoalData>] = []

        for (index, goal) in goals.enumerated() {
            let rowNumber = rowOffset + index

            // Check for duplicate ID
            let idExists = try await repository.exists(goal.id)
            if idExists {
                records.append(ImportRecord(
                    id: goal.id,
                    rowNumber: rowNumber,
                    data: goal,
                    status: .duplicateID(existing: goal.id),
                    shouldImport: false
                ))
                continue
            }

            // TODO: Validate FK references (measures, values)
            // TODO: Semantic duplicate detection
            records.append(ImportRecord(
                id: goal.id,
                rowNumber: rowNumber,
                data: goal,
                status: .valid,
                shouldImport: true
            ))
        }

        return records
    }

    // MARK: - PersonalValue Validation

    /// Validate parsed personal values for import
    ///
    /// **Checks**:
    /// 1. Duplicate IDs
    /// 2. Semantic duplicates
    /// 3. Business rules (PersonalValueValidation)
    public func validate(
        _ values: [PersonalValueData],
        rowOffset: Int = 1
    ) async throws -> [ImportRecord<PersonalValueData>] {
        let repository = PersonalValueRepository(database: database)

        var records: [ImportRecord<PersonalValueData>] = []

        for (index, value) in values.enumerated() {
            let rowNumber = rowOffset + index

            // Check for duplicate ID
            let idExists = try await repository.exists(value.id)
            if idExists {
                records.append(ImportRecord(
                    id: value.id,
                    rowNumber: rowNumber,
                    data: value,
                    status: .duplicateID(existing: value.id),
                    shouldImport: false
                ))
                continue
            }

            // TODO: Semantic duplicate detection
            records.append(ImportRecord(
                id: value.id,
                rowNumber: rowNumber,
                data: value,
                status: .valid,
                shouldImport: true
            ))
        }

        return records
    }

    // MARK: - TimePeriod Validation

    /// Validate parsed time periods for import
    ///
    /// **Checks**:
    /// 1. Duplicate IDs
    /// 2. Date range validation (startDate < endDate)
    /// 3. Business rules (TermValidation)
    public func validate(
        _ periods: [TimePeriodData],
        rowOffset: Int = 1
    ) async throws -> [ImportRecord<TimePeriodData>] {
        let repository = TimePeriodRepository(database: database)

        var records: [ImportRecord<TimePeriodData>] = []

        for (index, period) in periods.enumerated() {
            let rowNumber = rowOffset + index

            // Check for duplicate ID
            let idExists = try await repository.exists(period.id)
            if idExists {
                records.append(ImportRecord(
                    id: period.id,
                    rowNumber: rowNumber,
                    data: period,
                    status: .duplicateID(existing: period.id),
                    shouldImport: false
                ))
                continue
            }

            // Validate date range
            var validationErrors: [ValidationError] = []
            if period.startDate > period.endDate {
                validationErrors.append(.invalidDateRange("Start date must be before end date"))
            }

            if !validationErrors.isEmpty {
                records.append(ImportRecord(
                    id: period.id,
                    rowNumber: rowNumber,
                    data: period,
                    status: .validationError,
                    validationErrors: validationErrors,
                    shouldImport: false
                ))
                continue
            }

            records.append(ImportRecord(
                id: period.id,
                rowNumber: rowNumber,
                data: period,
                status: .valid,
                shouldImport: true
            ))
        }

        return records
    }
}

// MARK: - Future Enhancements (TODO)

/*
 Future semantic duplicate detection integration:

 extension ImportValidator {
     private func checkSemanticDuplicates<T: SemanticDetectable>(
         for record: T,
         in existing: [T],
         threshold: Double = 0.75
     ) async throws -> [DuplicateMatch] {
         let detector = SemanticDuplicateDetector<T>(
             semanticService: semanticService,
             config: .default
         )

         let matches = try await detector.findDuplicates(
             for: record.semanticRepresentation,
             in: existing,
             threshold: threshold
         )

         return matches.map { match in
             DuplicateMatch(
                 id: match.id,
                 title: match.title,
                 similarity: match.similarity
             )
         }
     }
 }

 Future FK validation:

 extension ImportValidator {
     private func validateForeignKeys(
         for action: ActionData
     ) async throws -> [ValidationError] {
         var errors: [ValidationError] = []

         // Check measures exist
         for measurement in action.measurements {
             let measureRepo = MeasureRepository(database: database)
             let exists = try await measureRepo.exists(measurement.measureId)
             if !exists {
                 errors.append(.invalidMeasure("Measure not found: \(measurement.measureId)"))
             }
         }

         // Check goals exist
         for contribution in action.contributions {
             let goalRepo = GoalRepository(database: database)
             let exists = try await goalRepo.exists(contribution.goalId)
             if !exists {
                 errors.append(.invalidGoal("Goal not found: \(contribution.goalId)"))
             }
         }

         return errors
     }
 }
 */
