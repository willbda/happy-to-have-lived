//
// ActionsListViewModel.swift
// Written by Claude Code on 2025-11-13
//
// PURPOSE:
// ViewModel for ActionsListView - manages actions list state and repository access.
// Eliminates @Fetch wrapper pattern in favor of direct repository access.
//
// ARCHITECTURE PATTERN:
// - @Observable for automatic UI updates (NOT ObservableObject)
// - @MainActor for UI thread safety
// - Lazy repository pattern for data access
// - Follows patterns from GoalsListViewModel.swift
//
// DATA FLOW:
// ActionRepository → ActionsListViewModel → ActionsListView
// GoalRepository → ActionsListViewModel (for Quick Add active goals)
//

import Foundation
import Observation
import Dependencies
import Services
import Models

/// ViewModel for ActionsListView
///
/// **PATTERN**: Modern Swift 6 ViewModel
/// - Uses @Observable (Swift 5.9+) not ObservableObject
/// - @MainActor ensures UI updates on main thread
/// - Lazy repository pattern for efficient data access
///
/// **RESPONSIBILITIES**:
/// - Fetch actions from repository
/// - Fetch active goals for Quick Add section
/// - Handle loading/error states
/// - Provide data to view
/// - Manage delete operations
///
/// **USAGE**:
/// ```swift
/// @State private var viewModel = ActionsListViewModel()
///
/// .task {
///     await viewModel.loadActions()
///     await viewModel.loadActiveGoals()
/// }
/// .refreshable {
///     await viewModel.loadActions()
///     await viewModel.loadActiveGoals()
/// }
/// ```
@Observable
@MainActor
public final class ActionsListViewModel {

    // MARK: - Observable State (internal visibility)

    /// Actions data for display (canonical type)
    var actions: [Models.ActionData] = []

    /// Active goals for Quick Add section (goals with no target date or future target date)
    var activeGoals: [Models.GoalData] = []

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

    /// Repository for action data access (lazy initialization)
    @ObservationIgnored
    private lazy var actionRepository: ActionRepository = {
        ActionRepository(database: database)
    }()

    /// Repository for goal data access (for Quick Add active goals)
    @ObservationIgnored
    private lazy var goalRepository: GoalRepository = {
        GoalRepository(database: database)
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Data Loading

    /// Load all actions from repository
    ///
    /// Used for both initial load (.task) and refresh (.refreshable)
    /// Automatically updates observable properties which trigger UI updates.
    ///
    /// **Performance**: Single JSON aggregation query (1 database round trip)
    /// **Concurrency**: Runs on background thread via repository, returns to main actor
    public func loadActions() async {
        isLoading = true
        errorMessage = nil

        do {
            actions = try await actionRepository.fetchAll()
        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ ActionsListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic error fallback
            errorMessage = "Failed to load actions: \(error.localizedDescription)"
            print("❌ ActionsListViewModel: \(error)")
        }

        isLoading = false
    }

    /// Load active goals for Quick Add section
    ///
    /// Fetches goals with no target date or target date in future.
    /// This supports the Quick Add feature where users can quickly log actions toward active goals.
    ///
    /// **Performance**: Single JSON aggregation query via GoalRepository
    /// **Filtering**: SQL-side filtering (WHERE targetDate IS NULL OR targetDate >= date('now'))
    public func loadActiveGoals() async {
        print("🔍 ActionsListViewModel: Starting to load active goals...")
        do {
            // Use specialized repository method (filters in SQL, not Swift)
            activeGoals = try await goalRepository.fetchActiveGoals()
            print("✅ ActionsListViewModel: Loaded \(activeGoals.count) active goals")
        } catch {
            // Don't set errorMessage (Quick Add is optional feature)
            print("⚠️ ActionsListViewModel: Failed to load active goals: \(error)")
            print("⚠️ Error type: \(type(of: error))")
            if let validationError = error as? ValidationError {
                print("⚠️ ValidationError details: \(validationError)")
            }
        }
    }

    /// Delete an action and reload the list
    ///
    /// - Parameter actionData: The action to delete (canonical data type)
    ///
    /// **Implementation**: Uses ActionCoordinator for atomic multi-table delete
    /// **Side Effects**: Reloads actions list after successful deletion
    public func deleteAction(_ actionData: Models.ActionData) async {
        isLoading = true
        errorMessage = nil

        do {
            // Use coordinator for atomic delete with cascading relationships
            let coordinator = ActionCoordinator(database: database)
            try await coordinator.delete(actionData)

            // Reload list after successful delete
            await loadActions()
        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ ActionsListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic error fallback
            errorMessage = "Failed to delete action: \(error.localizedDescription)"
            print("❌ ActionsListViewModel: \(error)")
        }

        isLoading = false
    }
}
