//
// ObligationsListView.swift
// Written by Claude Code on 2025-11-19
// Refactored by Claude Code on 2025-11-20 - Uses DataStore (declarative pattern)
//
// PURPOSE: List of obligations with deadlines
// DATA SOURCE: DataStore (ValueObservation for automatic updates)
// INTERACTIONS: Tap to view, swipe to delete, empty state
//

import Models
import Services
import SwiftUI

/// List view for obligations
///
/// **PATTERN**: DataStore-based (declarative pattern, consistent with Goals/Actions/Values/Terms/Milestones)
/// **DATA**: DataStore → ValueObservation → Automatic UI updates
/// **DISPLAY**: ObligationRowView for each obligation
/// **INTERACTIONS**: Swipe to delete, pull to refresh
///
public struct ObligationsListView: View {
    @Environment(DataStore.self) private var dataStore

    @State private var showingAddObligation = false
    @State private var obligationToDelete: ObligationWithDetails?
    @State private var showingDeleteAlert = false

    public init() {}

    public var body: some View {
        Group {
            if dataStore.isLoading {
                // Loading state
                ProgressView("Loading obligations...")
            } else if dataStore.obligations.isEmpty {
                // Empty state
                ContentUnavailableView {
                    Label("No Obligations Yet", systemImage: "checkmark.circle")
                } description: {
                    Text("Add your first obligation to track commitments")
                } actions: {
                    Button("Add Obligation") {
                        showingAddObligation = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Obligation list
                List {
                    ForEach(dataStore.obligations) { obligationData in
                        ObligationRowView(obligation: obligationData)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    obligationToDelete = obligationData
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Obligations")
        .errorAlert(dataStore: dataStore)  // ✅ Unified error handling
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddObligation = true
                } label: {
                    Label("Add Obligation", systemImage: "plus")
                }
            }
        }
        .refreshable {
            // Manual refresh (ValueObservation handles automatic updates)
            await dataStore.loadObligations()
        }
        .sheet(isPresented: $showingAddObligation) {
            NavigationStack {
                ObligationFormView()
            }
        }
        .alert("Delete Obligation?", isPresented: $showingDeleteAlert, presenting: obligationToDelete) { obligationData in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await dataStore.deleteObligation(obligationData)
                    obligationToDelete = nil
                }
            }
        } message: { obligationData in
            Text("Are you sure you want to delete \"\(obligationData.expectation.title ?? "this obligation")\"?")
        }
    }
}
