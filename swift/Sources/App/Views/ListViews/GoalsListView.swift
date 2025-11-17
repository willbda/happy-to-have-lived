//
// GoalsListView.swift
// Written by Claude Code on 2025-11-03
// Refactored on 2025-11-13 to use ViewModel pattern
//
// PURPOSE: List of goals with progress and alignment display
// DATA SOURCE: GoalsListViewModel (replaces @Fetch pattern)
// INTERACTIONS: Tap to edit, swipe to delete, empty state
//

import Models
import SwiftUI

/// List view for goals
///
/// **PATTERN**: ViewModel-based (migrated from @Fetch)
/// **DATA**: GoalsListViewModel → GoalRepository → Database
/// **DISPLAY**: GoalRowView for each goal
/// **INTERACTIONS**: Tap to edit, swipe to delete, pull to refresh
///
/// **MIGRATION NOTE** (2025-11-13):
/// Previously used @Fetch(GoalsQuery()) which wrapped repository calls.
/// Now uses GoalsListViewModel directly for:
/// - Better separation of concerns
/// - Explicit async/await patterns
/// - Easier testing and error handling
public struct GoalsListView: View {
    @State private var viewModel = GoalsListViewModel()

    @State private var showingAddGoal = false
    @State private var goalToEdit: GoalData?
    @State private var goalToDelete: GoalData?
    @State private var showingDeleteAlert = false
    @State private var showingGoalCoach = false

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading {
                // Loading state
                ProgressView("Loading goals...")
            } else if viewModel.goals.isEmpty {
                // Empty state
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
            } else {
                // Goal list
                List {
                    ForEach(viewModel.goals) { goalData in
                        GoalRowView(goal: goalData)
                            .onTapGesture {
                                goalToEdit = goalData
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    goalToDelete = goalData
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    goalToEdit = goalData
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddGoal = true
                } label: {
                    Label("Add Goal", systemImage: "plus")
                }
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
        .task {
            // Load goals when view appears
            await viewModel.loadGoals()
        }
        .refreshable {
            // Pull-to-refresh uses same load method
            await viewModel.loadGoals()
        }
        .sheet(isPresented: $showingAddGoal) {
            NavigationStack {
                GoalFormView()
            }
        }
        .sheet(item: $goalToEdit) { goalData in
            NavigationStack {
                GoalFormView(goalToEdit: goalData)
            }
        }
        .alert("Delete Goal?", isPresented: $showingDeleteAlert, presenting: goalToDelete) { goalData in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteGoal(goalData)
                }
            }
        } message: { goalData in
            Text("Are you sure you want to delete \"\(goalData.title ?? "this goal")\"?")
        }
        .alert("Error", isPresented: .constant(viewModel.hasError)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .sheet(isPresented: $showingGoalCoach) {
            if #available(iOS 26.0, macOS 26.0, *) {
                NavigationStack {
                    GoalCoachView()
                }
            }
        }
    }
}
