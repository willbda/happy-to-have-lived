//
// ObligationsListView.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: List of obligations with deadlines
// DATA SOURCE: ObligationsListViewModel
// INTERACTIONS: Tap to view, swipe to delete, empty state
//

import Models
import Services
import SwiftUI

/// List view for obligations
///
/// **PATTERN**: ViewModel-based (same pattern as MilestonesListView)
/// **DATA**: ObligationsListViewModel → ObligationRepository → Database
/// **DISPLAY**: ObligationRowView for each obligation
/// **INTERACTIONS**: Swipe to delete, pull to refresh
///
public struct ObligationsListView: View {
    @State private var viewModel = ObligationsListViewModel()

    @State private var showingAddObligation = false
    @State private var obligationToDelete: ObligationWithDetails?
    @State private var showingDeleteAlert = false

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading {
                // Loading state
                ProgressView("Loading obligations...")
            } else if viewModel.obligations.isEmpty {
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
                    ForEach(viewModel.obligations) { obligationData in
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddObligation = true
                } label: {
                    Label("Add Obligation", systemImage: "plus")
                }
            }
        }
        .task {
            // Load obligations when view appears
            await viewModel.loadObligations()
        }
        .refreshable {
            // Pull-to-refresh uses same load method
            await viewModel.loadObligations()
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
                    await viewModel.deleteObligation(obligationData)
                }
            }
        } message: { obligationData in
            Text("Are you sure you want to delete \"\(obligationData.expectation.title ?? "this obligation")\"?")
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
