//
// ActionsListView.swift
// Written by Claude Code on 2025-11-02
// Refactored on 2025-11-13 to use ViewModel pattern
// Refactored on 2025-11-19 for HIG compliance and consistency
//
// PURPOSE: List view for Actions with measurements and goal contributions
// DATA SOURCE: ActionsListViewModel (replaces @Fetch pattern)
// INTERACTIONS: Tap to edit, swipe to delete, pull to refresh, context menu
//

import SwiftUI
import Models
import Services

/// Main list view for Actions
///
/// **PATTERN**: ViewModel-based (migrated from @Fetch)
/// **DATA**: ActionsListViewModel → ActionRepository + GoalRepository → Database
/// **DISPLAY**: ActionRowView for each action + QuickAddSection
/// **INTERACTIONS**: Tap to edit, swipe to delete, pull to refresh, context menu
///
/// **HIG COMPLIANCE** (2025-11-19):
/// - Consistent feedback: Reload after create/edit/delete
/// - Platform support: macOS keyboard shortcuts and delete command
/// - Proper alert presentation with explicit bindings
/// - Context menu for desktop interaction patterns
public struct ActionsListView: View {
    // MARK: - State

    @State private var viewModel = ActionsListViewModel()

    @State private var showingAddAction = false
    @State private var actionToEdit: Models.ActionData?
    @State private var actionToDelete: Models.ActionData?
    @State private var selectedAction: Models.ActionData?
    @State private var formData: ActionFormData?  // For Quick Add pre-filling

    // MARK: - Initialization

    public init() {}

    // MARK: - Body

    public var body: some View {
        Group {
            if viewModel.isLoading {
                // Loading state
                ProgressView("Loading actions...")
            } else if viewModel.actions.isEmpty {
                // Empty state
                emptyState
            } else {
                // Actions list
                actionsList
            }
        }
        .background(BackgroundView(.actions))  // MoodyRiver for flow and progress
        .navigationTitle("Actions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddAction = true
                } label: {
                    Label("Add Action", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .task {
            // Load actions and active goals when view appears
            await viewModel.loadActions()
            await viewModel.loadActiveGoals()
        }
        .refreshable {
            // Pull-to-refresh uses same load methods
            await viewModel.loadActions()
            await viewModel.loadActiveGoals()
        }
        .sheet(isPresented: $showingAddAction) {
            NavigationStack {
                if let data = formData {
                    // Quick Add mode (pre-filled from duplicate or goal)
                    ActionFormView(initialData: data)
                } else {
                    // Create mode (empty form)
                    ActionFormView()
                }
            }
        }
        .onChange(of: showingAddAction) { _, isShowing in
            // Clear formData and refresh when sheet is dismissed
            if !isShowing {
                formData = nil
                Task {
                    await viewModel.loadActions()
                    await viewModel.loadActiveGoals()
                }
            }
        }
        .sheet(item: $actionToEdit) { actionData in
            NavigationStack {
                ActionFormView(actionToEdit: actionData)
            }
        }
        .onChange(of: actionToEdit) { oldValue, newValue in
            // Reload list when edit sheet is dismissed
            if newValue == nil && oldValue != nil {
                Task {
                    await viewModel.loadActions()
                    await viewModel.loadActiveGoals()
                }
            }
        }
        .alert(
            "Delete Action",
            isPresented: .constant(actionToDelete != nil),
            presenting: actionToDelete
        ) { actionData in
            Button("Cancel", role: .cancel) {
                actionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                delete(actionData)
            }
        } message: { actionData in
            Text("Are you sure you want to delete '\(actionData.title ?? "this action")'?")
        }
        .alert("Error", isPresented: .constant(viewModel.hasError)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Actions Yet", systemImage: "checkmark.circle")
        } description: {
            Text("Track what you've done by adding your first action")
        } actions: {
            Button("Add Action") {
                showingAddAction = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions List

    private var actionsList: some View {
        List(selection: $selectedAction) {
            // Quick Add Section
            QuickAddSection(
                recentActions: Array(viewModel.actions.prefix(5)),
                activeGoals: Array(viewModel.activeGoals.prefix(5)),
                onDuplicateAction: { preFilledData in
                    formData = preFilledData
                    showingAddAction = true
                },
                onLogActionForGoal: { goalData in
                    // Pre-fill form with goal's first metric
                    formData = buildFormDataForGoal(goalData)
                    showingAddAction = true
                }
            )
            .listRowBackground(Color.clear)

            // Actions List
            ForEach(viewModel.actions) { actionData in
                ActionRowView(action: actionData)
                    .listRowBackground(Color.clear)  // Transparent to show background
                    .contentShape(Rectangle())  // Make entire row tappable
                    .onTapGesture {
                        edit(actionData)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            actionToDelete = actionData
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            edit(actionData)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    // Context menu for mouse/trackpad users
                    .contextMenu {
                        Button {
                            edit(actionData)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            actionToDelete = actionData
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .tag(actionData)
            }
        }
        .scrollContentBackground(.hidden)  // Hide default list background
        #if os(macOS)
        .onDeleteCommand {
            if let selected = selectedAction {
                actionToDelete = selected
            }
        }
        #endif
    }

    // MARK: - Actions

    private func edit(_ actionData: Models.ActionData) {
        actionToEdit = actionData
    }

    private func delete(_ actionData: Models.ActionData) {
        Task {
            await viewModel.deleteAction(actionData)
            actionToDelete = nil
        }
    }

    // MARK: - Quick Add Helpers

    /// Build ActionFormData for logging action toward a goal
    ///
    /// Pre-fills form with goal's first metric target (if any)
    /// and pre-selects the goal for contribution tracking
    private func buildFormDataForGoal(_ goalData: Models.GoalData) -> ActionFormData {
        // Pre-fill with goal's first metric (if any) - using flat GoalData.MeasureTarget
        let measurements: [MeasurementInput] = goalData.measureTargets.prefix(1).map { target in
            MeasurementInput(
                measureId: target.measureId,
                value: 0  // User will enter actual value
            )
        }

        return ActionFormData(
            title: "",  // User will enter title
            measurements: measurements,
            goalContributions: [goalData.id]  // Pre-select this goal
        )
    }
}
