//
// TimePeriodFormViewModel.swift
// Written by Claude Code on 2025-11-02
//
// PURPOSE: Generic ViewModel for TimePeriod creation (works with all specializations)
// ARCHITECTURE: Generic ViewModel, type-specific views provide specialization
//

import Dependencies
import Foundation
import Models
import Observation
import SQLiteData
import Services
import SwiftUI

/// Generic ViewModel for TimePeriod form operations.
///
/// ARCHITECTURE DECISION: Generic ViewModel + Type-Specific Views
/// - This ViewModel works with ANY TimePeriodSpecialization
/// - Type-specific views (TermFormView, YearFormView) wrap this with pre-configured type
/// - Keeps ViewModel simple, views handle user-friendly specialization
///
/// PATTERN: Based on PersonalValuesFormViewModel
/// - @Observable (not ObservableObject)
/// - @Dependency(\.defaultDatabase) with @ObservationIgnored
/// - Individual parameters (not FormData object) for ergonomic SwiftUI binding
@Observable
@MainActor
public final class TimePeriodFormViewModel {
    public var isSaving: Bool = false
    public var errorMessage: String?

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    // ARCHITECTURE DECISION: Lazy stored property with @ObservationIgnored
    // CONTEXT: Swift 6 strict concurrency - coordinators are now non-isolated
    // PATTERN: Use lazy var with @ObservationIgnored for multi-method coordinator usage
    // WHY LAZY: Coordinator used in multiple methods (save, update, delete)
    // WHY @ObservationIgnored: Coordinators are stateless services, no observable state
    // RESULT: Coordinator created once on first use, safe across all async methods
    @ObservationIgnored
    private lazy var coordinator: TimePeriodCoordinator = {
        TimePeriodCoordinator(database: database)
    }()

    public init() {}

    /// Saves TimePeriod with specialization.
    /// - Parameters: Individual form fields (more ergonomic than FormData object)
    /// - Returns: Persisted TimePeriod
    /// - Throws: Database errors
    public func save(
        startDate: Date,
        targetDate: Date,
        specialization: TimePeriodSpecialization,
        title: String? = nil,
        description: String? = nil,
        notes: String? = nil,
        theme: String? = nil,
        reflection: String? = nil,
        status: TermStatus? = nil
    ) async throws -> TimePeriod {
        isSaving = true
        defer { isSaving = false }

        let formData = TimePeriodFormData(
            title: title,
            detailedDescription: description,
            freeformNotes: notes,
            startDate: startDate,
            targetDate: targetDate,
            specialization: specialization,
            theme: theme,
            reflection: reflection,
            status: status
        )

        do {
            let timePeriod = try await coordinator.create(from: formData)
            errorMessage = nil
            return timePeriod
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Updates existing TimePeriod with specialization.
    /// - Parameters: Existing time period data (canonical type) + updated form fields
    /// - Returns: Updated TimePeriod
    /// - Throws: Database errors
    public func update(
        timePeriodData: TimePeriodData,
        startDate: Date,
        targetDate: Date,
        specialization: TimePeriodSpecialization,
        title: String? = nil,
        description: String? = nil,
        notes: String? = nil,
        theme: String? = nil,
        reflection: String? = nil,
        status: TermStatus? = nil
    ) async throws -> TimePeriod {
        isSaving = true
        defer { isSaving = false }

        let formData = TimePeriodFormData(
            title: title,
            detailedDescription: description,
            freeformNotes: notes,
            startDate: startDate,
            targetDate: targetDate,
            specialization: specialization,
            theme: theme,
            reflection: reflection,
            status: status
        )

        do {
            // Reconstruct TimePeriod entity from TimePeriodData
            let timePeriod = TimePeriod(
                title: timePeriodData.timePeriodTitle,
                detailedDescription: nil,  // Not stored in TimePeriodData
                freeformNotes: nil,  // Not stored in TimePeriodData
                startDate: timePeriodData.startDate,
                endDate: timePeriodData.endDate,
                logTime: Date(),  // Will be preserved by coordinator
                id: timePeriodData.timePeriodId
            )

            // Reconstruct GoalTerm entity from TimePeriodData
            let goalTerm = GoalTerm(
                timePeriodId: timePeriodData.timePeriodId,
                termNumber: timePeriodData.termNumber,
                theme: timePeriodData.theme,
                reflection: timePeriodData.reflection,
                status: timePeriodData.termStatus ?? .planned,
                id: timePeriodData.id
            )

            let updatedTimePeriod = try await coordinator.update(
                timePeriod: timePeriod,
                goalTerm: goalTerm,
                from: formData
            )
            errorMessage = nil
            return updatedTimePeriod
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Deletes TimePeriod and its specialization.
    /// - Parameters: Entities to delete
    /// - Throws: Database errors (e.g., if Term has goal assignments)
    public func delete(
        timePeriodData: TimePeriodData
    ) async throws {
        isSaving = true
        defer { isSaving = false }

        do {
            try await coordinator.delete(timePeriodData)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
