//
// NavigationCoordinator.swift
// Written by Claude Code on 2025-11-20
// Updated by Claude Code on 2025-11-21 - Type-safe routing with NavigationRoute
//
// PURPOSE: Manages navigation state for the app
//
// PATTERN: Type-safe navigation coordinator
// - Single source of truth for navigation state
// - Type-safe routes with NavigationRoute enum
// - Observable for automatic UI updates
//
// DESIGN DECISIONS:
// - [NavigationRoute] for type-safe hierarchical navigation
// - selectedGoalId for horizontal paging context (Weather app pattern)
// - @MainActor because navigation state drives UI updates
//
// APPLE'S GUIDANCE (from NavigationStack documentation):
// "Use navigationDestination(for:) to associate a view with a kind of
//  presented data, and then present a value of that data type from a
//  NavigationLink or the navigation stack's path."
//

import SwiftUI
import Foundation

/// Manages navigation state for the app
///
/// **Usage**:
/// ```swift
/// // In App:
/// @State private var navigationCoordinator = NavigationCoordinator()
///
/// HomeView()
///     .environment(navigationCoordinator)
///
/// // In View:
/// @Environment(NavigationCoordinator.self) var navigationCoordinator
///
/// Button("View Goal") {
///     navigationCoordinator.navigate(to: .goalDetail(goalId))
/// }
/// ```
@Observable
@MainActor
public final class NavigationCoordinator {

    // MARK: - Navigation State

    /// Navigation path for drill-down hierarchy (Home → Goal Detail → ...)
    ///
    /// **Type-Safe Routing**:
    /// - Each route explicitly declares intent (.goalDetail, .settings, etc.)
    /// - Compiler verifies all routes are handled in NavigationContainer
    /// - Testable: Can verify navigation without launching UI
    /// - Serializable: Supports deep linking for App Shortcuts
    public var path: [NavigationRoute] = []

    /// Currently selected goal for horizontal paging
    ///
    /// **Use Case**: Weather app-style horizontal swiping between goals
    /// **Pattern**: Track current goal to enable swipe-left/right navigation
    public var selectedGoalId: UUID?

    // MARK: - Initialization

    public init() {}

    // MARK: - Navigation Actions

    /// Navigate to a specific route
    ///
    /// **Type-Safe Pattern**: Use NavigationRoute enum for explicit intent
    /// **Result**: SwiftUI pushes corresponding view onto stack
    /// **Back**: Automatic via NavigationStack
    ///
    /// **Example**:
    /// ```swift
    /// navigationCoordinator.navigate(to: .goalDetail(goalId))
    /// navigationCoordinator.navigate(to: .settings)
    /// ```
    public func navigate(to route: NavigationRoute) {
        // Update selectedGoalId if navigating to goal
        if case .goalDetail(let goalId) = route {
            selectedGoalId = goalId
        }

        path.append(route)
    }

    /// Navigate to goal detail view (convenience method)
    ///
    /// **Pattern**: Wrapper for navigate(to: .goalDetail(goalId))
    /// **Backward Compatibility**: Maintains existing call sites
    ///
    /// **Example**:
    /// ```swift
    /// navigationCoordinator.navigateToGoal(goal.id)
    /// // → Equivalent to: navigate(to: .goalDetail(goal.id))
    /// ```
    public func navigateToGoal(_ goalId: UUID) {
        navigate(to: .goalDetail(goalId))
    }

    /// Pop to root (Home)
    ///
    /// **Use Case**: "Home" button, logout, reset navigation
    /// **Pattern**: Clear navigation path (SwiftUI pops all views)
    ///
    /// **Example**:
    /// ```swift
    /// navigationCoordinator.popToRoot()
    /// // → Returns to HomeView
    /// ```
    public func popToRoot() {
        path = []
        selectedGoalId = nil
    }

    /// Navigate to next goal in list
    ///
    /// **Use Case**: Swipe-left gesture in GoalDetailView
    /// **Pattern**: Replace current goal in path
    ///
    /// **Note**: Actual navigation logic in GoalDetailView (needs access to dataStore)
    public func navigateToNextGoal(_ goalId: UUID) {
        selectedGoalId = goalId
        // Remove last path element and append new goal
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(.goalDetail(goalId))
    }

    /// Navigate to previous goal in list
    ///
    /// **Use Case**: Swipe-right gesture in GoalDetailView
    /// **Pattern**: Replace current goal in path
    public func navigateToPreviousGoal(_ goalId: UUID) {
        selectedGoalId = goalId
        // Remove last path element and append new goal
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(.goalDetail(goalId))
    }
}
