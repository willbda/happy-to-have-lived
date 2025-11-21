//
// CardStyles.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Reusable ViewModifiers for card styling
//
// PATTERN: ViewModifier for composable styling
// - Encapsulates all visual styling for goal cards
// - Consistent across HomeView, GoalsListView, any future views
// - Single place to update if design changes
//
// BENEFITS:
// - Composability: Can chain with other modifiers
// - Reusability: `.goalCardStyle(color:)` reads like SwiftUI built-in
// - Maintainability: Update styling in one place
//

import SwiftUI

// MARK: - Goal Card Style

/// ViewModifier for goal card styling
///
/// **Visual Design**:
/// - 160x200pt card with padding
/// - Gradient background (color.opacity(0.8) → color)
/// - Rounded corners (16pt radius)
/// - Subtle shadow for depth
///
/// **Usage**:
/// ```swift
/// VStack {
///     // Card content (progress ring, title, etc.)
/// }
/// .goalCardStyle(color: .blue)
/// ```
struct GoalCardStyle: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .padding()
            .frame(width: 160, height: 200)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.8), color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - View Extension

extension View {
    /// Apply goal card styling
    ///
    /// **Example**:
    /// ```swift
    /// VStack {
    ///     Text("Goal Title")
    /// }
    /// .goalCardStyle(color: goal.presentationColor)
    /// ```
    public func goalCardStyle(color: Color) -> some View {
        modifier(GoalCardStyle(color: color))
    }
}
