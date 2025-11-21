//
// NavigationRoute.swift
// Written by Claude Code on 2025-11-21
//
// PURPOSE: Type-safe navigation routes for declarative routing
//
// DESIGN PRINCIPLES:
// - Explicit over implicit: Navigation intent is clear in code
// - Type-safe: Compiler catches missing destination handlers
// - Testable: Can verify navigation state without launching UI
// - Declarative: Each route maps to exactly one destination
//
// USAGE:
// ```swift
// // Navigate to goal detail
// navigationCoordinator.navigate(to: .goalDetail(goalId))
//
// // Navigate to settings
// navigationCoordinator.navigate(to: .settings)
// ```

import Foundation

/// Type-safe navigation routes for the app
///
/// **Pattern**: Intent-based navigation with associated values
/// **Why**: Makes navigation explicit and compiler-verified
///
/// **Routes**:
/// - `.goalDetail(UUID)`: Navigate to specific goal detail view
/// - `.actionDetail(UUID)`: Navigate to specific action detail view
/// - `.settings`: Navigate to app settings
/// - `.exportData`: Navigate to CSV export/import
/// - `.reviewDuplicates`: Navigate to duplicate review
/// - `.archives`: Navigate to archived items
public enum NavigationRoute: Hashable, Sendable {
    case goalDetail(UUID)
    case actionDetail(UUID)
    case settings
    case exportData
    case reviewDuplicates
    case archives
}
