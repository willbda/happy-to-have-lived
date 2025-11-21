//
// NavigationCoordinator.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Manages navigation state for the app
//
// PATTERN: Centralized navigation coordinator
// - Single source of truth for navigation state
// - Serializable (NavigationPath supports AppIntents deep linking)
// - Observable for automatic UI updates
//
// DESIGN DECISIONS:
// - NavigationPath for hierarchical navigation (Home → Goal Detail → ...)
// - selectedGoalId for horizontal paging context (Weather app pattern)
// - @MainActor because navigation state drives UI updates
//
// APPLE'S GUIDANCE (from NavigationStack documentation):
// "Use a navigation stack to present a stack of views over a root view.
//  People can add views to the top of the stack by clicking or tapping a
//  NavigationLink, and remove views using built-in, platform-appropriate
//  controls, like a Back button or a swipe gesture."
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
///     navigationCoordinator.navigateToGoal(goalId)
/// }
/// ```
@Observable
@MainActor
public final class NavigationCoordinator {

    // MARK: - Navigation State

    /// Navigation path for drill-down hierarchy (Home → Goal Detail → ...)
    ///
    /// **NavigationPath Benefits**:
    /// - Type-erased: Can append any Hashable type
    /// - Serializable: Supports deep linking for App Shortcuts
    /// - Observable: UI updates automatically when path changes
    /// - SwiftUI-managed: Back button and swipe gestures work automatically
    public var path: NavigationPath = NavigationPath()

    /// Currently selected goal for horizontal paging
    ///
    /// **Use Case**: Weather app-style horizontal swiping between goals
    /// **Pattern**: Track current goal to enable swipe-left/right navigation
    public var selectedGoalId: UUID?

    // MARK: - Initialization

    public init() {}

    // MARK: - Navigation Actions

    /// Navigate to goal detail view
    ///
    /// **Pattern**: Append goal ID to navigation path
    /// **Result**: SwiftUI pushes GoalDetailView onto stack
    /// **Back**: Automatic via NavigationStack
    ///
    /// **Example**:
    /// ```swift
    /// navigationCoordinator.navigateToGoal(goal.id)
    /// // → Pushes GoalDetailView with that goal
    /// ```
    public func navigateToGoal(_ goalId: UUID) {
        selectedGoalId = goalId
        path.append(goalId)
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
        path = NavigationPath()
        selectedGoalId = nil
    }

    /// Navigate to next goal in list
    ///
    /// **Use Case**: Swipe-left gesture in GoalDetailView
    /// **Pattern**: Replace current goal ID in path
    ///
    /// **Note**: Actual navigation logic in GoalDetailView (needs access to dataStore)
    public func navigateToNextGoal(_ goalId: UUID) {
        selectedGoalId = goalId
        // Remove last path element and append new goal
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(goalId)
    }

    /// Navigate to previous goal in list
    ///
    /// **Use Case**: Swipe-right gesture in GoalDetailView
    /// **Pattern**: Replace current goal ID in path
    public func navigateToPreviousGoal(_ goalId: UUID) {
        selectedGoalId = goalId
        // Remove last path element and append new goal
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(goalId)
    }
}
