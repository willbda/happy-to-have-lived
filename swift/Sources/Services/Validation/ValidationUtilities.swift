// ValidationUtilities.swift
// Written by Claude Code on 2025-11-09
//
// PURPOSE:
// Single unified validator with generalized validation functions.
// Provides reusable validation primitives that throw errors with helpful messages.
//
// ARCHITECTURE POSITION:
// Foundation layer - depends on ValidationError, used by all validators.

import Foundation

/// Unified validation utilities
public enum ValidationUtilities {

    // MARK: - 1. Field Has Value (Content Validation)
    ///
    /// - Parameters:
    ///   - field: Optional string to validate
    ///   - fieldName: Name of field for error message
    ///
    /// **Usage**:
    /// ```swift
    /// try requireFieldHasValue(formData.title, field: "Title")
    /// // Throws: "Non-empty value required for Title"
    /// ```
    public static func requireFieldHasValue(_ field: String?, field fieldName: String) throws {
        guard let field = field, !field.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyValue("Non-empty value required for \(fieldName)")
        }
    }

    /// Require that at least one field has meaningful content
    ///
    /// **Generalizes**: OR validation across multiple fields
    ///
    /// - Parameters:
    ///   - fields: Array of (value, name) tuples to check
    ///   - entityName: Name of entity for error message (e.g., "Action")
    /// - Throws: ValidationError.emptyValue if all fields are empty
    ///
    /// **Usage**:
    /// ```swift
    /// try requireAnyFieldHasValue(
    ///     [(formData.title, "title"), (formData.description, "description")],
    ///     entity: "Action"
    /// )
    /// // Throws: "Action must have at least one of: title, description"
    /// ```
    public static func requireAnyFieldHasValue(
        _ fields: [(String?, String)],
        entity entityName: String
    ) throws {
        let hasValue = fields.contains { field, _ in
            guard let field = field, !field.trimmingCharacters(in: .whitespaces).isEmpty else {
                return false
            }
            return true
        }

        guard hasValue else {
            let fieldNames = fields.map { $0.1 }.joined(separator: ", ")
            throw ValidationError.emptyValue(
                "\(entityName) must have at least one of: \(fieldNames)"
            )
        }
    }

    // MARK: - 2. Field Value In Range (Bounds Validation)

    /// Require value is within valid range
    ///
    /// - Parameters:
    ///   - value: Value to check
    ///   - range: Valid range (e.g., 1...10, 1...100)
    ///   - fieldName: Name of field for error message
    /// - Throws: ValidationError.invalidPriority if value out of range
    ///
    /// **Usage**:
    /// ```swift
    /// try requireFieldInRange(formData.priority, 1...100, field: "Priority")
    /// // Throws: "Invalid range 1-100 for Priority, got 150"
    /// ```
    public static func requireFieldInRange<T: Comparable & CustomStringConvertible>(
        _ value: T,
        _ range: ClosedRange<T>,
        field fieldName: String
    ) throws {
        guard range.contains(value) else {
            throw ValidationError.invalidPriority(
                "Invalid range \(range.lowerBound)-\(range.upperBound) for \(fieldName), got \(value)"
            )
        }
    }

    /// Require value is within partial range (unbounded upper limit)
    ///
    /// - Parameters:
    ///   - value: Value to check
    ///   - range: Partial range (e.g., 0... for non-negative, 1... for positive)
    ///   - fieldName: Name of field for error message
    /// - Throws: ValidationError.invalidExpectation if value out of range
    ///
    /// **Usage**:
    /// ```swift
    /// try requireFieldInRange(formData.targetValue, 1..., field: "Target value")
    /// // Throws: "Invalid range >=1 for Target value, got -5"
    /// ```
    public static func requireFieldInRange<T: Comparable & CustomStringConvertible>(
        _ value: T,
        _ range: PartialRangeFrom<T>,
        field fieldName: String
    ) throws {
        guard range.contains(value) else {
            throw ValidationError.invalidExpectation(
                "Invalid range >=\(range.lowerBound) for \(fieldName), got \(value)"
            )
        }
    }

    /// Require optional value is in range (nil is valid)
    ///
    /// - Parameters:
    ///   - value: Optional value to check
    ///   - range: Valid range
    ///   - fieldName: Name of field for error message
    /// - Throws: ValidationError.invalidPriority if value out of range
    ///
    /// **Usage**:
    /// ```swift
    /// try requireFieldInRange(formData.priority, 1...100, field: "Priority")
    /// // Nil is OK, but if provided must be in range
    /// ```
    public static func requireFieldInRange<T: Comparable & CustomStringConvertible>(
        _ value: T?,
        _ range: ClosedRange<T>,
        field fieldName: String
    ) throws {
        guard let value = value else { return }
        try requireFieldInRange(value, range, field: fieldName)
    }

    /// Require all items in collection have values in range
    ///
    /// - Parameters:
    ///   - items: Collection of items to check
    ///   - range: Valid range
    ///   - keyPath: KeyPath to the value property
    ///   - fieldName: Name of field for error message
    /// - Throws: ValidationError if any item out of range
    ///
    /// **Usage**:
    /// ```swift
    /// try requireFieldInRange(
    ///     formData.measureTargets,
    ///     1...,
    ///     keyPath: \.targetValue,
    ///     field: "Metric target values"
    /// )
    /// // Throws: "Invalid range >=1 for Metric target values, got -10"
    /// ```
    public static func requireFieldInRange<T, V: Comparable & CustomStringConvertible>(
        _ items: [T],
        _ range: ClosedRange<V>,
        keyPath: KeyPath<T, V>,
        field fieldName: String
    ) throws {
        for item in items {
            let value = item[keyPath: keyPath]
            guard range.contains(value) else {
                throw ValidationError.invalidPriority(
                    "Invalid range \(range.lowerBound)-\(range.upperBound) for \(fieldName), got \(value)"
                )
            }
        }
    }

    public static func requireFieldInRange<T, V: Comparable & CustomStringConvertible>(
        _ items: [T],
        _ range: PartialRangeFrom<V>,
        keyPath: KeyPath<T, V>,
        field fieldName: String
    ) throws {
        for item in items {
            let value = item[keyPath: keyPath]
            guard range.contains(value) else {
                throw ValidationError.invalidExpectation(
                    "Invalid range >=\(range.lowerBound) for \(fieldName), got \(value)"
                )
            }
        }
    }

    // MARK: - 3. Field Value Identical (Equality Validation)

    /// Require that two values are identical
    ///
    /// **Generalizes**: ID matching, reference consistency
    ///
    /// - Parameters:
    ///   - value1: First value
    ///   - value2: Second value
    ///   - field1Name: Name of first field
    ///   - field2Name: Name of second field
    /// - Throws: ValidationError.inconsistentReference if values don't match
    ///
    /// **Usage**:
    /// ```swift
    /// try requireFieldsMatch(goal.expectationId, expectation.id,
    ///                        field1: "Goal.expectationId", field2: "Expectation.id")
    /// // Throws: "Inconsistent reference: Goal.expectationId must match Expectation.id"
    /// ```
    public static func requireFieldsMatch<T: Equatable & CustomStringConvertible>(
        _ value1: T,
        _ value2: T,
        field1 field1Name: String,
        field2 field2Name: String
    ) throws {
        guard value1 == value2 else {
            throw ValidationError.inconsistentReference(
                "Inconsistent reference: \(field1Name) must match \(field2Name)"
            )
        }
    }

    /// Require that all items in collection have matching foreign key
    ///
    /// - Parameters:
    ///   - items: Collection to check
    ///   - expectedValue: Value that all items should match
    ///   - keyPath: KeyPath to the property to check
    ///   - itemName: Name of item type (e.g., "Measurements")
    ///   - fieldName: Name of field being checked (e.g., "actionId")
    /// - Throws: ValidationError.inconsistentReference if any item doesn't match
    ///
    /// **Usage**:
    /// ```swift
    /// try requireFieldsMatch(
    ///     measurements,
    ///     expectedValue: action.id,
    ///     keyPath: \.actionId,
    ///     items: "Measurements",
    ///     field: "actionId"
    /// )
    /// // Throws: "Inconsistent reference: All Measurements must have matching actionId"
    /// ```
    public static func requireFieldsMatch<T, V: Equatable>(
        _ items: [T],
        expectedValue: V,
        keyPath: KeyPath<T, V>,
        items itemName: String,
        field fieldName: String
    ) throws {
        for item in items {
            guard item[keyPath: keyPath] == expectedValue else {
                throw ValidationError.inconsistentReference(
                    "Inconsistent reference: All \(itemName) must have matching \(fieldName)"
                )
            }
        }
    }

    /// Require that all values in collection are unique (no duplicates)
    ///
    /// - Parameters:
    ///   - items: Collection to check
    ///   - keyPath: KeyPath to the property to check for uniqueness
    ///   - itemName: Name of item type (e.g., "Measurements")
    ///   - fieldName: Name of field being checked (e.g., "measureId")
    /// - Throws: ValidationError.duplicateRecord if duplicates found
    ///
    /// **Usage**:
    /// ```swift
    /// try requireFieldsUnique(
    ///     measurements,
    ///     keyPath: \.measureId,
    ///     items: "Measurements",
    ///     field: "measureId"
    /// )
    /// // Throws: "Duplicate record: Multiple Measurements with same measureId"
    /// ```
    public static func requireFieldsUnique<T, V: Hashable>(
        _ items: [T],
        keyPath: KeyPath<T, V>,
        items itemName: String,
        field fieldName: String
    ) throws {
        let values = items.map { $0[keyPath: keyPath] }
        let uniqueValues = Set(values)

        guard values.count == uniqueValues.count else {
            throw ValidationError.duplicateRecord(
                "Duplicate record: Multiple \(itemName) with same \(fieldName)"
            )
        }
    }

    // MARK: - 4. Field Date Invalid (Temporal Validation)

    /// Require date is not in future
    ///
    /// **Use case**: Action start times, log timestamps (past/present only)
    ///
    /// - Parameters:
    ///   - date: Date to validate
    ///   - fieldName: Name of field for error message
    /// - Throws: ValidationError.invalidDateRange if date is in future
    ///
    /// **Usage**:
    /// ```swift
    /// try requireDateNotInFuture(formData.startTime, field: "Start time")
    /// // Throws: "Invalid date for Start time: cannot be in future"
    /// ```
    public static func requireDateNotInFuture(_ date: Date, field fieldName: String) throws {
        guard date <= Date() else {
            throw ValidationError.invalidDateRange(
                "Invalid date for \(fieldName): cannot be in future"
            )
        }
    }

    /// Require date range is valid (start before/equal to end)
    ///
    /// - Parameters:
    ///   - start: Start date
    ///   - end: End date
    ///   - startName: Name of start field
    ///   - endName: Name of end field
    ///   - allowEqual: Whether start == end is valid (default: true)
    /// - Throws: ValidationError.invalidDateRange if start > end
    ///
    /// **Usage**:
    /// ```swift
    /// try requireValidDateRange(
    ///     formData.startDate,
    ///     formData.targetDate,
    ///     start: "Start date",
    ///     end: "Target date"
    /// )
    /// // Throws: "Invalid date range: Start date must be before Target date"
    /// ```
    public static func requireValidDateRange(
        _ start: Date,
        _ end: Date,
        start startName: String,
        end endName: String,
        allowEqual: Bool = true
    ) throws {
        let isInvalid = allowEqual ? (start > end) : (start >= end)

        guard !isInvalid else {
            let comparison = allowEqual ? "before or equal to" : "before"
            throw ValidationError.invalidDateRange(
                "Invalid date range: \(startName) must be \(comparison) \(endName)"
            )
        }
    }

    /// Require optional date range is valid (nil dates are OK)
    ///
    /// - Parameters:
    ///   - start: Optional start date
    ///   - end: Optional end date
    ///   - startName: Name of start field
    ///   - endName: Name of end field
    ///   - allowEqual: Whether start == end is valid (default: true)
    /// - Throws: ValidationError.invalidDateRange if both dates present and start > end
    ///
    /// **Usage**:
    /// ```swift
    /// try requireValidDateRange(
    ///     formData.startDate,
    ///     formData.targetDate,
    ///     start: "Start date",
    ///     end: "Target date"
    /// )
    /// // Nil dates are OK, but if both present must be valid range
    /// ```
    public static func requireValidDateRange(
        _ start: Date?,
        _ end: Date?,
        start startName: String,
        end endName: String,
        allowEqual: Bool = true
    ) throws {
        guard let start = start, let end = end else { return }
        try requireValidDateRange(
            start, end, start: startName, end: endName, allowEqual: allowEqual)
    }
}

// MARK: - Sendable Conformance

// ValidationUtilities is Sendable because:
// - It's an enum with only static methods (no stored properties)
// - All methods are pure functions (no mutable state)
// - Safe to use from any actor context
extension ValidationUtilities: Sendable {}
