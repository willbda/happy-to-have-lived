//
// NavigationContainer.swift
// Written by Claude Code on 2025-11-21
//
// PURPOSE: Centralized navigation destination mapping
//
// DESIGN PRINCIPLES:
// - Single source of truth: All routes defined in one place
// - Reusable: Any view can use NavigationContainer
// - Maintainable: Adding new routes requires one change
// - Type-safe: Compiler verifies all routes are handled
//
// APPLE'S GUIDANCE:
// "Use navigationDestination(for:) to describe the view the stack displays
//  when presenting data of a given type."
//
// USAGE:
// ```swift
// NavigationStack(path: $navigationCoordinator.path) {
//     NavigationContainer {
//         HomeView()
//     }
// }
// ```

import SwiftUI

/// Container that maps NavigationRoute to destination views
///
/// **Pattern**: Declarative route mapping with type-safe enum
/// **Why**: Centralizes navigation logic, makes it easy to add new routes
///
/// **How It Works**:
/// 1. NavigationCoordinator appends route to path
/// 2. SwiftUI looks up route in .navigationDestination(for:)
/// 3. NavigationContainer returns corresponding view
/// 4. SwiftUI pushes view onto stack
///
/// **Example**:
/// ```swift
/// // In coordinator:
/// navigationCoordinator.navigate(to: .goalDetail(goalId))
///
/// // NavigationContainer maps to:
/// case .goalDetail(let goalId):
///     GoalDetailView(goalId: goalId)
/// ```
public struct NavigationContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            // Single source of truth: All navigation destinations in ONE place
            .navigationDestination(for: NavigationRoute.self) { route in
                switch route {
                case .goalDetail(let goalId):
                    GoalDetailView(goalId: goalId)

                case .actionDetail(let actionId):
                    // TODO: Create ActionDetailView
                    Text("Action Detail: \(actionId.uuidString)")
                        .navigationTitle("Action")

                case .settings:
                    // TODO: Create SettingsView
                    Text("Settings")
                        .navigationTitle("Settings")

                case .exportData:
                    CSVExportImportView()

                case .reviewDuplicates:
                    // TODO: Create DuplicateReviewView
                    Text("Review Duplicates")
                        .navigationTitle("Duplicates")

                case .archives:
                    // TODO: Create ArchivesView
                    Text("Archives")
                        .navigationTitle("Archives")
                }
            }
    }
}
