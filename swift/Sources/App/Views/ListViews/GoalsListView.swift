//
// GoalsListView.swift
// Written by Claude Code on 2025-11-03
// Refactored on 2025-11-13 to use ViewModel pattern
// Refactored on 2025-11-19 for HIG compliance and consistency
// Refactored on 2025-11-20 to use DataStore (declarative pattern)
//
// PURPOSE: List of goals with progress and alignment display
// DATA SOURCE: DataStore (environment object, single source of truth)
// INTERACTIONS: Tap to edit, swipe to delete, empty state, context menu
//

import Models
import SwiftUI

/// List view for goals
///
/// **PATTERN**: Declarative SwiftUI with DataStore (Apple's recommended pattern)
/// **DATA**: DataStore (environment) → Observable state → Automatic UI updates
/// **DISPLAY**: GoalRowView for each goal
/// **INTERACTIONS**: Tap to edit, swipe to delete, context menu
///
/// **DECLARATIVE ARCHITECTURE** (2025-11-20):
/// - No manual refresh calls (DataStore updates propagate automatically)
/// - No separate ViewModels (DataStore is single source of truth)
/// - Truly reactive (views observe DataStore via @Environment)
/// - Follows Apple's sample code pattern (AddRichGraphicsToYourSwiftUIApp)
public struct GoalsListView: View {
    @Environment(DataStore.self) private var dataStore

    @State private var showingAddGoal = false
    @State private var goalToEdit: GoalData?
    @State private var goalToDelete: GoalData?
    @State private var selectedGoal: GoalData?  // For keyboard navigation
    @State private var showingGoalCoach = false

    public init() {}

    public var body: some View {
        mainContent
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGoal = true
                    } label: {
                        Label("Add Goal", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }

                // AI Goal Coach button
                if #available(iOS 26.0, macOS 26.0, *) {
                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            showingGoalCoach = true
                        } label: {
                            Label("AI Coach", systemImage: "brain")
                        }
                    }
                }
            }
            .refreshable {
                // Pull-to-refresh reloads from database
                await dataStore.loadGoals()
            }
            .sheet(isPresented: $showingAddGoal) {
                NavigationStack {
                    GoalFormView()
                }
            }
            // NO onDismiss needed - DataStore updates automatically!
            .sheet(item: $goalToEdit) { goalData in
                NavigationStack {
                    GoalFormView(goalToEdit: goalData)
                }
            }
            // NO onDismiss needed - DataStore updates automatically!
            .alert("Delete Goal", isPresented: .constant(goalToDelete != nil), presenting: goalToDelete) { goalData in
                Button("Cancel", role: .cancel) {
                    goalToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    delete(goalData)
                }
            } message: { goalData in
                Text("Are you sure you want to delete '\(goalData.title ?? "this goal")'?")
            }
            .alert("Error", isPresented: .constant(dataStore.errorMessage != nil)) {
                Button("OK") {
                    // Can't mutate dataStore directly since it's not @Bindable
                    // Error will clear on next operation
                }
            } message: {
                Text(dataStore.errorMessage ?? "Unknown error")
            }
            .sheet(isPresented: $showingGoalCoach) {
                if #available(iOS 26.0, macOS 26.0, *) {
                    NavigationStack {
                        GoalCoachView()
                    }
                }
            }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if dataStore.isLoading {
            // Loading state
            ProgressView("Loading goals...")
        } else if dataStore.goals.isEmpty {
            // Empty state
            emptyState
        } else {
            // Goal list
            goalsList
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Goals Yet", systemImage: "target")
        } description: {
            Text("Set your first goal to start tracking progress")
        } actions: {
            Button("Add Goal") {
                showingAddGoal = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Goals List

    private var goalsList: some View {
        List(selection: $selectedGoal) {
            ForEach(dataStore.goals) { goalData in
                GoalRowView(goal: goalData)
                    .onTapGesture {
                        edit(goalData)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            goalToDelete = goalData
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            edit(goalData)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    // Context menu for mouse/trackpad users
                    .contextMenu {
                        Button {
                            edit(goalData)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            goalToDelete = goalData
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .tag(goalData)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)  // iOS: Inset grouped style with Liquid Glass
        #else
        .listStyle(.inset)  // macOS: Inset style (native macOS appearance)
        #endif
        #if os(macOS)
        .onDeleteCommand {
            if let selected = selectedGoal {
                goalToDelete = selected
            }
        }
        #endif
    }

    // MARK: - Actions

    private func edit(_ goalData: GoalData) {
        goalToEdit = goalData
    }

    private func delete(_ goalData: GoalData) {
        Task {
            try? await dataStore.deleteGoal(goalData)
            goalToDelete = nil
        }
    }
}
