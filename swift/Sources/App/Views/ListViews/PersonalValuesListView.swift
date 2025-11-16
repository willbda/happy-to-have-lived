import Models
import SwiftUI

//
// PersonalValuesListView.swift
// Written by Claude Code on 2025-11-03
// Refactored on 2025-11-13 to use ViewModel pattern
// Refactored on 2025-11-16 to use PersonalValueData
//
// PURPOSE: List of personal values with priority and level display
// DATA SOURCE: PersonalValuesListViewModel (returns PersonalValueData)
// INTERACTIONS: Tap to edit, swipe to delete, empty state
//
// MIGRATION NOTE (2025-11-13):
// Previously used @FetchAll(PersonalValue.all) with manual Dictionary grouping.
// Now uses PersonalValuesListViewModel directly for:
// - Better separation of concerns
// - Explicit async/await patterns
// - Easier testing and error handling
// - Consistent pattern with GoalsListView and ActionsListView
//
// CANONICAL PATTERN (2025-11-16):
// - ViewModel stores PersonalValueData (canonical type)
// - Transform to PersonalValue at display boundary (via .asValue)
// - Child views (RowView, FormView) still use PersonalValue
//

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
            } else {
                List {
                    // PERFORMANCE: Dictionary grouping computed in ViewModel (O(n))
                    // Lookup per level is O(1)
                    // Database: Already sorted by valueLevel + priority via ORDER BY
                    // PATTERN: Transform PersonalValueData → PersonalValue at display boundary
                    ForEach(ValueLevel.allCases, id: \.self) { level in
                        if let levelValues = viewModel.groupedValues[level.rawValue], !levelValues.isEmpty {
                            Section(level.displayName) {
                                ForEach(levelValues) { valueData in
                                    // Transform canonical type to entity for row view
                                    PersonalValuesRowView(value: valueData.asValue)
                                        .onTapGesture {
                                            edit(valueData)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                valueToDelete = valueData
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading) {
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
                                }
                            }
                        }
                    }
                }
            }
        }
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
            NavigationStack {
                PersonalValuesFormView()
            }
        }
        .sheet(item: $valueToEdit) { valueData in
            NavigationStack {
                // Transform PersonalValueData to PersonalValue for form view
                PersonalValuesFormView(valueToEdit: valueData.asValue)
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
