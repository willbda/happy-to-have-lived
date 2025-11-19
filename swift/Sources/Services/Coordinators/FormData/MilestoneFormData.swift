//
// MilestoneFormData.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Input DTO for MilestoneCoordinator
// STRUCTURE: Combines Expectation + Milestone
// USAGE: Assembled by MilestoneFormViewModel, consumed by MilestoneCoordinator
//

import Foundation
import Models

/// Form data for milestone creation/editing
///
/// Captures all user input needed to create:
/// 1. Expectation (title, description, importance, urgency)
/// 2. Milestone (targetDate)
///
/// **Pattern**: Implements ExpectationFormDataBase for shared expectation fields
/// **Usage**: Pass to MilestoneCoordinator.create(from:) or update(from:)
public struct MilestoneFormData: ExpectationFormDataBase, Sendable {

    // MARK: - Expectation Fields (ExpectationFormDataBase)

    public var title: String
    public var detailedDescription: String
    public var freeformNotes: String
    public var expectationImportance: Int
    public var expectationUrgency: Int

    // MARK: - Milestone Fields

    /// Target date for this milestone (point-in-time)
    public var targetDate: Date

    // MARK: - Initialization

    public init(
        title: String = "",
        detailedDescription: String = "",
        freeformNotes: String = "",
        expectationImportance: Int = 8,  // Default for milestones
        expectationUrgency: Int = 7,     // Default for milestones
        targetDate: Date = Date()
    ) {
        self.title = title
        self.detailedDescription = detailedDescription
        self.freeformNotes = freeformNotes
        self.expectationImportance = expectationImportance
        self.expectationUrgency = expectationUrgency
        self.targetDate = targetDate
    }
}
