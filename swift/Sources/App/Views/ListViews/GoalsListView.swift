//
// GoalsListView.swift
// Written by Claude Code on 2025-11-03
// Refactored on 2025-11-13 to use ViewModel pattern
// Refactored on 2025-11-19 for HIG compliance and consistency
//
// PURPOSE: List of goals with progress and alignment display
// DATA SOURCE: GoalsListViewModel (replaces @Fetch pattern)
// INTERACTIONS: Tap to edit, swipe to delete, empty state, context menu
//

import Models
import SwiftUI

/// List view for goals
///
/// **PATTERN**: ViewModel-based (migrated from @Fetch)
/// **DATA**: GoalsListViewModel → GoalRepository → Database
/// **DISPLAY**: GoalRowView for each goal
/// **INTERACTIONS**: Tap to edit, swipe to delete, pull to refresh, context menu
///
/// **HIG COMPLIANCE** (2025-11-19):
/// - Consistent feedback: Reload after create/edit/delete
/// - Platform support: macOS keyboard shortcuts and delete command
/// - Proper alert presentation with explicit bindings
/// - Context menu for desktop interaction patterns
public struct GoalsListView: View {
    @State private var viewModel = GoalsListViewModel()

    @State private var showingAddGoal = false
    @State private var goalToEdit: GoalData?
    @State private var goalToDelete: GoalData?
    @State private var selectedGoal: GoalData?  // For keyboard navigation
    @State private var showingGoalCoach = false

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading {
                // Loading state
                ProgressView("Loading goals...")
            } else if viewModel.goals.isEmpty {
                // Empty state
                emptyState
            } else {
                // Goal list
                goalsList
            }
        }
        .background(BackgroundView(.goals))  // Mountain background for aspiration
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
        .task {
            // Load goals when view appears
            await viewModel.loadGoals()
        }
        .refreshable {
            // Pull-to-refresh uses same load method
            await viewModel.loadGoals()
        }
        .sheet(isPresented: $showingAddGoal) {
            // Reload when sheet dismisses
            Task {
                await viewModel.loadGoals()
            }
        } content: {
            NavigationStack {
                GoalFormView()
            }
        }
        .sheet(item: $goalToEdit) { goalData in
            NavigationStack {
                GoalFormView(goalToEdit: goalData)
            }
        }
        .onChange(of: goalToEdit) { oldValue, newValue in
            // Reload list when edit sheet is dismissed
            if newValue == nil && oldValue != nil {
                Task {
                    await viewModel.loadGoals()
                }
            }
        }
        .alert(
            "Delete Goal",
            isPresented: .constant(goalToDelete != nil),
            presenting: goalToDelete
        ) { goalData in
            Button("Cancel", role: .cancel) {
                goalToDelete = nil
            }
            Button("Delete", role: .destructive) {
                delete(goalData)
            }
        } message: { goalData in
            Text("Are you sure you want to delete '\(goalData.title ?? "this goal")'?")
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
            ForEach(viewModel.goals) { goalData in
                GoalRowView(goal: goalData)
                    .listRowBackground(Color.clear)  // Transparent to show background
                    .contentShape(Rectangle())  // Make entire row tappable
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
        .scrollContentBackground(.hidden)  // Hide default list background
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
            await viewModel.deleteGoal(goalData)
            goalToDelete = nil
        }
    }
}
