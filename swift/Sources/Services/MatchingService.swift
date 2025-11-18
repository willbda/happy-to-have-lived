//
// MatchingService.swift
// Written by Claude Code on 2025-11-03
// Refactored for 3NF normalized schema
//
// PURPOSE: Business logic for matching actions to goals
// PATTERN: Pure functions (no side effects, fully testable without database)
//
// KEY CHANGES FROM v1.0:
// - Works with [MeasuredAction] instead of JSON measuresByUnit
// - Works with [ExpectationMeasure] instead of single measurementUnit
// - Metric overlap calculation instead of string matching
//

import Foundation
import Models

/// Stateless matching functions for action-goal relationships (3NF normalized)
///
/// **Architecture Decision**: Why pure functions?
/// - Testable without database
/// - No side effects (predictable, composable)
/// - Clear inputs/outputs (explicit dependencies)
/// - Reusable across UI and backend
///
/// **Usage**:
/// ```swift
/// // 1. Fetch action with measurements
/// let actionDetails = try await ActionsQuery.fetch(db).first { $0.action.id == actionId }
///
/// // 2. Fetch goal with targets
/// let goalDetails = try await GoalsQuery.fetch(db).first { $0.goal.id == goalId }
///
/// // 3. Check match
/// let match = MatchingService.matches(
///     action: actionDetails.action,
///     actionMeasures: actionDetails.measurements.map { ($0.measure, $0.measuredAction.value) },
///     goal: goalDetails.goal,
///     goalTargets: goalDetails.measureTargets.map { ($0.measure, $0.expectationMeasure.targetValue) }
/// )
///
/// if match.isMatch {
///     print("Action contributes \(match.metricMatch.contribution!) to goal")
/// }
/// ```
public struct MatchingService {

    // MARK: - Period Matching (Unchanged from v1.0)

    /// Check if action occurred during goal's active period
    ///
    /// **No changes needed** - dates still on Action and Goal models
    ///
    /// - Parameters:
    ///   - action: Action with logTime
    ///   - goal: Goal with startDate/targetDate
    /// - Returns: `true` if action is within goal period
    ///
    /// **Examples**:
    /// - Action on Oct 15, Goal Oct 1-31 → true
    /// - Action on Nov 5, Goal Oct 1-31 → false
    /// - Action on Oct 15, Goal with no dates → true (always matches)
    public static func matchesOnPeriod(action: Action, goal: Goal) -> Bool {
        guard let startDate = goal.startDate else { return true }
        guard let targetDate = goal.targetDate else { return true }

        return startDate <= action.logTime && action.logTime <= targetDate
    }

    // MARK: - Metric Matching (NEW - Replaces Unit Matching)

    /// Result of metric overlap calculation
    public struct MetricMatchResult: Sendable {
        /// Whether action and goal share at least one metric
        public let hasOverlap: Bool

        /// Shared metrics between action and goal
        public let sharedMetrics: [Measure]

        /// Total contribution amount (sum of all shared metric values)
        /// Example: Action has [5km, 30min], Goal targets [km, sessions]
        ///          → contribution = 5.0 (only km overlaps)
        public let contribution: Double?

        /// Confidence score (0.0-1.0) based on overlap strength
        public let confidence: Double

        public init(hasOverlap: Bool, sharedMetrics: [Measure], contribution: Double?, confidence: Double) {
            self.hasOverlap = hasOverlap
            self.sharedMetrics = sharedMetrics
            self.contribution = contribution
            self.confidence = confidence
        }
    }

    /// Check if action's measurements overlap with goal's target metrics
    ///
    /// **Replaces**: `matchesOnUnit()` from v1.0
    /// **New Logic**: Compares Measure IDs instead of string matching
    ///
    /// - Parameters:
    ///   - actionMeasures: Action's measurements as [(Measure, value)]
    ///   - goalTargets: Goal's target metrics as [(Measure, targetValue)]
    /// - Returns: MetricMatchResult with overlap details
    ///
    /// **Examples**:
    ///
    /// ```swift
    /// // Case 1: Perfect overlap
    /// let action = [(kmMeasure, 5.0)]
    /// let goal = [(kmMeasure, 120.0)]
    /// // Result: hasOverlap=true, contribution=5.0, confidence=1.0
    ///
    /// // Case 2: Partial overlap (multi-metric goal)
    /// let action = [(kmMeasure, 5.0), (minutesMeasure, 30.0)]
    /// let goal = [(kmMeasure, 120.0), (sessionsMeasure, 20.0)]
    /// // Result: hasOverlap=true, contribution=5.0 (only km matches), confidence=0.5
    ///
    /// // Case 3: No overlap
    /// let action = [(pagesMeasure, 25.0)]
    /// let goal = [(kmMeasure, 120.0)]
    /// // Result: hasOverlap=false, contribution=nil, confidence=0.0
    /// ```
    public static func matchesOnMetrics(
        actionMeasures: [(Measure, Double)],
        goalTargets: [(Measure, Double)]
    ) -> MetricMatchResult {
        // Extract metric IDs for comparison
        let actionMetricIds = Set(actionMeasures.map { $0.0.id })
        let goalMetricIds = Set(goalTargets.map { $0.0.id })

        // Find intersection
        let sharedMetricIds = actionMetricIds.intersection(goalMetricIds)

        guard !sharedMetricIds.isEmpty else {
            return MetricMatchResult(
                hasOverlap: false,
                sharedMetrics: [],
                contribution: nil,
                confidence: 0.0
            )
        }

        // Calculate contribution (sum of shared metric values)
        let contribution = actionMeasures
            .filter { sharedMetricIds.contains($0.0.id) }
            .reduce(0.0) { $0 + $1.1 }

        // Get shared Measure objects
        let sharedMeasures = actionMeasures
            .filter { sharedMetricIds.contains($0.0.id) }
            .map { $0.0 }

        // Calculate confidence (ratio of overlap)
        let overlapRatio = Double(sharedMetricIds.count) / Double(goalMetricIds.count)
        let confidence = min(overlapRatio, 1.0)

        return MetricMatchResult(
            hasOverlap: true,
            sharedMetrics: sharedMeasures,
            contribution: contribution,
            confidence: confidence
        )
    }

