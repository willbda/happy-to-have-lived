//
// EmbeddingSourceTextBuilders.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// Build normalized source text for embedding generation from entity data.
// Provides both title-only and full-context variants for each entity type.
//
// DESIGN DECISIONS:
// - Normalization: Lowercase, collapsed whitespace, trimmed
// - Two variants per entity:
//   * Title-only: Fast duplicate detection (3KB vector)
//   * Full-context: Rich semantic search for LLM RAG (3KB vector)
// - Consistent field ordering for stable hash generation
// - Optional fields handled gracefully (skip if nil)
//
// USAGE:
// ```swift
// // Title-only for duplicate detection
// let text = EmbeddingSourceTextBuilders.buildGoalSource(goal, variant: .titleOnly)
// let embedding = try await semanticService.generateEmbedding(for: text)
//
// // Full-context for semantic search
// let text = EmbeddingSourceTextBuilders.buildGoalSource(goal, variant: .fullContext)
// let embedding = try await semanticService.generateEmbedding(for: text)
// ```

import Foundation
import Models

/// Variant of embedding source text to generate
///
/// **Database Storage**:
/// These enum cases map to database `sourceVariant` values:
/// - `.titleOnly` → 'title_only'
/// - `.fullContext` → 'full_context'
///
/// **Storage Pattern**:
/// Each entity can have TWO embeddings (same entityId, different sourceVariant):
/// ```sql
/// SELECT * FROM semanticEmbeddings WHERE entityId = ? AND sourceVariant = 'title_only'
/// SELECT * FROM semanticEmbeddings WHERE entityId = ? AND sourceVariant = 'full_context'
/// ```
public enum EmbeddingSourceVariant: String, Sendable, Codable {
    /// Title-only: For duplicate detection and quick similarity checks
    /// Database value: 'title_only'
    case titleOnly = "title_only"

    /// Full-context: For semantic search and LLM RAG
    /// Database value: 'full_context'
    case fullContext = "full_context"
}

/// Builds normalized source text for embedding generation
///
/// **Normalization Strategy**:
/// - Convert to lowercase (case-insensitive matching)
/// - Collapse multiple whitespace to single space
/// - Trim leading/trailing whitespace
/// - Skip nil fields
///
/// **Field Ordering**:
/// - Title always first (most important signal)
/// - Description second (context)
/// - Freeform notes last (user annotations)
/// - Domain-specific fields in logical order
public enum EmbeddingSourceTextBuilders {

    // MARK: - Goal Source Text

    /// Build source text for Goal embedding
    ///
    /// **Title-Only Variant**:
    /// - Just the goal title (for duplicate detection)
    /// - Example: "run a marathon this year"
    ///
    /// **Full-Context Variant**:
    /// - Title + description + notes + action plan + measure targets + aligned values
    /// - Example: "run a marathon this year. complete 26.2 miles by december. train 4x/week. targets: 120 km. values: health, discipline"
    ///
    /// - Parameters:
    ///   - goal: Goal data to build source text from
    ///   - variant: Title-only or full-context variant
    /// - Returns: Normalized source text ready for embedding
    public static func buildGoalSource(_ goal: GoalData, variant: EmbeddingSourceVariant) -> String {
        switch variant {
        case .titleOnly:
            return normalize(goal.title ?? "")

        case .fullContext:
            var parts: [String] = []

            // Core semantic fields
            if let title = goal.title {
                parts.append(title)
            }
            if let description = goal.detailedDescription {
                parts.append(description)
            }
            if let notes = goal.freeformNotes {
                parts.append(notes)
            }
            if let actionPlan = goal.actionPlan {
                parts.append(actionPlan)
            }

            // Measure targets (semantic context: "120 km", "52 occasions")
            if !goal.measureTargets.isEmpty {
                let targets = goal.measureTargets.map { target in
                    "\(target.targetValue) \(target.measureUnit)"
                }.joined(separator: ", ")
                parts.append("targets: \(targets)")
            }

            // Aligned values (semantic context: values this goal serves)
            if !goal.valueAlignments.isEmpty {
                let values = goal.valueAlignments.map { $0.valueTitle }.joined(separator: ", ")
                parts.append("values: \(values)")
            }

            return normalize(parts.joined(separator: ". "))
        }
    }

