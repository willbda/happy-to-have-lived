//
// GoalDetailView.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Goal detail view with Weather app-style horizontal swiping
//
// UX PATTERN (as requested):
// - Hero image with goal title (similar to HomeView)
// - Quick-add action button (top-right plus button, pre-filled with this goal)
// - Contributing actions list (filtered to this goal)
// - Swipe left/right to navigate between goals (Weather app pattern)
//
// DESIGN REFERENCES:
// - Apple Weather app: Horizontal swiping between locations
// - HomeView: Hero image with gradient overlay
// - ActionsListView: Action row styling
//

import SwiftUI
import Models
import Services

/// Goal detail view with Weather app-style horizontal swiping
public struct GoalDetailView: View {
    // MARK: - Environment

    @Environment(DataStore.self) private var dataStore
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    // MARK: - Properties

    let goalId: UUID

    // MARK: - State

    @State private var showingQuickAction = false

    // MARK: - Computed Properties

    private var goal: GoalData? {
        dataStore.goals.first { $0.id == goalId }
    }

    private var contributingActions: [ActionData] {
        dataStore.actionsForGoal(goalId)
            .sorted { $0.logTime > $1.logTime }  // Most recent first
    }

    // MARK: - Initialization

    public init(goalId: UUID) {
        self.goalId = goalId
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            if let goal {
                VStack(spacing: 24) {
                    heroImageSection(for: goal)
                    contributingActionsSection
                }
            } else {
                ContentUnavailableView(
                    "Goal Not Found",
                    systemImage: "target",
                    description: Text("This goal may have been deleted.")
                )
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingQuickAction = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                }
            }
        }
        // SHEET FOR QUICK-ADD (Apple's recommended pattern for forms)
        .sheet(isPresented: $showingQuickAction) {
            NavigationStack {
                ActionFormView(initialData: ActionFormData(
                    title: "",
                    detailedDescription: "",
                    freeformNotes: "",
                    durationMinutes: 0,
                    startTime: Date(),
                    measurements: [],
                    goalContributions: [goalId]  // Pre-fill with this goal
                ))
            }
        }
        // Horizontal swipe gesture (Weather app pattern)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -100 {
                        navigateToNextGoal()
                    } else if value.translation.width > 100 {
                        navigateToPreviousGoal()
                    }
                }
        )
    }

    // MARK: - Sections

    private func heroImageSection(for goal: GoalData) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Hero image with goal-specific gradient
            LinearGradient(
                colors: [
                    goal.presentationColor.opacity(0.6),
                    goal.presentationColor
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 300)

            // Goal title overlay
            VStack(alignment: .leading, spacing: 8) {
                Text(goal.title ?? "Untitled Goal")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)

                // Target date (if available)
                if let targetDate = goal.targetDate {
                    Text("Target: \(targetDate, style: .date)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private var contributingActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Actions")
                .font(.headline)
                .padding(.horizontal, 20)

            if contributingActions.isEmpty {
                ContentUnavailableView(
                    "No Actions Yet",
                    systemImage: "checkmark.circle",
                    description: Text("Log an action to track progress on this goal.")
                )
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(contributingActions.prefix(10)) { action in
                        actionRow(for: action)
                        Divider()
                            .padding(.leading, 20)
                    }
                }
            }
        }
    }

    private func actionRow(for action: ActionData) -> some View {
        HStack(spacing: 12) {
            // Icon from MeasurePresentation
            let icon = action.measurements.first.map { measurement in
                MeasurePresentation.icon(for: measurement.measureUnit)
            } ?? "checkmark.circle.fill"

            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(goal?.presentationColor ?? .gray)
                .frame(width: 40, height: 40)
                .background((goal?.presentationColor ?? .gray).opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(action.title ?? "Untitled Action")
                    .font(.body)

                HStack(spacing: 8) {
                    // Measurement value
                    if let measurement = action.measurements.first {
                        Text("\(Int(measurement.value)) \(measurement.measureUnit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Date
                    Text(action.logTime, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Navigation Helpers

    private func navigateToNextGoal() {
        let activeGoals = dataStore.activeGoals
        guard let currentIndex = activeGoals.firstIndex(where: { $0.id == goalId }),
              currentIndex < activeGoals.count - 1 else { return }

        let nextGoal = activeGoals[currentIndex + 1]
        navigationCoordinator.navigateToNextGoal(nextGoal.id)
    }

    private func navigateToPreviousGoal() {
        let activeGoals = dataStore.activeGoals
        guard let currentIndex = activeGoals.firstIndex(where: { $0.id == goalId }),
              currentIndex > 0 else { return }

        let previousGoal = activeGoals[currentIndex - 1]
        navigationCoordinator.navigateToPreviousGoal(previousGoal.id)
    }
}
