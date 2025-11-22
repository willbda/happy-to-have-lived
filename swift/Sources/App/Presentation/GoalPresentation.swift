//
// GoalPresentation.swift
// Written by Claude Code on 2025-11-20
// Updated on 2025-11-21 to add progress calculation helpers
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
import Services

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

    /// Calculate combined progress for a goal (time + action progress)
    ///
    /// **Algorithm**: 30% time-based + 70% action-based
    /// **Inputs**: Goal data, related actions, progress service
    /// **Returns**: Progress value 0.0 to 1.0
    ///
    /// **Example**:
    /// ```swift
    /// let progress = GoalPresentation.progress(
    ///     for: goalData,
    ///     actions: dataStore.actionsForGoal(goalData.id),
    ///     service: progressService
    /// )
    /// Text("\(Int(progress * 100))%")
    /// ```
    public static func progress(
        for goal: GoalData,
        actions: [ActionData],
        service: ProgressCalculationService
    ) -> Double {
        // Time-based progress (30% weight)
        let timeResult = service.calculateTimeProgress(
            startDate: goal.startDate,
            targetDate: goal.targetDate
        )

        // Convert actions to service format
        // IMPORTANT: Uses contributions (goal-directed), not measurements (all tracking)
        let actionContributions: [ActionWithContributions] = actions.map { action in
            ActionWithContributions(
                id: action.id,
                logTime: action.logTime,
                contributions: action.contributions.map { contribution in
                    ActionContribution(
                        measureId: contribution.measureId,
                        contributionAmount: contribution.contributionAmount
                    )
                }
            )
        }

        // Convert targets to service format
        let targets: [MeasureTarget] = goal.measureTargets.map { target in
            MeasureTarget(
                measureId: target.measureId,
                measureTitle: target.measureTitle ?? "",
                measureUnit: target.measureUnit,
                targetValue: target.targetValue
            )
        }

        // Action-based progress (70% weight)
        let actionResult = service.calculateActionProgress(
            targets: targets,
            actions: actionContributions
        )

        // Combined: 30% time + 70% action
        return service.calculateCombinedProgress(
            timeProgress: timeResult.progress,
            actionProgress: actionResult.progress
        )
    }
}

// MARK: - Convenience Extensions

extension GoalData {
    /// Presentation color for this goal (delegates to GoalPresentation)
    ///
    /// **Convenience**: Allows `goal.presentationColor` instead of `GoalPresentation.color(for: goal.id)`
    /// **Implementation**: Thin wrapper around static helper
    public var presentationColor: Color {
        GoalPresentation.color(for: id)
    }

    /// Formatted target date for display
    ///
    /// **Example**:
    /// ```swift
    /// Text(goal.formattedTargetDate)  // "Target: Nov 21, 2025" or "No target date"
    /// ```
    public var formattedTargetDate: String {
        if let targetDate = targetDate {
            return "Target: \(targetDate.formatted(date: .abbreviated, time: .omitted))"
        } else {
            return "No target date"
        }
    }
}
