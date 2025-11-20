//
// PersonalValuesListView.swift
// Written by Claude Code on 2025-11-03
// Refactored on 2025-11-13 to use ViewModel pattern
// Refactored on 2025-11-16 to use PersonalValueData
// Refactored on 2025-11-19 for HIG compliance and consistency
//
// PURPOSE: List of personal values with priority and level display
// DATA SOURCE: PersonalValuesListViewModel (returns PersonalValueData)
// INTERACTIONS: Tap to edit, swipe to delete, empty state, context menu
//

import Models
import SwiftUI

/// List view for personal values
///
/// **PATTERN**: ViewModel-based (migrated from @FetchAll)
/// **DATA**: PersonalValuesListViewModel → PersonalValueRepository → Database
/// **DISPLAY**: PersonalValuesRowView for each value (grouped by level)
/// **INTERACTIONS**: Tap to edit, swipe to delete, pull to refresh, context menu
///
/// **HIG COMPLIANCE** (2025-11-19):
/// - Consistent feedback: Reload after create/edit/delete
/// - Platform support: macOS keyboard shortcuts and delete command
/// - Proper alert presentation with explicit bindings
/// - Context menu for desktop interaction patterns
/// - Sectioned list with clear hierarchy
public struct PersonalValuesListView: View {
    @State private var viewModel = PersonalValuesListViewModel()

    @State private var showingAddValue = false
    @State private var valueToEdit: PersonalValueData?
    @State private var valueToDelete: PersonalValueData?
    @State private var selectedValue: PersonalValueData?  // For keyboard navigation

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading {
                // Loading state
                ProgressView("Loading values...")
            } else if viewModel.values.isEmpty {
                // Empty state
                emptyState
            } else {
                // Values list
                valuesList
            }
        }
        .background(.regularMaterial)  // System material with automatic Liquid Glass
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
        .task {
            // Load values when view appears
            await viewModel.loadValues()
        }
        .refreshable {
            // Pull-to-refresh uses same load method
            await viewModel.loadValues()
        }
        .sheet(isPresented: $showingAddValue) {
            // Reload when sheet dismisses
            Task {
                await viewModel.loadValues()
            }
        } content: {
            NavigationStack {
                PersonalValuesFormView()
            }
        }
        .sheet(item: $valueToEdit) { valueData in
            NavigationStack {
                PersonalValuesFormView(valueToEdit: valueData)
            }
        }
        .onChange(of: valueToEdit) { oldValue, newValue in
            // Reload list when edit sheet is dismissed
            if newValue == nil && oldValue != nil {
                Task {
                    await viewModel.loadValues()
                }
            }
        }
        .alert(
            "Delete Value",
            isPresented: .constant(valueToDelete != nil),
            presenting: valueToDelete
        ) { valueData in
            Button("Cancel", role: .cancel) {
                valueToDelete = nil
            }
            Button("Delete", role: .destructive) {
                delete(valueData)
            }
        } message: { valueData in
            Text("Are you sure you want to delete '\(valueData.title)'?")
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
            // PERFORMANCE: Dictionary grouping computed in ViewModel (O(n))
            // Lookup per level is O(1)
            // Database: Already sorted by valueLevel + priority via ORDER BY
            ForEach(ValueLevel.allCases, id: \.self) { level in
                if let levelValues = viewModel.groupedValues[level.rawValue], !levelValues.isEmpty {
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
            await viewModel.deleteValue(valueData)
            valueToDelete = nil
        }
    }
}
