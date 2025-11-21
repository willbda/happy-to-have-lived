//
// GoalPresentation.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Presentation helpers for Goal display
//
// PATTERN: Separate presentation layer from domain models
// - Keeps domain models pure (GoalData has no UI dependencies)
// - Single source of truth for visual presentation
// - Reusable across all views (HomeView, GoalsListView, GoalDetailView)
// - Testable independently
//
// WHY SEPARATE LAYER:
// - Testing: Can test GoalPresentation.color(for:) without mocking GoalData
// - Discoverability: Clear namespace for all presentation logic
// - Future expansion: Easy to add .icon(for:), .badge(for:), etc.
// - Domain purity: GoalData stays in Models package, no SwiftUI dependency
//

import SwiftUI
import Models

/// Presentation helpers for Goal display
public struct GoalPresentation {
    private static let colorPalette: [Color] = [.blue, .green, .orange, .purple, .pink]

    /// Consistent color for a goal (hash-based, deterministic)
    ///
    /// **Algorithm**: Uses goal ID hash modulo color count
    /// **Guarantee**: Same goal always gets same color across all app views
    /// **Use Case**: Goal cards, action row borders, detail view headers
    ///
    /// **Example**:
    /// ```swift
    /// let color = GoalPresentation.color(for: goalId)
    /// // Returns .blue for one goal, .green for another, consistently
    /// ```
    public static func color(for goalId: UUID) -> Color {
        let index = abs(goalId.hashValue) % colorPalette.count
        return colorPalette[index]
    }
}

// MARK: - Convenience Extension

extension GoalData {
    /// Presentation color for this goal (delegates to GoalPresentation)
    ///
    /// **Convenience**: Allows `goal.presentationColor` instead of `GoalPresentation.color(for: goal.id)`
    /// **Implementation**: Thin wrapper around static helper
    public var presentationColor: Color {
        GoalPresentation.color(for: id)
    }
}
