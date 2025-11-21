//
// ActionsListView.swift
// Written by Claude Code on 2025-11-02
// Refactored on 2025-11-13 to use ViewModel pattern
// Refactored on 2025-11-19 for HIG compliance and consistency
// Refactored on 2025-11-20 to use DataStore (declarative pattern)
//
// PURPOSE: List view for Actions with measurements and goal contributions
// DATA SOURCE: DataStore (environment object, single source of truth)
// INTERACTIONS: Tap to edit, swipe to delete, pull to refresh, context menu
//

import SwiftUI
import Models
import Services

/// Main list view for Actions
///
/// **PATTERN**: Declarative SwiftUI with DataStore (Apple's recommended pattern)
/// **DATA**: DataStore (environment) → Observable state → Automatic UI updates
/// **DISPLAY**: ActionRowView for each action + QuickAddSection
/// **INTERACTIONS**: Tap to edit, swipe to delete, pull to refresh, context menu
///
/// **DECLARATIVE ARCHITECTURE** (2025-11-20):
/// - No manual refresh calls (DataStore updates propagate automatically)
/// - No separate ViewModels (DataStore is single source of truth)
/// - Truly reactive (views observe DataStore via @Environment)
/// - Follows Apple's sample code pattern (AddRichGraphicsToYourSwiftUIApp)
public struct ActionsListView: View {
    @Environment(DataStore.self) private var dataStore

    @State private var showingAddAction = false
    @State private var actionToEdit: Models.ActionData?
    @State private var actionToDelete: Models.ActionData?
    @State private var selectedAction: Models.ActionData?
    @State private var formData: ActionFormData?  // For Quick Add pre-filling

    public init() {}

    // MARK: - Body

    public var body: some View {
        mainContent
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
            .refreshable {
                // Pull-to-refresh reloads from database
                await dataStore.loadActions()
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
            // NO onDismiss needed - DataStore updates automatically!
            .sheet(item: $actionToEdit) { actionData in
                NavigationStack {
                    ActionFormView(actionToEdit: actionData)
                }
            }
            // NO onDismiss needed - DataStore updates automatically!
            .alert("Delete Action", isPresented: .constant(actionToDelete != nil), presenting: actionToDelete) { actionData in
                Button("Cancel", role: .cancel) {
                    actionToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    delete(actionData)
                }
            } message: { actionData in
                Text("Are you sure you want to delete '\(actionData.title ?? "this action")'?")
            }
            .alert("Error", isPresented: .constant(dataStore.errorMessage != nil)) {
                Button("OK") {
                    // Error will clear on next operation
                }
            } message: {
                Text(dataStore.errorMessage ?? "Unknown error")
            }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if dataStore.isLoading {
            // Loading state
            ProgressView("Loading actions...")
        } else if dataStore.actions.isEmpty {
            // Empty state
            emptyState
        } else {
            // Actions list
            actionsList
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
                recentActions: Array(dataStore.actions.prefix(5)),
                activeGoals: Array(dataStore.activeGoals.prefix(5)),
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

            // Actions List
            ForEach(dataStore.actions) { actionData in
                ActionRowView(action: actionData)
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
        #if os(iOS)
        .listStyle(.insetGrouped)  // iOS: Inset grouped style with Liquid Glass
        #else
        .listStyle(.inset)  // macOS: Inset style (native macOS appearance)
        #endif
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
            try? await dataStore.deleteAction(actionData)
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