    // MARK: - Keyword Matching (NEW - Replaces Actionability)

    /// Check if action title/description contains goal-related keywords
    ///
    /// **Replaces**: `matchesWithActionability()` JSON parsing
    /// **New Logic**: Simple keyword matching (no JSON)
    ///
    /// **Future Enhancement**: Could store keywords in GoalKeyword junction table
    /// if we want structured keyword management.
    ///
    /// - Parameters:
    ///   - action: Action with title/description
    ///   - keywords: Array of keywords to match (e.g., ["run", "jog", "sprint"])
    /// - Returns: `true` if any keyword appears in action text
    ///
    /// **Examples**:
    /// ```swift
    /// let action = Action(title: "Morning run in the park")
    /// let keywords = ["run", "jog", "sprint"]
    /// // Result: true (contains "run")
    ///
    /// let action2 = Action(title: "Yoga class")
    /// let keywords2 = ["run", "jog", "sprint"]
    /// // Result: false
    /// ```
    public static func matchesOnKeywords(
        action: Action,
        keywords: [String]
    ) -> Bool {
        guard !keywords.isEmpty else { return true }

        // Combine title and description for searching
        let searchText = [action.title, action.detailedDescription]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        guard !searchText.isEmpty else { return false }

        // Check if any keyword appears
        return keywords.contains { keyword in
            searchText.contains(keyword.lowercased())
        }
    }

    // MARK: - Combined Matching (Main Entry Point)

    /// Full match result combining all criteria
    public struct MatchResult: Sendable {
        public let periodMatch: Bool
        public let metricMatch: MetricMatchResult
        public let keywordMatch: Bool?  // Optional (not all goals have keywords)

        /// Overall confidence (0.0-1.0)
        public let overallConfidence: Double

        /// Whether this is considered a valid match
        public var isMatch: Bool {
            // Minimum: must match on period AND have metric overlap
            periodMatch && metricMatch.hasOverlap
        }

        public init(periodMatch: Bool, metricMatch: MetricMatchResult, keywordMatch: Bool?, overallConfidence: Double) {
            self.periodMatch = periodMatch
            self.metricMatch = metricMatch
            self.keywordMatch = keywordMatch
            self.overallConfidence = overallConfidence
        }
    }

    /// Check if action matches goal across all criteria
    ///
    /// **Main entry point** for matching logic
    ///
    /// - Parameters:
    ///   - action: Action to check
    ///   - actionMeasures: Action's measurements
    ///   - goal: Goal to match against
    ///   - goalTargets: Goal's target metrics
    ///   - keywords: Optional keywords for refinement
    /// - Returns: Complete match result
    ///
    /// **Usage**:
    /// ```swift
    /// let result = MatchingService.matches(
    ///     action: action,
    ///     actionMeasures: actionDetails.measurements.map { ($0.measure, $0.measuredAction.value) },
    ///     goal: goal,
    ///     goalTargets: goalDetails.measureTargets.map { ($0.measure, $0.expectationMeasure.targetValue) },
    ///     keywords: ["run", "jog"]  // Optional
    /// )
    ///
    /// if result.isMatch {
    ///     // Create ActionGoalContribution record
    ///     let contribution = ActionGoalContribution(
    ///         actionId: action.id,
    ///         goalId: goal.id,
    ///         contributionAmount: result.metricMatch.contribution
    ///     )
    /// }
    /// ```
    public static func matches(
        action: Action,
        actionMeasures: [(Measure, Double)],
        goal: Goal,
        goalTargets: [(Measure, Double)],
        keywords: [String]? = nil
    ) -> MatchResult {
        // Check all criteria
        let periodMatch = matchesOnPeriod(action: action, goal: goal)
        let metricMatch = matchesOnMetrics(
            actionMeasures: actionMeasures,
            goalTargets: goalTargets
        )

        let keywordMatch: Bool? = {
            guard let kw = keywords, !kw.isEmpty else { return nil }
            return matchesOnKeywords(action: action, keywords: kw)
        }()

        // Calculate overall confidence
        var confidence = 0.0

        if periodMatch && metricMatch.hasOverlap {
            // Base confidence from metric overlap
            confidence = metricMatch.confidence * 0.6

            // Boost if keywords also match
            if let keywordMatch = keywordMatch, keywordMatch {
                confidence += 0.3
            }

            // Ensure max 1.0
            confidence = min(confidence, 1.0)
        }

        return MatchResult(
            periodMatch: periodMatch,
            metricMatch: metricMatch,
            keywordMatch: keywordMatch,
            overallConfidence: confidence
        )
    }
}
