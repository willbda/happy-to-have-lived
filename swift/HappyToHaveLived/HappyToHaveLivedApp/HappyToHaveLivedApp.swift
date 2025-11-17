//
//  HappyToHaveLivedApp.swift
//  Happy to Have Lived
//
//  Created by David Williams on 11/1/25.
//

import SwiftUI
import Database  // DatabaseBootstrap for initialization
import App
import Dependencies
import SQLiteData  // For #sql macro

@main
struct HappyToHaveLivedApp: App {
    @State private var isPerformingInitialSync = false

    init() {
        // Initialize database and CloudKit sync
        DatabaseBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay(alignment: .top) {
                    if isPerformingInitialSync {
                        HStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Syncing with iCloud...")
                                .font(.subheadline)
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 8)
                    }
                }
                .task {
                    await performInitialSyncIfNeeded()
                }
        }
    }

    /// Wait for CloudKit sync to complete on first launch
    ///
    /// When the app starts, SyncEngine is started in DatabaseBootstrap, but the actual
    /// CKSyncEngine fetch begins asynchronously. We need to wait for it to start AND complete.
    private func performInitialSyncIfNeeded() async {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.defaultSyncEngine) var syncEngine

        // Check if database is empty (fresh install or deleted data)
        let isEmpty = (try? await database.read { db in
            try #sql("SELECT COUNT(*) FROM goals", as: Int.self).fetchOne(db) == 0
        }) ?? false

        guard isEmpty else {
            print("📊 Database has existing data, skipping initial sync wait")
            return
        }

        print("📥 Fresh install detected - waiting for CloudKit sync...")
        isPerformingInitialSync = true

        // PROBLEM: SyncEngine.start() is async - the fetch hasn't begun yet
        // SOLUTION: Wait for isSynchronizing to become TRUE first (sync started)
        //           Then wait for it to become FALSE (sync completed)

        // Phase 1: Wait for sync to START (up to 5 seconds)
        var startIterations = 0
        let maxStartIterations = 50 // 5 seconds at 100ms intervals

        while !syncEngine.isSynchronizing && startIterations < maxStartIterations {
            try? await Task.sleep(for: .milliseconds(100))
            startIterations += 1
        }

        if startIterations >= maxStartIterations {
            print("⚠️ Sync never started after 5 seconds - continuing anyway")
            isPerformingInitialSync = false
            return
        }

        print("📊 Sync started after \(startIterations * 100)ms, waiting for completion...")

        // Phase 2: Wait for sync to COMPLETE (up to 60 seconds)
        var completeIterations = 0
        let maxCompleteIterations = 600 // 60 seconds at 100ms intervals

        while syncEngine.isSynchronizing && completeIterations < maxCompleteIterations {
            try? await Task.sleep(for: .milliseconds(100))
            completeIterations += 1
        }

        if completeIterations >= maxCompleteIterations {
            print("⚠️ Sync timed out after 60 seconds")
        } else {
            print("✅ Initial CloudKit sync complete (\(completeIterations * 100)ms)")
        }

        isPerformingInitialSync = false
    }
}
