//
// TermsListViewModel.swift
// Written by Claude Code on 2025-11-13
//
// PURPOSE:
// ViewModel for TermsListView - manages terms list state and repository access.
// Eliminates @Fetch(TermsWithPeriods()) pattern in favor of direct repository access.
//
// ARCHITECTURE PATTERN:
// - @Observable for automatic UI updates (NOT ObservableObject)
// - @MainActor for UI thread safety
// - Lazy repository pattern for data access
// - Follows patterns from GoalsListViewModel.swift and PersonalValuesListViewModel.swift
//
// DATA FLOW:
// TimePeriodRepository → TermsListViewModel → TermsListView
//
// DESIGN NOTE:
// Terms have simple 1:1 relationship with TimePeriod (no child relationships to aggregate).
// Repository uses query builder pattern (already established), no JSON aggregation needed.
//

import Foundation
import Observation
import Dependencies
import Services
import Models

/// ViewModel for TermsListView
///
/// **PATTERN**: Modern Swift 6 ViewModel
/// - Uses @Observable (Swift 5.9+) not ObservableObject
/// - @MainActor ensures UI updates on main thread
/// - Lazy repository pattern for efficient data access
///
/// **RESPONSIBILITIES**:
/// - Fetch terms from repository
/// - Handle loading/error states
/// - Provide data to view
/// - Manage delete operations
/// - Calculate next term number
///
/// **USAGE**:
/// ```swift
/// @State private var viewModel = TermsListViewModel()
///
/// .task {
///     await viewModel.loadTerms()
/// }
/// .refreshable {
///     await viewModel.loadTerms()
/// }
/// ```
@Observable
@MainActor
public final class TermsListViewModel {

    // MARK: - Observable State (internal visibility)

    /// Terms data for display (canonical type)
    var terms: [TimePeriodData] = []

    /// Loading state for UI feedback
    var isLoading: Bool = false

    /// Error message for user display
    var errorMessage: String?

    // MARK: - Computed Properties

    /// Whether there's an error to display
    var hasError: Bool {
        errorMessage != nil
    }

    /// Calculate next term number from existing terms
    var nextTermNumber: Int {
        let maxTermNumber = terms.map { $0.termNumber }.max() ?? 0
        return maxTermNumber + 1
    }

    // MARK: - Dependencies (not observable)

    /// Database dependency
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    /// Repository for data access (lazy initialization)
    @ObservationIgnored
    private lazy var repository: TimePeriodRepository = {
        TimePeriodRepository(database: database)
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Data Loading

    /// Load all terms from repository
    ///
    /// Used for both initial load (.task) and refresh (.refreshable)
    /// Automatically updates observable properties which trigger UI updates.
    ///
    /// **Performance**: Single query with 1:1 JOIN (no aggregation needed)
    /// **Concurrency**: Runs on background thread via repository, returns to main actor
    public func loadTerms() async {
        isLoading = true
        errorMessage = nil

        do {
            terms = try await repository.fetchAll()
        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ TermsListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic error fallback
            errorMessage = "Failed to load terms: \(error.localizedDescription)"
            print("❌ TermsListViewModel: \(error)")
        }

        isLoading = false
    }

    /// Delete a term and reload the list
    ///
    /// - Parameter termData: The term data to delete
    ///
    /// **Implementation**: Uses TimePeriodCoordinator for atomic delete
    /// **Side Effects**: Reloads terms list after successful deletion
    public func deleteTerm(_ termData: TimePeriodData) async {
        isLoading = true
        errorMessage = nil

        do {
            // Transform TimePeriodData to entities for coordinator
            let termWithPeriod = termData.asWithPeriod

            // Use coordinator for atomic delete
            let coordinator = TimePeriodCoordinator(database: database)
            try await coordinator.delete(
                timePeriod: termWithPeriod.timePeriod,
                goalTerm: termWithPeriod.term
            )

            // Reload list after successful delete
            await loadTerms()
        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ TermsListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic error fallback
            errorMessage = "Failed to delete term: \(error.localizedDescription)"
            print("❌ TermsListViewModel: \(error)")
        }

        isLoading = false
    }
}
