//
// ObligationFormViewModel.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: ViewModel for Obligation forms (create + edit)
// PATTERN: @Observable with @Dependency, following MilestoneFormViewModel
//

import Dependencies
import Foundation
import Models
import Observation
import Services
import SQLiteData

/// ViewModel for Obligation forms
///
/// **Pattern**: @Observable (not ObservableObject)
/// **Dependencies**: @Dependency(\.defaultDatabase) with @ObservationIgnored
/// **Responsibilities**:
/// - save() creates new Obligation + Expectation
/// - update() updates existing Obligation + Expectation
///
/// **Usage in View**:
/// ```swift
/// @State private var viewModel = ObligationFormViewModel()
///
/// Button("Save") {
///     try await viewModel.save(from: formData)
/// }
/// ```
@Observable
@MainActor
public final class ObligationFormViewModel {
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
    private lazy var coordinator: ObligationCoordinator = {
        ObligationCoordinator(database: database)
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Actions

    /// Save new obligation from form data
    ///
    /// **Flow**:
    /// 1. Set isSaving = true (show loading indicator)
    /// 2. Call coordinator.create(from:) - switches to background for I/O
    /// 3. Return obligation - Swift switches back to main actor
    /// 4. Clear error message on success
    /// 5. Set isSaving = false (hide loading indicator)
    ///
    /// **Error Handling**:
    /// - ValidationError: User-friendly message (e.g., "Title is required")
    /// - DatabaseError: Generic fallback message
    ///
    /// - Parameter formData: Validated obligation form data
    /// - Returns: Created Obligation entity
    /// - Throws: ValidationError or DatabaseError (propagates to caller)
    public func save(from formData: ObligationFormData) async throws -> Obligation {
        isSaving = true
        defer { isSaving = false }

        do {
            let obligation = try await coordinator.create(from: formData)
            errorMessage = nil
            return obligation
        } catch let error as ValidationError {
            errorMessage = error.userMessage
            print("❌ ObligationFormViewModel ValidationError: \(error.userMessage)")
            throw error
        } catch {
            errorMessage = "Failed to save obligation: \(error.localizedDescription)"
            print("❌ ObligationFormViewModel: \(error)")
            throw error
        }
    }

    /// Update existing obligation from form data
    ///
    /// **Flow**: Same as save() but calls coordinator.update()
    ///
    /// - Parameters:
    ///   - obligation: Existing obligation to update
    ///   - formData: New form data
    /// - Returns: Updated Obligation entity
    /// - Throws: ValidationError or DatabaseError
    public func update(
        obligation: Obligation,
        from formData: ObligationFormData
    ) async throws -> Obligation {
        isSaving = true
        defer { isSaving = false }

        do {
            let updatedObligation = try await coordinator.update(obligation: obligation, from: formData)
            errorMessage = nil
            return updatedObligation
        } catch let error as ValidationError {
            errorMessage = error.userMessage
            print("❌ ObligationFormViewModel ValidationError: \(error.userMessage)")
            throw error
        } catch {
            errorMessage = "Failed to update obligation: \(error.localizedDescription)"
            print("❌ ObligationFormViewModel: \(error)")
            throw error
        }
    }
}
