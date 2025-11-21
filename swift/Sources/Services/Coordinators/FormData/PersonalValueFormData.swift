import Foundation
import Models

/// Form data for PersonalValue creation and editing.
///
/// **Naming**: PersonalValueFormData (not ValueFormData)
/// - "Value" is a reserved word in many contexts
/// - Clarity: explicitly identifies this as PersonalValue entity data
/// - Consistency: matches PersonalValue, PersonalValueValidator, PersonalValueCoordinator
///
/// **Purpose**: Transfer object between UI layer and Coordinator layer
/// - UI → FormData: SwiftUI form @State variables assembled into struct
/// - FormData → Coordinator: Passed to create/update methods
/// - Validation: Happens in Coordinator, not in this struct
///
/// **Sendable**: Thread-safe for passing across actor boundaries
public struct PersonalValueFormData: Sendable {
    public let title: String
    public let detailedDescription: String?
    public let freeformNotes: String?
    public let valueLevel: ValueLevel
    public let priority: Int?
    public let lifeDomain: String?
    public let alignmentGuidance: String?

    public init(
        title: String,
        detailedDescription: String? = nil,
        freeformNotes: String? = nil,
        valueLevel: ValueLevel,
        priority: Int? = nil,
        lifeDomain: String? = nil,
        alignmentGuidance: String? = nil
    ) {
        self.title = title
        self.detailedDescription = detailedDescription
        self.freeformNotes = freeformNotes
        self.valueLevel = valueLevel
        self.priority = priority
        self.lifeDomain = lifeDomain
        self.alignmentGuidance = alignmentGuidance
    }

    /// Initialize form data from existing PersonalValueData (for editing)
    ///
    /// Maps all fields from PersonalValueData back to editable form structure.
    /// Used when user taps "Edit" on an existing personal value.
    ///
    /// **Pattern**: PersonalValueData (display) → PersonalValueFormData (editing) → DataStore.updateValue()
    ///
    /// **Usage**:
    /// ```swift
    /// struct PersonalValuesFormView: View {
    ///     let valueToEdit: PersonalValueData?
    ///     @State private var formData: PersonalValueFormData
    ///
    ///     init(valueToEdit: PersonalValueData? = nil) {
    ///         if let value = valueToEdit {
    ///             _formData = State(initialValue: PersonalValueFormData(from: value))
    ///         } else {
    ///             _formData = State(initialValue: PersonalValueFormData(
    ///                 title: "",
    ///                 valueLevel: .general
    ///             ))
    ///         }
    ///     }
    /// }
    /// ```
    public init(from valueData: PersonalValueData) {
        self.title = valueData.title
        self.detailedDescription = valueData.detailedDescription
        self.freeformNotes = valueData.freeformNotes
        self.priority = valueData.priority
        self.lifeDomain = valueData.lifeDomain
        self.alignmentGuidance = valueData.alignmentGuidance

        // Parse valueLevel string back to enum
        self.valueLevel = ValueLevel(rawValue: valueData.valueLevel) ?? .general
    }
}
