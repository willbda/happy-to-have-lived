//
// TermsListView.swift
// Written by Claude Code on 2025-11-02
// Refactored on 2025-11-13 to use ViewModel pattern
// Refactored on 2025-11-19 for HIG compliance and consistency
// Refactored on 2025-11-20 to use DataStore (declarative pattern)
//
// PURPOSE: List view showing Terms with their TimePeriod details
// DATA SOURCE: DataStore (environment object, single source of truth)
// INTERACTIONS: Tap to edit, swipe to delete, empty state, context menu
//

import Models
import SwiftUI

/// List view for terms (10-week planning periods)
///
/// **PATTERN**: Declarative SwiftUI with DataStore (Apple's recommended pattern)
/// **DATA**: DataStore (environment) → Observable state → Automatic UI updates
/// **DISPLAY**: TermRowView for each term
/// **INTERACTIONS**: Tap to edit, swipe to delete, pull to refresh, context menu
///
/// **DECLARATIVE ARCHITECTURE** (2025-11-20):
/// - No manual refresh calls (DataStore updates propagate automatically)
/// - No separate ViewModels (DataStore is single source of truth)
/// - Truly reactive (views observe DataStore via @Environment)
/// - Follows Apple's sample code pattern (AddRichGraphicsToYourSwiftUIApp)
public struct TermsListView: View {
    @Environment(DataStore.self) private var dataStore

    @State private var showingForm = false
    @State private var termToEdit: TimePeriodData?
    @State private var selectedTerm: TimePeriodData?
    @State private var termToDelete: TimePeriodData?

    public var body: some View {
        Group {
            if dataStore.isLoading {
                // Loading state
                ProgressView("Loading terms...")
            } else if dataStore.terms.isEmpty {
                // Empty state
                emptyState
            } else {
                // Terms list
                termsList
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
        .refreshable {
            await dataStore.loadTerms()
        }
        .sheet(isPresented: $showingForm) {
            NavigationStack {
                TermFormView(
                    termToEdit: termToEdit,
                    suggestedTermNumber: termToEdit == nil ? nextTermNumber : nil
                )
            }
            // Force sheet to recreate when termToEdit changes
            // Fixes bug: clicking same term twice showed "New Term" instead of edit
            .id(termToEdit?.id)
        }
        // NO onDismiss needed - DataStore updates automatically!
        .alert("Delete Term", isPresented: .constant(termToDelete != nil), presenting: termToDelete) { termData in
            Button("Cancel", role: .cancel) {
                termToDelete = nil
            }
            Button("Delete", role: .destructive) {
                delete(termData)
            }
        } message: { termData in
            Text("Are you sure you want to delete Term \(termData.termNumber)?")
        }
        .alert("Error", isPresented: .constant(dataStore.errorMessage != nil)) {
            Button("OK") {
                // Error will clear on next operation
            }
        } message: {
            Text(dataStore.errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Computed Properties

    private var nextTermNumber: Int {
        (dataStore.terms.map { $0.termNumber }.max() ?? 0) + 1
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
            ForEach(dataStore.terms) { termData in
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

    private func delete(_ termData: TimePeriodData) {
        Task {
            try? await dataStore.deleteTerm(termData)
            termToDelete = nil
        }
    }
}

#Preview {
    NavigationStack {
        TermsListView()
    }
}
