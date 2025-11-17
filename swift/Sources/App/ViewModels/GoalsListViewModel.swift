//
// GoalsListViewModel.swift
// Written by Claude Code on 2025-11-13
// Updated on 2025-11-15 to use canonical GoalData type
//
// PURPOSE:
// ViewModel for GoalsListView - manages goals list state and repository access.
// Uses canonical GoalData type for both display and export.
//
// ARCHITECTURE PATTERN:
// - @Observable for automatic UI updates (NOT ObservableObject)
// - @MainActor for UI thread safety
// - Lazy repository pattern for data access
// - Canonical GoalData type (transforms to GoalWithDetails when needed)
//
// DATA FLOW:
// GoalRepository → GoalData → GoalsListViewModel → GoalsListView
//

import Foundation
import Observation
import Dependencies
import Services
import Models

/// ViewModel for GoalsListView
///
/// **PATTERN**: Modern Swift 6 ViewModel
/// - Uses @Observable (Swift 5.9+) not ObservableObject
/// - @MainActor ensures UI updates on main thread
/// - Lazy repository pattern for efficient data access
///
/// **RESPONSIBILITIES**:
/// - Fetch goals from repository
/// - Handle loading/error states
/// - Provide data to view
/// - Manage delete operations
///
/// **USAGE**:
/// ```swift
/// @State private var viewModel = GoalsListViewModel()
///
/// .task {
///     await viewModel.loadGoals()
/// }
/// .refreshable {
///     await viewModel.loadGoals()
/// }
/// ```
@Observable
@MainActor
public final class GoalsListViewModel {

    // MARK: - Observable State (internal visibility)

    /// Goals data for display (canonical GoalData type)
    /// Views can transform to GoalWithDetails using .asDetails if needed
    var goals: [GoalData] = []

    /// Loading state for UI feedback
    var isLoading: Bool = false

    /// Error message for user display
    var errorMessage: String?

    // MARK: - Computed Properties

    /// Whether there's an error to display
    var hasError: Bool {
        errorMessage != nil
    }

    // MARK: - Dependencies (not observable)

    /// Database dependency
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    /// Repository for data access (lazy initialization)
    @ObservationIgnored
    private lazy var repository: GoalRepository = {
        GoalRepository(database: database)
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Data Loading

    /// Load all goals from repository
    ///
    /// Used for both initial load (.task) and refresh (.refreshable)
    /// Returns canonical GoalData type for both display and export.
    ///
    /// **Performance**: Single JSON aggregation query (1 database round trip)
    /// **Concurrency**: Runs on background thread via repository, returns to main actor
    /// **NEW**: Uses fetchAllAsData() for canonical GoalData type
    public func loadGoals() async {
        isLoading = true
        errorMessage = nil

        do {
            goals = try await repository.fetchAll()
        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ GoalsListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic error fallback
            errorMessage = "Failed to load goals: \(error.localizedDescription)"
            print("❌ GoalsListViewModel: \(error)")
        }

        isLoading = false
    }

    /// Delete a goal and reload the list
    ///
    /// - Parameter goalData: The goal to delete (canonical GoalData type)
    ///
    /// **Implementation**: Uses new GoalCoordinator.delete(_:GoalData) method directly
    /// **Side Effects**: Reloads goals list after successful deletion
    public func deleteGoal(_ goalData: GoalData) async {
        isLoading = true
        errorMessage = nil

        do {
            // Use coordinator for atomic delete with cascading relationships
            let coordinator = GoalCoordinator(database: database)
            try await coordinator.delete(goalData)

            // Reload list after successful delete
            await loadGoals()
        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ GoalsListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic error fallback
            errorMessage = "Failed to delete goal: \(error.localizedDescription)"
            print("❌ GoalsListViewModel: \(error)")
        }

        isLoading = false
    }
}
