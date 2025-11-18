import Foundation
import Models

/// Form data for Measure creation and editing.
///
/// **Purpose**: Transfer object between UI layer and Coordinator layer
/// - UI → FormData: SwiftUI form @State variables assembled into struct
/// - FormData → Coordinator: Passed to create/update methods
/// - Validation: Happens in Coordinator, not in this struct
///
/// **Design**: Parallel to PersonalValueFormData (simplest FormData pattern)
/// - Measure is Abstraction Layer entity (catalog of measurement units)
/// - No relationships to other entities (pure catalog)
/// - Simple validation: unit + measureType compound uniqueness
///
/// **Ontological Distinction**:
/// - MeasureFormData = Creating/editing catalog units ("km", "hours", "occasions")
/// - ExpectationMeasureFormData = Creating goal targets ("120 km by June 1")
///
/// **Sendable**: Thread-safe for passing across actor boundaries
public struct MeasureFormData: Sendable {
    // MARK: - Required Fields (Core Identity)

    /// Display title for the measure
    /// Example: "Kilometers", "Hours", "Occasions"
    public let title: String

    /// Unit abbreviation (used in data storage and display)
    /// Example: "km", "hours", "occasions"
    /// NOTE: Part of compound uniqueness key (unit + measureType)
    public let unit: String

    /// Type of measurement
    /// Example: "distance", "time", "count", "energy"
    /// NOTE: Part of compound uniqueness key (unit + measureType)
    public let measureType: String

    // MARK: - Optional Fields (Metadata)

    /// Detailed description of what this measure represents
    /// Example: "Distance traveled by running or cycling"
    public let detailedDescription: String?

    /// Freeform notes (user-specific context)
    /// Example: "Use this for all cardio activities"
    public let freeformNotes: String?

    // MARK: - Unit Conversion Support (Optional)

    /// Canonical unit for conversion (if applicable)
    /// Example: "meters" (for km conversion), "seconds" (for hours conversion)
    /// NOTE: Leave nil if unit doesn't convert (e.g., "count" type measures)
    public let canonicalUnit: String?

    /// Conversion factor to canonical unit
    /// Example: 1000.0 (km → meters), 3600.0 (hours → seconds)
    /// NOTE: Leave nil if canonicalUnit is nil
    public let conversionFactor: Double?

    // MARK: - Initialization

    public init(
        title: String,
        unit: String,
        measureType: String,
        detailedDescription: String? = nil,
        freeformNotes: String? = nil,
        canonicalUnit: String? = nil,
        conversionFactor: Double? = nil
    ) {
        self.title = title
        self.unit = unit
        self.measureType = measureType
        self.detailedDescription = detailedDescription
        self.freeformNotes = freeformNotes
        self.canonicalUnit = canonicalUnit
        self.conversionFactor = conversionFactor
    }
}