    // MARK: - Action Source Text

    /// Build source text for Action embedding
    ///
    /// **Title-Only Variant**:
    /// - Just the action title
    /// - Example: "ran 10km this morning"
    ///
    /// **Full-Context Variant**:
    /// - Title + description + notes + measurements + contributing goals
    /// - Example: "ran 10km this morning. easy pace in park. measurements: 10.2 km. contributing to: marathon training, fitness"
    ///
    /// - Parameters:
    ///   - action: Action data to build source text from
    ///   - variant: Title-only or full-context variant
    /// - Returns: Normalized source text ready for embedding
    public static func buildActionSource(_ action: ActionData, variant: EmbeddingSourceVariant) -> String {
        switch variant {
        case .titleOnly:
            return normalize(action.title ?? "")

        case .fullContext:
            var parts: [String] = []

            // Core semantic fields
            if let title = action.title {
                parts.append(title)
            }
            if let description = action.detailedDescription {
                parts.append(description)
            }
            if let notes = action.freeformNotes {
                parts.append(notes)
            }

            // Measurements (semantic context: what was measured)
            if !action.measurements.isEmpty {
                let measurements = action.measurements.map { measurement in
                    "\(measurement.value) \(measurement.measureUnit)"
                }.joined(separator: ", ")
                parts.append("measurements: \(measurements)")
            }

            // Contributing goals (semantic context: what this action advances)
            if !action.contributions.isEmpty {
                let goals = action.contributions.compactMap { $0.goalTitle }.joined(separator: ", ")
                if !goals.isEmpty {
                    parts.append("contributing to: \(goals)")
                }
            }

            return normalize(parts.joined(separator: ". "))
        }
    }

    // MARK: - PersonalValue Source Text

    /// Build source text for PersonalValue embedding
    ///
    /// **Title-Only Variant**:
    /// - Just the value title
    /// - Example: "family"
    ///
    /// **Full-Context Variant**:
    /// - Title + description + notes + alignment guidance + life domain
    /// - Example: "family. time with wife and kids. balance work with presence. guidance: prioritize family dinners. domain: relationships"
    ///
    /// - Parameters:
    ///   - value: PersonalValue data to build source text from
    ///   - variant: Title-only or full-context variant
    /// - Returns: Normalized source text ready for embedding
    public static func buildValueSource(_ value: PersonalValueData, variant: EmbeddingSourceVariant) -> String {
        switch variant {
        case .titleOnly:
            return normalize(value.title)

        case .fullContext:
            var parts: [String] = []

            // Core semantic fields
            parts.append(value.title)
            if let description = value.detailedDescription {
                parts.append(description)
            }
            if let notes = value.freeformNotes {
                parts.append(notes)
            }

            // Alignment guidance (semantic context: how to live this value)
            if let guidance = value.alignmentGuidance {
                parts.append("guidance: \(guidance)")
            }

            // Life domain (semantic context: categorization)
            if let domain = value.lifeDomain {
                parts.append("domain: \(domain)")
            }

            return normalize(parts.joined(separator: ". "))
        }
    }

    // MARK: - Measure Source Text

    /// Build source text for Measure embedding
    ///
    /// **Title-Only Variant**:
    /// - Unit + measure type (compound semantic key)
    /// - Example: "km distance"
    ///
    /// **Full-Context Variant**:
    /// - Unit + measure type + title + description + notes
    /// - Example: "km distance. kilometers. distance traveled by running or cycling. use for all cardio activities"
    ///
    /// **Design Note**:
    /// Title-only uses unit+type (not title) because semantic similarity
    /// is based on measurement semantics, not custom labels.
    /// This enables: "km" ≈ "kilometers" ≈ "killometers" (typo)
    ///
    /// - Parameters:
    ///   - measure: Measure data to build source text from
    ///   - variant: Title-only or full-context variant
    /// - Returns: Normalized source text ready for embedding
    public static func buildMeasureSource(_ measure: MeasureData, variant: EmbeddingSourceVariant) -> String {
        switch variant {
        case .titleOnly:
            // Use unit + measureType as semantic key (not custom title)
            return normalize("\(measure.unit) \(measure.measureType)")

        case .fullContext:
            var parts: [String] = []

            // Semantic key first
            parts.append("\(measure.unit) \(measure.measureType)")

            // Custom title (if different from unit)
            if let title = measure.title, title.lowercased() != measure.unit.lowercased() {
                parts.append(title)
            }

            // Context fields
            if let description = measure.detailedDescription {
                parts.append(description)
            }
            if let notes = measure.freeformNotes {
                parts.append(notes)
            }

            return normalize(parts.joined(separator: ". "))
        }
    }

