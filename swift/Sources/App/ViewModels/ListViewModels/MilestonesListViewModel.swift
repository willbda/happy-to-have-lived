//
// MilestonesListViewModel.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: ViewModel for Milestones list view
// PATTERN: @Observable with Repository pattern, following GoalsListViewModel
//

import Dependencies
import Foundation
import Models
import Observation
import Services
import SQLiteData

/// ViewModel for Milestones list view
///
/// **Pattern**: @Observable with Repository + Coordinator
/// **Dependencies**: @Dependency(\.defaultDatabase) with @ObservationIgnored
/// **Responsibilities**:
/// - loadMilestones() fetches all milestones with expectation details
/// - deleteMilestone() removes milestone and reloads list
/// - Handles loading states and errors with user-friendly messages
///
/// **Usage in View**:
/// ```swift
/// @State private var viewModel = MilestonesListViewModel()
///
/// .task {
///     await viewModel.loadMilestones()
/// }
///
/// .refreshable {
///     await viewModel.loadMilestones()
/// }
/// ```
@Observable
@MainActor
public final class MilestonesListViewModel {
    // MARK: - Observable State (internal - accessed only by corresponding view)

    var milestones: [MilestoneWithDetails] = []
    var isLoading: Bool = false
    var errorMessage: String?

    var hasError: Bool { errorMessage != nil }

    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    private lazy var repository: MilestoneRepository = {
        MilestoneRepository(database: database)
    }()

    @ObservationIgnored
    private lazy var coordinator: MilestoneCoordinator = {
        MilestoneCoordinator(database: database)
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Actions

    /// Load all milestones from repository
    ///
    /// **Flow**:
    /// 1. Set isLoading = true (show progress view)
    /// 2. Fetch milestones from repository - switches to background for I/O
    /// 3. Update milestones array - Swift switches back to main actor
    /// 4. Set isLoading = false (hide progress view)
    ///
    /// **Error Handling**:
    /// - ValidationError: User-friendly message from repository
    /// - DatabaseError: Generic fallback message
    ///
    /// **Usage**: Call in .task or .refreshable modifier
    public func loadMilestones() async {
        isLoading = true
        errorMessage = nil

        do {
            milestones = try await repository.fetchAll()
        } catch let error as ValidationError {
            // User-friendly validation messages (e.g., "Database constraint violated")
            errorMessage = error.userMessage
            print("❌ MilestonesListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic fallback for unexpected errors
            errorMessage = "Failed to load milestones: \(error.localizedDescription)"
            print("❌ MilestonesListViewModel: \(error)")
        }

        isLoading = false
    }

    /// Delete milestone and reload list
    ///
    /// **Flow**:
    /// 1. Set isLoading = true (show progress view)
    /// 2. Call coordinator.delete() - switches to background for I/O
    /// 3. Reload milestones if successful - Swift switches back to main actor
    /// 4. Set isLoading = false (hide progress view)
    ///
    /// **Error Handling**:
    /// - ValidationError: User-friendly message
    /// - DatabaseError: Generic fallback message
    ///
    /// **Usage**: Call in .onDelete or swipe-to-delete handler
    public func deleteMilestone(_ milestone: MilestoneWithDetails) async {
        isLoading = true
        errorMessage = nil

        do {
            try await coordinator.delete(milestoneId: milestone.id)
            // Reload list after successful deletion
            await loadMilestones()
        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ MilestonesListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic fallback for unexpected errors
            errorMessage = "Failed to delete milestone: \(error.localizedDescription)"
            print("❌ MilestonesListViewModel: \(error)")
        }

        isLoading = false
    }
}
