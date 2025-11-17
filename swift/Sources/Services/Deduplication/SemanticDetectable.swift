//
//  SemanticDetectable.swift
//  Ten Week Goal App
//
//  Written by Claude Code on 2025-11-16
//
//  PURPOSE: Protocol for entities that support semantic duplicate detection
//  PATTERN: Protocol-oriented design for generic semantic operations
//

import Foundation

/// Protocol for entities that can be checked for semantic duplicates
///
/// Conforming types can use `SemanticDuplicateDetector` to find similar entities
/// based on text content similarity using NLEmbedding vectors.
///
/// ## Example
/// ```swift
/// extension PersonalValueData: SemanticDetectable {
///     public var semanticText: String { title }
///     // id already exists on PersonalValueData
/// }
/// ```
public protocol SemanticDetectable: Identifiable where ID == UUID {
    /// The text content to generate semantic embeddings from
    ///
    /// This should be the primary text that defines the entity's meaning.
    /// For goals: title (e.g., "Run a marathon")
    /// For values: title (e.g., "Health & Wellness")
    /// For actions: title (e.g., "Morning run 5K")
    var semanticText: String { get }
}

// MARK: - Conformances

// Import canonical DataTypes
import Models

// GoalData conformance (canonical goal type)
extension GoalData: SemanticDetectable {
    public var semanticText: String {
        title ?? "Untitled"
    }
}

// PersonalValueData conformance (canonical value type)
extension PersonalValueData: SemanticDetectable {
    public var semanticText: String {
        title
    }
}
