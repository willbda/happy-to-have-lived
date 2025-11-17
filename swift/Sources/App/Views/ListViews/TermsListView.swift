//
// TermsListView.swift
// Written by Claude Code on 2025-11-02
// Refactored on 2025-11-13 to use ViewModel pattern
//
// PURPOSE: List view showing Terms with their TimePeriod details
// DATA SOURCE: TermsListViewModel (replaces @Fetch pattern)
// INTERACTIONS: Tap to edit, swipe to delete, empty state
//
// MIGRATION NOTE (2025-11-13):
// Previously used @Fetch(TermsWithPeriods()) with manual refresh trigger hack.
// Now uses TermsListViewModel directly for:
// - Better separation of concerns
// - Explicit async/await patterns
// - Easier testing and error handling
// - Consistent pattern with GoalsListView, ActionsListView, PersonalValuesListView
// - Eliminates refresh trigger hack (automatic reactivity via @Observable)
//

import Models
import SwiftUI

public struct TermsListView: View {
    @State private var viewModel = TermsListViewModel()

    @State private var showingForm = false

    /// Term being edited (nil = create mode)
    @State private var termToEdit: TimePeriodData?

    /// Selected term for keyboard navigation
    @State private var selectedTerm: TimePeriodData?

    /// Term to delete (for confirmation)
    @State private var termToDelete: TimePeriodData?

    public var body: some View {
        Group {
            if viewModel.isLoading {
                // Loading state
                ProgressView("Loading terms...")
            } else if viewModel.terms.isEmpty {
                // Empty state
                ContentUnavailableView {
                    Label("No Terms Yet", systemImage: "calendar")
                } description: {
                    Text("Organize your goals by creating your first 10-week term")
                } actions: {
                    Button("Add Term") {
                        termToEdit = nil
                        showingForm = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List(selection: $selectedTerm) {
                    ForEach(viewModel.terms) { termData in
                        TermRowView(timePeriod: termData)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Tap row → edit
                                termToEdit = termData
                                showingForm = true
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    termToDelete = termData
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    // Swipe left → edit
                                    termToEdit = termData
                                    showingForm = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            // Context menu for mouse/trackpad users
                            .contextMenu {
                                Button {
                                    termToEdit = termData
                                    showingForm = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    termToDelete = termData
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .tag(termData)
                    }
                }
                #if os(macOS)
                .onDeleteCommand {
                    if let selected = selectedTerm {
                        termToDelete = selected
                    }
                }
                #endif
            }
        }
        .navigationTitle("Terms")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    termToEdit = nil  // Create mode
                    showingForm = true
                } label: {
                    Label("Add Term", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .task {
            // Load terms when view appears
            await viewModel.loadTerms()
        }
        .refreshable {
            // Pull-to-refresh uses same load method
            await viewModel.loadTerms()
        }
        .sheet(isPresented: $showingForm) {
            // Reload when sheet dismisses (automatic via @Observable)
            Task {
                await viewModel.loadTerms()
            }
        } content: {
            NavigationStack {
                TermFormView(
                    termToEdit: termToEdit,
                    suggestedTermNumber: termToEdit == nil ? viewModel.nextTermNumber : nil
                )
            }
            // Force sheet to recreate when termToEdit changes
            // Fixes bug: clicking same term twice showed "New Term" instead of edit
            .id(termToEdit?.id)
        }
        .alert(
            "Delete Term",
            isPresented: .constant(termToDelete != nil),
            presenting: termToDelete
        ) { termData in
            Button("Cancel", role: .cancel) {
                termToDelete = nil
            }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteTerm(termData)
                    termToDelete = nil
                }
            }
        } message: { termData in
            Text("Are you sure you want to delete Term \(termData.termNumber)?")
        }
        .alert("Error", isPresented: .constant(viewModel.hasError)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}

#Preview {
    NavigationStack {
        TermsListView()
    }
}