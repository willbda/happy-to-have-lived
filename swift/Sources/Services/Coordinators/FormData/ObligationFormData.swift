//
// ObligationFormData.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Input DTO for ObligationCoordinator
// STRUCTURE: Combines Expectation + Obligation
// USAGE: Assembled by ObligationFormViewModel, consumed by ObligationCoordinator
//

import Foundation
import Models

/// Form data for obligation creation/editing
///
/// Captures all user input needed to create:
/// 1. Expectation (title, description, importance, urgency)
/// 2. Obligation (deadline, requestedBy, consequence)
///
/// **Pattern**: Implements ExpectationFormDataBase for shared expectation fields
/// **Usage**: Pass to ObligationCoordinator.create(from:) or update(from:)
public struct ObligationFormData: ExpectationFormDataBase, Sendable {

    // MARK: - Expectation Fields (ExpectationFormDataBase)

    public var title: String
    public var detailedDescription: String
    public var freeformNotes: String
    public var expectationImportance: Int
    public var expectationUrgency: Int

    // MARK: - Obligation Fields

    /// Deadline for this obligation
    public var deadline: Date

    /// Who requested this obligation (optional)
    public var requestedBy: String

    /// Consequence if not completed (optional)
    public var consequence: String

    // MARK: - Initialization

    public init(
        title: String = "",
        detailedDescription: String = "",
        freeformNotes: String = "",
        expectationImportance: Int = 9,  // Default higher for obligations
        expectationUrgency: Int = 9,     // Default higher for obligations
        deadline: Date = Date(),
        requestedBy: String = "",
        consequence: String = ""
    ) {
        self.title = title
        self.detailedDescription = detailedDescription
        self.freeformNotes = freeformNotes
        self.expectationImportance = expectationImportance
        self.expectationUrgency = expectationUrgency
        self.deadline = deadline
        self.requestedBy = requestedBy
        self.consequence = consequence
    }
}
