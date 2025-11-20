//
// UtilitiesMenuView.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Central menu for debug and utility features
// PATTERN: Simple navigation list to specialized tools
//
// ACCESSIBLE FROM: Dashboard (gear icon) or development builds
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
public struct UtilitiesMenuView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        EmbeddingManagementView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Embedding Management")
                                Text("View stats, purge orphaned, regenerate")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "brain")
                                .foregroundStyle(.purple)
                        }
                    }

                    NavigationLink {
                        MeasureDeduplicationView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Measure Deduplication")
                                Text("Find and merge duplicate measures")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "ruler")
                                .foregroundStyle(.blue)
                        }
                    }

                    NavigationLink {
                        SyncDebugView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("CloudKit Sync Debug")
                                Text("View sync status and force sync")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "icloud")
                                .foregroundStyle(.cyan)
                        }
                    }
                } header: {
                    Text("Database & Sync")
                }

                Section {
                    Label {
                        VStack(alignment: .leading) {
                            Text("App Version")
                            Text("0.7.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "info.circle")
                    }

                    Label {
                        VStack(alignment: .leading) {
                            Text("Platform")
                            Group {
                                #if os(iOS)
                                Text("iOS 26+")
                                #elseif os(macOS)
                                Text("macOS 26+")
                                #else
                                Text("visionOS 26+")
                                #endif
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "app.badge")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Utilities")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

#Preview {
    UtilitiesMenuView()
}
