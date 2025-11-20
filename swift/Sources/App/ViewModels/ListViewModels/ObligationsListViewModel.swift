//
// ObligationsListViewModel.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: ViewModel for Obligations list view
// PATTERN: @Observable with Repository pattern, following MilestonesListViewModel
//

import Dependencies
import Foundation
import Models
import Observation
import Services
import SQLiteData

/// ViewModel for Obligations list view
///
/// **Pattern**: @Observable with Repository + Coordinator
/// **Dependencies**: @Dependency(\.defaultDatabase) with @ObservationIgnored
/// **Responsibilities**:
/// - loadObligations() fetches all obligations with expectation details
/// - deleteObligation() removes obligation and reloads list
/// - Handles loading states and errors with user-friendly messages
///
/// **Usage in View**:
/// ```swift
/// @State private var viewModel = ObligationsListViewModel()
///
/// .task {
///     await viewModel.loadObligations()
/// }
///
/// .refreshable {
///     await viewModel.loadObligations()
/// }
/// ```
@Observable
@MainActor
public final class ObligationsListViewModel {
    // MARK: - Observable State (internal - accessed only by corresponding view)

    var obligations: [ObligationWithDetails] = []
    var isLoading: Bool = false
    var errorMessage: String?

    var hasError: Bool { errorMessage != nil }

    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    private lazy var repository: ObligationRepository = {
        ObligationRepository(database: database)
    }()

    @ObservationIgnored
    private lazy var coordinator: ObligationCoordinator = {
        ObligationCoordinator(database: database)
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Actions

    /// Load all obligations from repository
    ///
    /// **Flow**:
    /// 1. Set isLoading = true (show progress view)
    /// 2. Fetch obligations from repository - switches to background for I/O
    /// 3. Update obligations array - Swift switches back to main actor
    /// 4. Set isLoading = false (hide progress view)
    ///
    /// **Error Handling**:
    /// - ValidationError: User-friendly message from repository
    /// - DatabaseError: Generic fallback message
    ///
    /// **Usage**: Call in .task or .refreshable modifier
    public func loadObligations() async {
        isLoading = true
        errorMessage = nil

        do {
            obligations = try await repository.fetchAll()
        } catch let error as ValidationError {
            // User-friendly validation messages (e.g., "Database constraint violated")
            errorMessage = error.userMessage
            print("❌ ObligationsListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic fallback for unexpected errors
            errorMessage = "Failed to load obligations: \(error.localizedDescription)"
            print("❌ ObligationsListViewModel: \(error)")
        }

        isLoading = false
    }

    /// Delete obligation and reload list
    ///
    /// **Flow**:
    /// 1. Set isLoading = true (show progress view)
    /// 2. Call coordinator.delete() - switches to background for I/O
    /// 3. Reload obligations if successful - Swift switches back to main actor
    /// 4. Set isLoading = false (hide progress view)
    ///
    /// **Error Handling**:
    /// - ValidationError: User-friendly message
    /// - DatabaseError: Generic fallback message
    ///
    /// **Usage**: Call in .onDelete or swipe-to-delete handler
    public func deleteObligation(_ obligation: ObligationWithDetails) async {
        isLoading = true
        errorMessage = nil

        do {
            try await coordinator.delete(obligationId: obligation.id)
            // Reload list after successful deletion
            await loadObligations()
        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ ObligationsListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic fallback for unexpected errors
            errorMessage = "Failed to delete obligation: \(error.localizedDescription)"
            print("❌ ObligationsListViewModel: \(error)")
        }

        isLoading = false
    }
}
