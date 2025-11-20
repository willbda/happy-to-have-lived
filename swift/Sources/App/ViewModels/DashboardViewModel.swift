//
// DashboardViewModel.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: ViewModel for dashboard view with active goals, term, actions, milestones, and obligations
//
// DESIGN PATTERN:
// - @Observable + @MainActor (UI state management)
// - 5 lazy repositories with @ObservationIgnored
// - Parallel data loading for performance
// - User-friendly error handling with ValidationError
//
// USAGE:
// ```swift
// @State private var viewModel = DashboardViewModel()
//
// .task {
//     await viewModel.loadDashboard()
// }
// ```

import Foundation
import Observation
import Dependencies
import Services
import Models
import Database

/// ViewModel for Dashboard view
///
/// **Pattern**: Dashboard ViewModel (loads multiple data sources in parallel)
/// **Concurrency**: @MainActor (UI state updates on main thread)
@available(iOS 26.0, macOS 26.0, *)
@Observable
@MainActor
public final class DashboardViewModel {

    // MARK: - Observable State

    /// Current active term (nil if none)
    var currentTerm: TimePeriodData?

    /// Active goals (sorted by importance/urgency)
    var activeGoals: [GoalData] = []

    /// Recent actions (last 10)
    var recentActions: [ActionData] = []

    /// Upcoming milestones (next 7 days)
    var upcomingMilestones: [MilestoneWithDetails] = []

    /// Approaching/overdue obligations
    var approachingObligations: [ObligationWithDetails] = []

    /// Loading state
    var isLoading: Bool = false

    /// Error message (user-friendly)
    var errorMessage: String?

    /// Computed property for error display
    var hasError: Bool { errorMessage != nil }

    // MARK: - Dependencies (Not Observable)

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    private lazy var goalRepository: GoalRepository = {
        GoalRepository(database: database)
    }()

    @ObservationIgnored
    private lazy var timePeriodRepository: TimePeriodRepository = {
        TimePeriodRepository(database: database)
    }()

    @ObservationIgnored
    private lazy var actionRepository: ActionRepository = {
        ActionRepository(database: database)
    }()

    @ObservationIgnored
    private lazy var milestoneRepository: MilestoneRepository = {
        MilestoneRepository(database: database)
    }()

    @ObservationIgnored
    private lazy var obligationRepository: ObligationRepository = {
        ObligationRepository(database: database)
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Load all dashboard data in parallel
    ///
    /// **Performance**: Fetches all 5 data sources concurrently
    /// **Error Handling**: Shows first error, but partial data still usable
    public func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load all data in parallel for performance
            async let currentTermTask = timePeriodRepository.fetchCurrentTerm()
            async let activeGoalsTask = goalRepository.fetchActiveGoals()
            async let recentActionsTask = actionRepository.fetchRecentActions(limit: 10)
            async let upcomingMilestonesTask = milestoneRepository.fetchUpcoming(days: 7)

            // Obligations: fetch both approaching and overdue
            async let approachingObligationsTask = obligationRepository.fetchByStatus(.approaching)
            async let overdueObligationsTask = obligationRepository.fetchByStatus(.overdue)

            // Await all results
            currentTerm = try await currentTermTask
            activeGoals = try await activeGoalsTask
            recentActions = try await recentActionsTask
            upcomingMilestones = try await upcomingMilestonesTask

            let approaching = try await approachingObligationsTask
            let overdue = try await overdueObligationsTask

            // Combine obligations (overdue first)
            approachingObligations = overdue + approaching

            print("✅ DashboardViewModel: Loaded dashboard data")
            print("   - Current term: \(currentTerm?.termNumber ?? 0)")
            print("   - Active goals: \(activeGoals.count)")
            print("   - Recent actions: \(recentActions.count)")
            print("   - Upcoming milestones: \(upcomingMilestones.count)")
            print("   - Obligations: \(approachingObligations.count)")

        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ DashboardViewModel ValidationError: \(error.userMessage)")

        } catch {
            // Generic error fallback
            errorMessage = "Failed to load dashboard: \(error.localizedDescription)"
            print("❌ DashboardViewModel: \(error)")
        }

        isLoading = false
    }

    /// Reload dashboard (for pull-to-refresh)
    public func reloadDashboard() async {
        await loadDashboard()
    }

    /// Clear error message
    public func clearError() {
        errorMessage = nil
    }

    // MARK: - Helper Methods

    /// Get term progress (0.0-1.0 based on current date)
    func termProgress() -> Double {
        guard let term = currentTerm else { return 0.0 }

        let now = Date()
        let start = term.startDate
        let end = term.endDate

        // Ensure dates are valid
        guard start <= end, now >= start else { return 0.0 }
        guard now <= end else { return 1.0 }

        let totalDuration = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)

        return elapsed / totalDuration
    }

    /// Get days remaining in current term
    func daysRemainingInTerm() -> Int {
        guard let term = currentTerm else { return 0 }

        let now = Date()
        let end = term.endDate

        guard now < end else { return 0 }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: now, to: end)

        return max(0, components.day ?? 0)
    }

    /// Get days until milestone
    func daysUntil(milestone: MilestoneWithDetails) -> Int {
        let now = Date()
        let target = milestone.milestone.targetDate

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: now, to: target)

        return components.day ?? 0
    }

    /// Get days until obligation deadline
    func daysUntil(obligation: ObligationWithDetails) -> Int {
        let now = Date()
        let deadline = obligation.obligation.deadline

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: now, to: deadline)

        return components.day ?? 0
    }

    /// Check if obligation is overdue
    func isOverdue(obligation: ObligationWithDetails) -> Bool {
        return obligation.obligation.deadline < Date()
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, macOS 26.0, *)
extension DashboardViewModel {
    /// Obligation status for filtering
    enum ObligationStatus {
        case approaching
        case overdue
    }
}
