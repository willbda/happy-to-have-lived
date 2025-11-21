//
// TimePeriodFormData.swift
// Written by Claude Code on 2025-11-02
//
// PURPOSE: Form data structure for creating TimePeriod entities with specializations
//

import Foundation
import Models

/// Specialization types for TimePeriod (ontologically pure)
public enum TimePeriodSpecialization: Sendable {
    case term(number: Int)
    case year(yearNumber: Int)
    case custom
    // Future: case quarter(number: Int), case sprint(number: Int)
}

/// Form data for creating/updating TimePeriod with appropriate specialization
public struct TimePeriodFormData: Sendable {
    // TimePeriod fields
    public let title: String?
    public let detailedDescription: String?
    public let freeformNotes: String?
    public let startDate: Date
    public let targetDate: Date
    public let specialization: TimePeriodSpecialization

    // GoalTerm-specific fields (used when specialization = .term)
    public let theme: String?
    public let reflection: String?
    public let status: TermStatus?

    public init(
        title: String? = nil,
        detailedDescription: String? = nil,
        freeformNotes: String? = nil,
        startDate: Date,
        targetDate: Date,
        specialization: TimePeriodSpecialization,
        theme: String? = nil,
        reflection: String? = nil,
        status: TermStatus? = nil
    ) {
        self.title = title
        self.detailedDescription = detailedDescription
        self.freeformNotes = freeformNotes
        self.startDate = startDate
        self.targetDate = targetDate
        self.specialization = specialization
        self.theme = theme
        self.reflection = reflection
        self.status = status
    }

    /// Initialize form data from existing TimePeriodData (for editing)
    ///
    /// Maps all fields from TimePeriodData back to editable form structure.
    /// Used when user taps "Edit" on an existing term/time period.
    ///
    /// **Pattern**: TimePeriodData (display) → TimePeriodFormData (editing) → DataStore.updateTerm()
    ///
    /// **Usage**:
    /// ```swift
    /// struct TermFormView: View {
    ///     let termToEdit: TimePeriodData?
    ///     @State private var formData: TimePeriodFormData
    ///
    ///     init(termToEdit: TimePeriodData? = nil) {
    ///         if let term = termToEdit {
    ///             _formData = State(initialValue: TimePeriodFormData(from: term))
    ///         } else {
    ///             _formData = State(initialValue: TimePeriodFormData(
    ///                 startDate: Date(),
    ///                 targetDate: Date().addingTimeInterval(70 * 24 * 60 * 60),
    ///                 specialization: .term(number: 1)
    ///             ))
    ///         }
    ///     }
    /// }
    /// ```
    public init(from periodData: TimePeriodData) {
        // TimePeriod fields
        self.title = periodData.timePeriodTitle
        self.detailedDescription = nil  // Not stored in TimePeriodData
        self.freeformNotes = nil        // Not stored in TimePeriodData
        self.startDate = periodData.startDate
        self.targetDate = periodData.endDate

        // GoalTerm fields
        self.theme = periodData.theme
        self.reflection = periodData.reflection

        // Parse status string back to enum
        if let statusString = periodData.status {
            self.status = TermStatus(rawValue: statusString)
        } else {
            self.status = nil
        }

        // Reconstruct specialization from termNumber
        self.specialization = .term(number: periodData.termNumber)
    }
}
