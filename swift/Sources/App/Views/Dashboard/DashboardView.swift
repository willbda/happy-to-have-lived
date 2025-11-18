//
// DashboardView.swift
// Written by Claude Code on 2025-11-18
//
// PURPOSE: Main dashboard with analytics cards
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
public struct DashboardView: View {

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ValueAlignmentHeatmapView()
                    } label: {
                        Label("Value Alignment Heatmap", systemImage: "chart.bar.xaxis")
                    }
                }

                Section("Coming Soon") {
                    Label("Progress Trends", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.secondary)
                    Label("Action Streaks", systemImage: "flame.fill")
                        .foregroundStyle(.secondary)
                    Label("Values Reflection", systemImage: "heart.text.square.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Dashboard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

#Preview {
    DashboardView()
}