    // MARK: - TimePeriod Source Text

    /// Build source text for TimePeriod (with GoalTerm semantics) embedding
    ///
    /// **Title-Only Variant**:
    /// - Term number + theme (if present) or title
    /// - Example: "term 1 build foundation"
    ///
    /// **Full-Context Variant**:
    /// - Term number + theme + title + reflection + status
    /// - Example: "term 1 build foundation. q1 2025. established running habit and meal prep. status: completed"
    ///
    /// **Design Note**:
    /// Embeddings capture planning semantics (theme, reflection) not just dates.
    /// Enables: "build foundation" ≈ "establish habits" ≈ "create routine"
    ///
    /// - Parameters:
    ///   - period: TimePeriod data to build source text from
    ///   - variant: Title-only or full-context variant
    /// - Returns: Normalized source text ready for embedding
    public static func buildTimePeriodSource(_ period: TimePeriodData, variant: EmbeddingSourceVariant) -> String {
        switch variant {
        case .titleOnly:
            // Use term number + theme as semantic key
            var key = "term \(period.termNumber)"
            if let theme = period.theme {
                key += " \(theme)"
            } else if let title = period.timePeriodTitle {
                key += " \(title)"
            }
            return normalize(key)

        case .fullContext:
            var parts: [String] = []

            // Semantic key
            parts.append("term \(period.termNumber)")

            // Theme (planning semantic)
            if let theme = period.theme {
                parts.append(theme)
            }

            // Title (chronological label)
            if let title = period.timePeriodTitle {
                parts.append(title)
            }

            // Reflection (retrospective semantic)
            if let reflection = period.reflection {
                parts.append(reflection)
            }

            // Status (lifecycle semantic)
            if let status = period.status {
                parts.append("status: \(status)")
            }

            return normalize(parts.joined(separator: ". "))
        }
    }

    // MARK: - Private Normalization

    /// Normalize text for consistent embedding generation
    ///
    /// **Operations**:
    /// 1. Convert to lowercase (case-insensitive)
    /// 2. Collapse multiple whitespace to single space
    /// 3. Trim leading/trailing whitespace
    ///
    /// **Why**:
    /// - "Run Marathon" and "run marathon" should have identical embeddings
    /// - "Run  Marathon" (double space) and "Run Marathon" should match
    /// - Whitespace changes shouldn't invalidate cache
    ///
    /// - Parameter text: Raw text to normalize
    /// - Returns: Normalized text ready for embedding
    private static func normalize(_ text: String) -> String {
        // Lowercase
        let lowercased = text.lowercased()

        // Collapse whitespace (replace runs of whitespace with single space)
        let collapsed = lowercased.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        // Trim
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Usage Examples

/*
 // Goal duplicate detection (title-only)
 let titleText = EmbeddingSourceTextBuilders.buildGoalSource(goal, variant: .titleOnly)
 // Result: "run a marathon this year"

 let titleEmbedding = try await semanticService.generateEmbedding(for: titleText)
 // 768-dimensional vector for "run a marathon this year"

 // Goal semantic search (full-context)
 let fullText = EmbeddingSourceTextBuilders.buildGoalSource(goal, variant: .fullContext)
 // Result: "run a marathon this year. complete 26.2 miles by december. train 4x/week. targets: 120 km. values: health, discipline"

 let fullEmbedding = try await semanticService.generateEmbedding(for: fullText)
 // 768-dimensional vector with rich semantic context

 // Measure fuzzy matching (title-only)
 let measureText = EmbeddingSourceTextBuilders.buildMeasureSource(measure, variant: .titleOnly)
 // Result: "km distance" (not custom title like "Kilometers")

 // Enables semantic similarity:
 // "km distance" ≈ "kilometers distance" ≈ "killometers distance" (typo)
 */
