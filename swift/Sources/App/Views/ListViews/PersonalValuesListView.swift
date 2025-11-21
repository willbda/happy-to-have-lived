//
// PersonalValuesListView.swift
// Written by Claude Code on 2025-11-03
// Refactored on 2025-11-13 to use ViewModel pattern
// Refactored on 2025-11-16 to use PersonalValueData
// Refactored on 2025-11-19 for HIG compliance and consistency
// Refactored on 2025-11-20 to use DataStore (declarative pattern)
//
// PURPOSE: List of personal values with priority and level display
// DATA SOURCE: DataStore (environment object, single source of truth)
// INTERACTIONS: Tap to edit, swipe to delete, empty state, context menu
//

import Models
import SwiftUI

/// List view for personal values
///
/// **PATTERN**: Declarative SwiftUI with DataStore (Apple's recommended pattern)
/// **DATA**: DataStore (environment) → Observable state → Automatic UI updates
/// **DISPLAY**: PersonalValuesRowView for each value (grouped by level)
/// **INTERACTIONS**: Tap to edit, swipe to delete, pull to refresh, context menu
///
/// **DECLARATIVE ARCHITECTURE** (2025-11-20):
/// - No manual refresh calls (DataStore updates propagate automatically)
/// - No separate ViewModels (DataStore is single source of truth)
/// - Truly reactive (views observe DataStore via @Environment)
/// - Follows Apple's sample code pattern (AddRichGraphicsToYourSwiftUIApp)
public struct PersonalValuesListView: View {
    @Environment(DataStore.self) private var dataStore

    @State private var showingAddValue = false
    @State private var valueToEdit: PersonalValueData?
    @State private var valueToDelete: PersonalValueData?
    @State private var selectedValue: PersonalValueData?

    public init() {}

    public var body: some View {
        mainContent
            .navigationTitle("Values")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddValue = true
                    } label: {
                        Label("Add Value", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
            .refreshable {
                await dataStore.loadValues()
            }
            .sheet(isPresented: $showingAddValue) {
                NavigationStack {
                    PersonalValuesFormView()
                }
            }
            // NO onDismiss needed - DataStore updates automatically!
            .sheet(item: $valueToEdit) { valueData in
                NavigationStack {
                    PersonalValuesFormView(valueToEdit: valueData)
                }
            }
            // NO onDismiss needed - DataStore updates automatically!
            .alert("Delete Value", isPresented: .constant(valueToDelete != nil), presenting: valueToDelete) { valueData in
                Button("Cancel", role: .cancel) {
                    valueToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    delete(valueData)
                }
            } message: { valueData in
                Text("Are you sure you want to delete '\(valueData.title)'?")
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
            ProgressView("Loading values...")
        } else if dataStore.values.isEmpty {
            // Empty state
            emptyState
        } else {
            // Values list
            valuesList
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Values Yet", systemImage: "heart")
        } description: {
            Text("Define what matters to you by adding your first personal value")
        } actions: {
            Button("Add Value") {
                showingAddValue = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Values List

    private var valuesList: some View {
        List(selection: $selectedValue) {
            // Group values by level for sectioned display
            // Database returns values sorted by priority
            ForEach(ValueLevel.allCases, id: \.self) { level in
                let levelValues = dataStore.values.filter { $0.valueLevel == level.rawValue }
                if !levelValues.isEmpty {
                    Section(level.displayName) {
                        ForEach(levelValues) { valueData in
                            PersonalValuesRowView(value: valueData)
                                .onTapGesture {
                                    edit(valueData)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        valueToDelete = valueData
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        edit(valueData)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                // Context menu for mouse/trackpad users
                                .contextMenu {
                                    Button {
                                        edit(valueData)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        valueToDelete = valueData
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .tag(valueData)
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)  // iOS: Inset grouped style with Liquid Glass
        #else
        .listStyle(.inset)  // macOS: Inset style (native macOS appearance)
        #endif
        #if os(macOS)
        .onDeleteCommand {
            if let selected = selectedValue {
                valueToDelete = selected
            }
        }
        #endif
    }

    // MARK: - Actions

    private func edit(_ valueData: PersonalValueData) {
        valueToEdit = valueData
    }

    private func delete(_ valueData: PersonalValueData) {
        Task {
            try? await dataStore.deleteValue(valueData)
            valueToDelete = nil
        }
    }
}
