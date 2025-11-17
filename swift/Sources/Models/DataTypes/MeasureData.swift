//
// MeasureData.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// Canonical measure data structure that serves both display and export needs.
// Simplest Data type - Measure is a catalog/lookup table with no complex relationships.
//
// DESIGN:
// - ONE struct for all use cases (not 2+ separate types)
// - Flat structure with Measure fields only (no relationships to aggregate)
// - Codable for direct JSON/CSV export
// - Even simpler than PersonalValueData (no relationship tracking needed)
//

import Foundation

/// Canonical measure data structure - serves both display and export needs
///
/// **Design Philosophy**:
/// - ONE struct to rule them all (not multiple separate types)
/// - Codable for JSON/CSV export
/// - Sendable for Swift 6 concurrency
/// - Identifiable + Hashable for SwiftUI
/// - Flat structure (Measure has no outbound relationships)
///
/// **Usage**:
/// ```swift
/// // Repository returns this
/// let measures = try await repository.fetchAll()
///
/// // Export uses directly
/// let json = try JSONEncoder().encode(measures)
///
/// // Views use directly (no transformation needed)
/// List(measures) { measure in
///     MeasureRow(measure: measure)
/// }
/// ```
public struct MeasureData: Identifiable, Hashable, Sendable, Codable {
    // MARK: - Core Identity

    public let id: UUID  // Measure ID (primary key)

    // MARK: - Measure Fields (from measures table)

    public let title: String?
    public let detailedDescription: String?
    public let freeformNotes: String?
    public let logTime: Date

    // MARK: - Measurement Specification

    /// Unit of measurement (e.g., "km", "hours", "occasions")
    /// Required field - basis for duplicate detection
    public let unit: String

    /// Type of measurement (e.g., "distance", "time", "count")
    /// Required field - combines with unit for uniqueness
    public let measureType: String

    /// Canonical unit for conversion (e.g., "meters" for "km")
    /// Optional - used for unit conversion calculations
    public let canonicalUnit: String?

    /// Conversion factor to canonical unit (e.g., 1000 for km->meters)
    /// Optional - used with canonicalUnit for conversions
    public let conversionFactor: Double?

    // MARK: - Initialization

    public init(
        id: UUID,
        title: String?,
        detailedDescription: String?,
        freeformNotes: String?,
        logTime: Date,
        unit: String,
        measureType: String,
        canonicalUnit: String?,
        conversionFactor: Double?
    ) {
        self.id = id
        self.title = title
        self.detailedDescription = detailedDescription
        self.freeformNotes = freeformNotes
        self.logTime = logTime
        self.unit = unit
        self.measureType = measureType
        self.canonicalUnit = canonicalUnit
        self.conversionFactor = conversionFactor
    }
}

// MARK: - CSV Export Support

extension MeasureData {
    /// Generate CSV row for this measure
    ///
    /// Provides flat representation suitable for spreadsheet import.
    public var csvRow: [String] {
        [
            id.uuidString.lowercased(),
            title ?? "",
            detailedDescription ?? "",
            freeformNotes ?? "",
            unit,
            measureType,
            canonicalUnit ?? "",
            conversionFactor.map { String(describing: $0) } ?? "",
            logTime.ISO8601Format(),
        ]
    }

    /// CSV header row
    public static var csvHeader: [String] {
        [
            "ID",
            "Title",
            "Description",
            "Notes",
            "Unit",
            "Measure Type",
            "Canonical Unit",
            "Conversion Factor",
            "Log Time",
        ]
    }
}

// MARK: - Display Helpers

extension MeasureData {
    /// Human-readable display title (uses title if present, otherwise generates from unit)
    public var displayTitle: String {
        title ?? unit
    }

    /// Full description for UI display (e.g., "Distance measured in km")
    public var fullDescription: String {
        "\(measureType.capitalized) measured in \(unit)"
    }
}
