//
// PersonalValuesListViewModel.swift
// Written by Claude Code on 2025-11-13
// Refactored to PersonalValueData on 2025-11-16
//
// PURPOSE:
// ViewModel for PersonalValuesListView - manages values list state and repository access.
// Uses canonical PersonalValueData for both display and export.
//
// ARCHITECTURE PATTERN:
// - @Observable for automatic UI updates (NOT ObservableObject)
// - @MainActor for UI thread safety
// - Lazy repository pattern for data access
// - Follows patterns from GoalsListViewModel.swift and ActionsListViewModel.swift
//
// DATA FLOW:
// PersonalValueRepository → PersonalValuesListViewModel → PersonalValuesListView
//
// CANONICAL PATTERN:
// - Stores PersonalValueData (not PersonalValue)
// - Repository returns PersonalValueData directly
// - Transform to PersonalValue at display boundary if needed (via .asValue)
//

import Foundation
import Observation
import Dependencies
import Services
import Models

/// ViewModel for PersonalValuesListView
///
/// **PATTERN**: Modern Swift 6 ViewModel
/// - Uses @Observable (Swift 5.9+) not ObservableObject
/// - @MainActor ensures UI updates on main thread
/// - Lazy repository pattern for efficient data access
///
/// **RESPONSIBILITIES**:
/// - Fetch values from repository
/// - Handle loading/error states
/// - Provide data to view
/// - Manage delete operations
///
/// **USAGE**:
/// ```swift
/// @State private var viewModel = PersonalValuesListViewModel()
///
/// .task {
///     await viewModel.loadValues()
/// }
/// .refreshable {
///     await viewModel.loadValues()
/// }
/// ```
@Observable
@MainActor
public final class PersonalValuesListViewModel {

    // MARK: - Observable State (internal visibility)

    /// Values data for display (canonical PersonalValueData)
    var values: [PersonalValueData] = []

    /// Loading state for UI feedback
    var isLoading: Bool = false

    /// Error message for user display
    var errorMessage: String?

    // MARK: - Computed Properties

    /// Whether there's an error to display
    var hasError: Bool {
        errorMessage != nil
    }

    /// Values grouped by level for section display
    /// Performance: O(n) grouping, computed on-demand
    var groupedValues: [String: [PersonalValueData]] {
        Dictionary(grouping: values, by: \.valueLevel)
    }

    // MARK: - Dependencies (not observable)

    /// Database dependency
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    /// Repository for data access (lazy initialization)
    @ObservationIgnored
    private lazy var repository: PersonalValueRepository = {
        PersonalValueRepository(database: database)
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Data Loading

    /// Load all values from repository
    ///
    /// Used for both initial load (.task) and refresh (.refreshable)
    /// Automatically updates observable properties which trigger UI updates.
    ///
    /// **Performance**: Single query (no joins needed for PersonalValue)
    /// **Concurrency**: Runs on background thread via repository, returns to main actor
    public func loadValues() async {
        isLoading = true
        errorMessage = nil

        do {
            values = try await repository.fetchAll()
        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ PersonalValuesListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic error fallback
            errorMessage = "Failed to load values: \(error.localizedDescription)"
            print("❌ PersonalValuesListViewModel: \(error)")
        }

        isLoading = false
    }

    /// Delete a value and reload the list
    ///
    /// - Parameter valueData: The PersonalValueData to delete
    ///
    /// **Implementation**: Uses PersonalValueCoordinator for atomic delete
    /// **Transform**: Converts PersonalValueData to PersonalValue for coordinator
    /// **Side Effects**: Reloads values list after successful deletion
    public func deleteValue(_ valueData: PersonalValueData) async {
        isLoading = true
        errorMessage = nil

        do {
            // Use coordinator for delete
            let coordinator = PersonalValueCoordinator(database: database)
            try await coordinator.delete(valueData)

            // Reload list after successful delete
            await loadValues()
        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ PersonalValuesListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic error fallback
            errorMessage = "Failed to delete value: \(error.localizedDescription)"
            print("❌ PersonalValuesListViewModel: \(error)")
        }

        isLoading = false
    }
}
