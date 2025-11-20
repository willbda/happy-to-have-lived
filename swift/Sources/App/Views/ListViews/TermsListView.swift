//
// TermsListView.swift
// Written by Claude Code on 2025-11-02
// Refactored on 2025-11-13 to use ViewModel pattern
// Refactored on 2025-11-19 for HIG compliance and consistency
//
// PURPOSE: List view showing Terms with their TimePeriod details
// DATA SOURCE: TermsListViewModel (replaces @Fetch pattern)
// INTERACTIONS: Tap to edit, swipe to delete, empty state, context menu
//

import Models
import SwiftUI

/// List view for terms (10-week planning periods)
///
/// **PATTERN**: ViewModel-based (migrated from @Fetch)
/// **DATA**: TermsListViewModel → TimePeriodRepository → Database
/// **DISPLAY**: TermRowView for each term
/// **INTERACTIONS**: Tap to edit, swipe to delete, pull to refresh, context menu
///
/// **HIG COMPLIANCE** (2025-11-19):
/// - Consistent feedback: Reload after create/edit/delete
/// - Platform support: macOS keyboard shortcuts and delete command
/// - Proper alert presentation with explicit bindings
/// - Context menu for desktop interaction patterns
public struct TermsListView: View {
    @State private var viewModel = TermsListViewModel()

    @State private var showingForm = false
    @State private var termToEdit: TimePeriodData?  // nil = create mode
    @State private var selectedTerm: TimePeriodData?  // For keyboard navigation
    @State private var termToDelete: TimePeriodData?  // For confirmation

    public var body: some View {
        Group {
            if viewModel.isLoading {
                // Loading state
                ProgressView("Loading terms...")
            } else if viewModel.terms.isEmpty {
                // Empty state
                emptyState
            } else {
                // Terms list
                termsList
            }
        }
        .background(.regularMaterial)  // System material with automatic Liquid Glass
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

    // MARK: - Empty State

    private var emptyState: some View {
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
    }

    // MARK: - Terms List

    private var termsList: some View {
        List(selection: $selectedTerm) {
            ForEach(viewModel.terms) { termData in
                TermRowView(timePeriod: termData)
                    .onTapGesture {
                        edit(termData)
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
                            edit(termData)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    // Context menu for mouse/trackpad users
                    .contextMenu {
                        Button {
                            edit(termData)
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
        #if os(iOS)
        .listStyle(.insetGrouped)  // iOS: Inset grouped style with Liquid Glass
        #else
        .listStyle(.inset)  // macOS: Inset style (native macOS appearance)
        #endif
        #if os(macOS)
        .onDeleteCommand {
            if let selected = selectedTerm {
                termToDelete = selected
            }
        }
        #endif
    }

    // MARK: - Actions

    private func edit(_ termData: TimePeriodData) {
        termToEdit = termData
        showingForm = true
    }
}

#Preview {
    NavigationStack {
        TermsListView()
    }
}
