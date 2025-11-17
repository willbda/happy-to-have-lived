//
// QuickAddSection.swift
// Written by Claude Code on 2025-11-03
// Refactored for 3NF normalized schema
//
// PURPOSE: Quick action entry from recent history or active goals
// PATTERN: Horizontal scroll cards → pre-fill ActionFormView
// INTEGRATION: Added to ActionsListView as first section
//

import SwiftUI
import Models
import Services

/// Quick add section showing recent actions and active goals
///
/// **Changes from v1.0**:
/// - No longer duplicates directly (opens pre-filled form instead)
/// - Uses ActionFormData for pre-filling
/// - Works with measurements (not JSON)
///
/// **UX Flow**:
/// 1. User taps "Duplicate" on recent action card
/// 2. ActionFormView opens with pre-filled data
/// 3. User can adjust, then save via ActionFormViewModel
///
/// **Usage**:
/// ```swift
/// QuickAddSection(
///     recentActions: Array(actions.prefix(5)),
///     activeGoals: activeGoals,
///     onDuplicateAction: { formData in
///         self.formData = formData
///         showActionForm = true
///     },
///     onLogActionForGoal: { goalDetail in
///         // Pre-fill with goal's first metric
///         self.formData = buildFormData(for: goalDetail)
///         showActionForm = true
///     }
/// )
/// ```
public struct QuickAddSection: View {

    // MARK: - Properties

    /// Recent actions with measurements (canonical data)
    let recentActions: [ActionData]

    /// Active goals with targets (canonical data)
    let activeGoals: [GoalData]

    /// Callback to show form with pre-filled action data
    let onDuplicateAction: (ActionFormData) -> Void

    /// Callback to show form with goal-related action data
    let onLogActionForGoal: (GoalData) -> Void

    // MARK: - State

    /// Whether the section is expanded (persisted via AppStorage)
    @AppStorage("quickAddSectionExpanded") private var isExpanded = true

    // MARK: - Initialization

    public init(
        recentActions: [ActionData],
        activeGoals: [GoalData],
        onDuplicateAction: @escaping (ActionFormData) -> Void,
        onLogActionForGoal: @escaping (GoalData) -> Void
    ) {
        self.recentActions = recentActions
        self.activeGoals = activeGoals
        self.onDuplicateAction = onDuplicateAction
        self.onLogActionForGoal = onLogActionForGoal
    }

    // MARK: - Body

    public var body: some View {
        Section {
            if isExpanded {
                // Recent Actions
                if !recentActions.isEmpty {
                    recentActionsSection
                }

                // Active Goals
                if !activeGoals.isEmpty {
                    activeGoalsSection
                }

                // Empty state
                if recentActions.isEmpty && activeGoals.isEmpty {
                    emptyState
                }
            }
        } header: {
            sectionHeader
        }
    }

    // MARK: - Subviews

    /// Collapsible section header
    private var sectionHeader: some View {
        Button {
            withAnimation(.smooth) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)

                Text("Quick Add")
                    .font(.headline)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
        }
        .buttonStyle(.plain)
    }

    /// Recent actions horizontal scroll
    private var recentActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Actions")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentActions.prefix(5), id: \.id) { actionData in
                        QuickActionCard(
                            title: actionData.title ?? "Untitled",
                            subtitle: formatActionDetails(actionData),
                            icon: "doc.text",
                            iconColor: .blue,
                            actionIcon: "plus.square.on.square"
                        ) {
                            // Build FormData from existing action
                            let formData = buildFormData(from: actionData)
                            onDuplicateAction(formData)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    /// Active goals horizontal scroll
    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Goals")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(activeGoals.prefix(5), id: \.id) { goalData in
                        QuickActionCard(
                            title: goalData.title ?? "Untitled",
                            subtitle: formatGoalDetails(goalData),
                            icon: "target",
                            iconColor: .orange,
                            actionIcon: "plus.circle"
                        ) {
                            onLogActionForGoal(goalData)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    /// Empty state when no recent actions or active goals
    private var emptyState: some View {
        Text("No recent actions or active goals")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical)
    }

    // MARK: - Helper Functions

    /// Build ActionFormData from existing ActionData
    ///
    /// Copies all fields except resets startTime to now
    private func buildFormData(from actionData: ActionData) -> ActionFormData {
        // Convert measurements to MeasurementInput (from flat ActionData.Measurement)
        let measurements = actionData.measurements.map { measurement in
            MeasurementInput(
                measureId: measurement.measureId,
                value: measurement.value
            )
        }

        // Convert goal contributions to UUID set
        let goalContributions = Set(
            actionData.contributions.map { $0.goalId }
        )

        return ActionFormData(
            title: actionData.title ?? "",
            detailedDescription: actionData.detailedDescription ?? "",
            freeformNotes: actionData.freeformNotes ?? "",
            durationMinutes: actionData.durationMinutes ?? 0,
            startTime: Date(),  // Reset to now (not historical time)
            measurements: measurements,
            goalContributions: goalContributions
        )
    }

    /// Format action details for card subtitle
    ///
    /// Shows: measurements (max 2) + duration
    private func formatActionDetails(_ actionData: ActionData) -> String {
        var parts: [String] = []

        // Add measurements (max 2) - using flat ActionData.Measurement structure
        if !actionData.measurements.isEmpty {
            let formatted = actionData.measurements.prefix(2).map { measurement in
                String(format: "%.1f %@", measurement.value, measurement.measureUnit)
            }
            parts.append(contentsOf: formatted)
        }

        // Add duration
        if let duration = actionData.durationMinutes {
            parts.append(String(format: "%.0f min", duration))
        }

        return parts.isEmpty ? "No details" : parts.joined(separator: " • ")
    }

    /// Format goal details for card subtitle
    ///
    /// Shows: first target + due date
    private func formatGoalDetails(_ goalData: GoalData) -> String {
        var parts: [String] = []

        // Add first target - using flat GoalData.MeasureTarget structure
        if let firstTarget = goalData.measureTargets.first {
            parts.append(String(
                format: "Target: %.1f %@",
                firstTarget.targetValue,
                firstTarget.measureUnit
            ))
        }

        // Add target date
        if let targetDate = goalData.targetDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("Due: \(formatter.string(from: targetDate))")
        }

        return parts.isEmpty ? "No target" : parts.joined(separator: " • ")
    }
}

// MARK: - Quick Action Card Component

/// Compact card for horizontal scrolling
///
/// **Design**: 160x100pt card with icon, title, subtitle, and action button
private struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let actionIcon: String
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Header: icon + action button
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(iconColor)

                    Spacer()

                    Image(systemName: actionIcon)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(iconColor)
                        .clipShape(Circle())
                }

                // Title
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Subtitle
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: 160, height: 100, alignment: .topLeading)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
