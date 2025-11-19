//
// MilestoneFormViewModel.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: ViewModel for Milestone forms (create + edit)
// PATTERN: @Observable with @Dependency, following ActionFormViewModel
//

import Dependencies
import Foundation
import Models
import Observation
import Services
import SQLiteData

/// ViewModel for Milestone forms
///
/// **Pattern**: @Observable (not ObservableObject)
/// **Dependencies**: @Dependency(\.defaultDatabase) with @ObservationIgnored
/// **Responsibilities**:
/// - save() creates new Milestone + Expectation
/// - update() updates existing Milestone + Expectation
///
/// **Usage in View**:
/// ```swift
/// @State private var viewModel = MilestoneFormViewModel()
///
/// Button("Save") {
///     try await viewModel.save(from: formData)
/// }
/// ```
@Observable
@MainActor
public final class MilestoneFormViewModel {
    // MARK: - Published State

    public var isSaving: Bool = false
    public var errorMessage: String?

    public var hasError: Bool { errorMessage != nil }

    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    // SWIFT 6 CONCURRENCY PATTERN:
    // - ViewModel is @MainActor (manages UI state)
    // - Coordinator is Sendable, NOT @MainActor (database I/O runs in background)
    // - Use lazy var with @ObservationIgnored for coordinator storage
    @ObservationIgnored
    private lazy var coordinator: MilestoneCoordinator = {
        MilestoneCoordinator(database: database)
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Actions

    /// Save new milestone from form data
    ///
    /// **Flow**:
    /// 1. Set isSaving = true (show loading indicator)
    /// 2. Call coordinator.create(from:) - switches to background for I/O
    /// 3. Return milestone - Swift switches back to main actor
    /// 4. Clear error message on success
    /// 5. Set isSaving = false (hide loading indicator)
    ///
    /// **Error Handling**:
    /// - ValidationError: User-friendly message (e.g., "Title is required")
    /// - DatabaseError: Generic fallback message
    ///
    /// - Parameter formData: Validated milestone form data
    /// - Returns: Created Milestone entity
    /// - Throws: ValidationError or DatabaseError (propagates to caller)
    public func save(from formData: MilestoneFormData) async throws -> Milestone {
        isSaving = true
        defer { isSaving = false }

        do {
            let milestone = try await coordinator.create(from: formData)
            errorMessage = nil
            return milestone
        } catch let error as ValidationError {
            errorMessage = error.userMessage
            print("❌ MilestoneFormViewModel ValidationError: \(error.userMessage)")
            throw error
        } catch {
            errorMessage = "Failed to save milestone: \(error.localizedDescription)"
            print("❌ MilestoneFormViewModel: \(error)")
            throw error
        }
    }

    /// Update existing milestone from form data
    ///
    /// **Flow**: Same as save() but calls coordinator.update()
    ///
    /// - Parameters:
    ///   - milestone: Existing milestone to update
    ///   - formData: New form data
    /// - Returns: Updated Milestone entity
    /// - Throws: ValidationError or DatabaseError
    public func update(
        milestone: Milestone,
        from formData: MilestoneFormData
    ) async throws -> Milestone {
        isSaving = true
        defer { isSaving = false }

        do {
            let updatedMilestone = try await coordinator.update(milestone: milestone, from: formData)
            errorMessage = nil
            return updatedMilestone
        } catch let error as ValidationError {
            errorMessage = error.userMessage
            print("❌ MilestoneFormViewModel ValidationError: \(error.userMessage)")
            throw error
        } catch {
            errorMessage = "Failed to update milestone: \(error.localizedDescription)"
            print("❌ MilestoneFormViewModel: \(error)")
            throw error
        }
    }
}
