# Progress Tracking & Active Period Management - Implementation Proposal

**Written by Claude Code on 2025-11-19**
**Updated on 2025-11-19**: Expanded to cover all Expectation types (Goal, Milestone, Obligation)

## Executive Summary

This proposal outlines an implementation for comprehensive progress tracking and active period management for **all Expectation types** (Goals, Milestones, Obligations) in Happy to Have Lived. The design focuses on **logic-first implementation** with reusable services that can power both data aggregation and future UI enhancements.

### Expectation Types Coverage
- **Goals**: Full progress tracking (time + action metrics, velocity, trend analysis)
- **Milestones**: Status tracking (upcoming, overdue, completed)
- **Obligations**: Deadline tracking (on-time, approaching, overdue)

## Problem Statement

### Current Gaps

1. **Progress Calculation**: `ProgressIndicator` component exists but has no actual progress data
   - Receives `actualProgress: [UUID: Double]` but no service calculates this
   - No aggregation of `MeasuredAction` → Goal progress
   - **Goals only**: Milestones and Obligations need status tracking

2. **Active Detection**: Current `GoalData.isActive` is too simplistic
   ```swift
   // Current implementation (GoalData.swift:203)
   public var isActive: Bool {
       guard let target = targetDate else { return true }
       return target > Date()
   }
   ```
   - **Goals**: Doesn't consider term status (a goal in a "cancelled" term shouldn't show as active)
   - **Milestones**: No distinction between upcoming/overdue/completed
   - **Obligations**: No "approaching deadline" detection

3. **No Time Progress Tracking**: All expectation types have temporal bounds
   - **Goals**: Start date → target date = time progress %
   - **Milestones**: Created → target date = proximity to checkpoint
   - **Obligations**: Created → deadline = urgency indicator

4. **No Period-Level Aggregation**: No way to answer:
   - "What's my progress across all active expectations?"
   - "How many obligations are overdue?"
   - "Which milestones are coming up this week?"
   - "How much progress did I make in Term 5?"

### User Requirements

✅ Show progress in accessible and encouraging way
✅ Progress measured by: **time elapsed** + **actions that advance goals** (Goals only)
✅ Status tracking for **all expectation types** (Goals, Milestones, Obligations)
✅ Abstract logic for **TimePeriods as a whole** (not just individual expectations)
✅ Improve active detection logic for **all expectation types**
✅ Deadline/checkpoint tracking for Milestones and Obligations
✅ Enable active period filtering for initial view
✅ **Focus on logic first, UI later**

## Proposed Architecture

### Core Services (3 new services)

```
┌─────────────────────────────────────────────────────────────────┐
│                  PROGRESS TRACKING LAYER                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ProgressCalculationService (Individual Progress)               │
│  ├─ calculateGoalProgress(goal, actions) → GoalProgress         │
│  ├─ calculateMilestoneStatus(milestone) → MilestoneStatus       │
│  ├─ calculateObligationStatus(obligation) → ObligationStatus    │
│  ├─ calculateTimeProgress(start, target, now) → Double          │
│  └─ calculateActionProgress(targets, actuals) → Double          │
│                                                                  │
│  ProgressAggregationService (Rollups & Summaries)               │
│  ├─ aggregateByGoal(goalId) → GoalProgressData                  │
│  ├─ aggregateByTerm(termId) → TermProgressData                  │
│  ├─ aggregateByPeriod(periodId) → PeriodProgressData            │
│  ├─ aggregateAllExpectations() → ExpectationSummary             │
│  └─ aggregatePortfolio(filter) → PortfolioProgressData          │
│                                                                  │
│  ActiveStatusService (Filtering & Detection)                    │
│  ├─ getActiveGoals() → [GoalData]                               │
│  ├─ getActiveMilestones() → [MilestoneWithDetails]              │
│  ├─ getActiveObligations() → [ObligationWithDetails]            │
│  ├─ getActiveTerms() → [TimePeriodData]                         │
│  ├─ isGoalActive(goal) → Bool (enhanced logic)                  │
│  ├─ getMilestoneStatus(milestone) → MilestoneStatus             │
│  └─ getObligationStatus(obligation) → ObligationStatus          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1. ProgressCalculationService

**Purpose**: Calculate individual progress metrics

**Responsibilities**:
- Time progress: `(now - start) / (target - start)`
- Action progress: `sum(actuals) / sum(targets)` per measure
- Combined progress: weighted average
- Velocity calculation: progress per day
- Trend detection: increasing/stable/decreasing/stalled

**Example Usage**:
```swift
let service = ProgressCalculationService(database: database)

// Calculate progress for a single goal
let progress = try await service.calculateGoalProgress(
    goal: goalData,
    actions: actionsForGoal
)

// Result:
// GoalProgress(
//     goalId: UUID,
//     timeProgress: 0.65,           // 65% of time elapsed
//     actionProgress: 0.58,         // 58% of targets achieved
//     combinedProgress: 0.615,      // Weighted average
//     velocity: 0.019,              // 1.9% progress per day
//     trend: .increasing,
//     measureProgress: [
//         MeasureProgress(
//             measureId: UUID,
//             target: 120.0,
//             actual: 87.0,
//             progress: 0.725,
//             unit: "km"
//         )
//     ],
//     lastActionDate: Date(),
//     estimatedCompletion: Date()   // Based on velocity
// )
```

**Key Methods**:

```swift
public struct ProgressCalculationService: Sendable {
    private let database: any DatabaseWriter

    /// Calculate time-based progress
    public func calculateTimeProgress(
        startDate: Date?,
        targetDate: Date?,
        currentDate: Date = Date()
    ) -> TimeProgress

    /// Calculate action-based progress for a goal
    public func calculateActionProgress(
        measureTargets: [GoalData.MeasureTarget],
        actions: [ActionData]
    ) -> ActionProgress

    /// Calculate combined progress (time + action)
    public func calculateGoalProgress(
        goal: GoalData,
        actions: [ActionData]
    ) async throws -> GoalProgress

    /// Calculate velocity and trend
    public func calculateVelocity(
        actions: [ActionData],
        timePeriodDays: Int = 30
    ) -> VelocityAnalysis

    /// Calculate milestone status (Milestones are point-in-time checkpoints)
    public func calculateMilestoneStatus(
        milestone: MilestoneWithDetails,
        currentDate: Date = Date()
    ) -> MilestoneStatus

    /// Calculate obligation status (Obligations are deadline-based commitments)
    public func calculateObligationStatus(
        obligation: ObligationWithDetails,
        currentDate: Date = Date()
    ) -> ObligationStatus
}
```

**Milestone Status Tracking**:

Milestones are point-in-time checkpoints, so they don't have progress percentages. Instead, they have statuses:

```swift
public enum MilestoneStatus: String, Codable, Sendable {
    case upcoming      // targetDate > now
    case due           // targetDate within 7 days
    case overdue       // targetDate < now
    case completed     // Manually marked complete
}

// Example usage:
let status = service.calculateMilestoneStatus(
    milestone: milestoneData,
    currentDate: Date()
)
// Returns: .upcoming, .due, or .overdue based on targetDate
```

**Obligation Status Tracking**:

Obligations track external commitments with deadlines:

```swift
public enum ObligationStatus: String, Codable, Sendable {
    case pending       // deadline > 7 days away
    case approaching   // deadline within 7 days
    case overdue       // deadline < now
    case completed     // Manually marked complete
}

// Example usage:
let status = service.calculateObligationStatus(
    obligation: obligationData,
    currentDate: Date()
)
// Returns: .pending, .approaching, or .overdue based on deadline
```

### 2. ProgressAggregationService

**Purpose**: Aggregate progress data at different levels

**Responsibilities**:
- Goal-level: individual goal progress
- Term-level: all goals in a term (average, min, max, variance)
- Period-level: abstract aggregation for any time period
- Portfolio-level: all active goals across all terms

**Example Usage**:
```swift
let service = ProgressAggregationService(database: database)

// Aggregate progress for a term
let termProgress = try await service.aggregateByTerm(termId: termId)

// Result:
// TermProgressData(
//     termId: UUID,
//     termNumber: 5,
//     status: .active,
//     startDate: Date("2025-03-01"),
//     endDate: Date("2025-05-10"),
//
//     // Time metrics
//     timeProgress: 0.65,           // 65% of term elapsed
//     daysElapsed: 46,
//     daysRemaining: 24,
//
//     // Goal metrics
//     totalGoals: 4,
//     activeGoals: 3,
//     completedGoals: 0,
//     stalledGoals: 1,
//
//     // Aggregated progress
//     averageProgress: 0.58,        // Average across all goals
//     minProgress: 0.23,            // Lowest performing goal
//     maxProgress: 0.89,            // Highest performing goal
//
//     // Progress distribution
//     goalsOnTrack: 2,              // progress >= timeProgress
//     goalsBehind: 1,               // progress < timeProgress
//     goalsStalledCount: 1,         // no actions in 14 days
//
//     // Individual goal progress
//     goalProgress: [
//         GoalProgressSummary(goalId: UUID, progress: 0.89, status: .onTrack),
//         GoalProgressSummary(goalId: UUID, progress: 0.58, status: .onTrack),
//         GoalProgressSummary(goalId: UUID, progress: 0.42, status: .behind),
//         GoalProgressSummary(goalId: UUID, progress: 0.23, status: .stalled)
//     ]
// )
```

**Key Methods**:

```swift
public struct ProgressAggregationService: Sendable {
    private let database: any DatabaseWriter
    private let calculationService: ProgressCalculationService

    /// Aggregate progress for a single goal
    public func aggregateByGoal(
        goalId: UUID
    ) async throws -> GoalProgressData

    /// Aggregate progress for all goals in a term
    public func aggregateByTerm(
        termId: UUID
    ) async throws -> TermProgressData

    /// Aggregate progress for any time period (abstract)
    public func aggregateByPeriod(
        startDate: Date,
        endDate: Date,
        goalFilter: GoalFilter? = nil
    ) async throws -> PeriodProgressData

    /// Aggregate portfolio-wide progress
    public func aggregatePortfolio(
        filter: ProgressFilter = .activeOnly
    ) async throws -> PortfolioProgressData
}
```

### 3. ActiveStatusService

**Purpose**: Enhanced active/inactive detection and filtering for all expectation types

**Responsibilities**:
- Determine if a goal is truly "active" (considering term status, completion, dates)
- Determine if a milestone is "upcoming" vs "overdue" vs "completed"
- Determine if an obligation is "pending" vs "approaching" vs "overdue"
- Determine if a term is active (based on status, dates, activity)
- Filter all expectation types by active status
- Provide "focus set" for dashboard (prioritized active expectations)

**Example Usage**:
```swift
let service = ActiveStatusService(database: database)

// Get all truly active goals
let activeGoals = try await service.getActiveGoals()

// Get upcoming/due milestones
let activeMilestones = try await service.getActiveMilestones()  // Not overdue

// Get pending/approaching obligations
let activeObligations = try await service.getActiveObligations()  // Not overdue

// Enhanced active detection
let isActive = service.isGoalActive(
    goal: goalData,
    termStatus: .active,
    currentDate: Date()
)

// Get milestone status
let milestoneStatus = service.getMilestoneStatus(milestone: milestoneData)  // .upcoming, .due, .overdue

// Get obligation status
let obligationStatus = service.getObligationStatus(obligation: obligationData)  // .pending, .approaching, .overdue

// Get active terms for dashboard
let activeTerms = try await service.getActiveTerms()
```

**Enhanced Active Detection Logic**:

```swift
public struct ActiveStatusService: Sendable {
    private let database: any DatabaseWriter

    /// Enhanced active detection for goals
    public func isGoalActive(
        goal: GoalData,
        termStatus: TermStatus?,
        currentDate: Date = Date()
    ) -> Bool {
        // Rule 1: If assigned to a term, respect term status
        if let status = termStatus {
            guard status == .active || status == .planned else {
                return false  // Terms that are cancelled/delayed/on_hold = inactive goals
            }
        }

        // Rule 2: Check if goal period is current
        if let targetDate = goal.targetDate, targetDate < currentDate {
            return false  // Past target date = inactive
        }

        if let startDate = goal.startDate, startDate > currentDate {
            return false  // Future start date = not yet active
        }

        // Rule 3: No target date = open-ended goal (active)
        return true
    }

    /// Get all active goals
    public func getActiveGoals() async throws -> [GoalData]

    /// Get all active milestones (upcoming or due, not overdue)
    public func getActiveMilestones() async throws -> [MilestoneWithDetails]

    /// Get all active obligations (pending or approaching, not overdue)
    public func getActiveObligations() async throws -> [ObligationWithDetails]

    /// Get milestone status
    public func getMilestoneStatus(
        milestone: MilestoneWithDetails,
        currentDate: Date = Date()
    ) -> MilestoneStatus

    /// Get obligation status
    public func getObligationStatus(
        obligation: ObligationWithDetails,
        currentDate: Date = Date()
    ) -> ObligationStatus

    /// Get all active terms
    public func getActiveTerms() async throws -> [TimePeriodData]

    /// Get focus set for dashboard (top 3-5 active goals)
    public func getFocusSet(
        priorityMode: PriorityMode = .importanceUrgency
    ) async throws -> [GoalData]

    /// Get all active expectations (Goals, Milestones, Obligations combined)
    public func getAllActiveExpectations() async throws -> ExpectationSummary
}
```

## Data Types (Canonical Progress Types)

### GoalProgress

```swift
/// Complete progress data for a single goal
public struct GoalProgress: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // goalId

    // Time-based progress
    public let timeProgress: Double        // 0.0 to 1.0 (% of time elapsed)
    public let daysElapsed: Int?
    public let daysRemaining: Int?

    // Action-based progress
    public let actionProgress: Double      // 0.0 to 1.0 (% of targets achieved)
    public let measureProgress: [MeasureProgress]

    // Combined metrics
    public let combinedProgress: Double    // Weighted: 30% time + 70% action
    public let progressStatus: ProgressStatus  // .onTrack, .behind, .ahead, .stalled

    // Velocity & trend
    public let velocity: Double?           // Progress per day
    public let trend: ProgressTrend        // .increasing, .stable, .decreasing, .stalled
    public let lastActionDate: Date?
    public let estimatedCompletion: Date?  // Based on velocity

    // Metadata
    public let calculatedAt: Date
}

/// Progress for a single measure
public struct MeasureProgress: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // measureId
    public let measureTitle: String?
    public let measureUnit: String
    public let targetValue: Double
    public let actualValue: Double
    public let progress: Double            // 0.0 to 1.0
}

public enum ProgressStatus: String, Codable, Sendable {
    case onTrack   // progress >= timeProgress
    case behind    // progress < timeProgress
    case ahead     // progress > timeProgress + 0.1
    case stalled   // no actions in 14+ days
    case completed // progress >= 1.0
}

public enum ProgressTrend: String, Codable, Sendable {
    case increasing  // Velocity increasing over time
    case stable      // Steady progress
    case decreasing  // Slowing down
    case stalled     // No recent progress
}
```

### TermProgressData

```swift
/// Aggregated progress for all goals in a term
public struct TermProgressData: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // termId
    public let termNumber: Int
    public let status: String  // TermStatus.rawValue

    // Time boundaries
    public let startDate: Date
    public let endDate: Date
    public let timeProgress: Double        // 0.0 to 1.0
    public let daysElapsed: Int
    public let daysRemaining: Int

    // Goal counts
    public let totalGoals: Int
    public let activeGoals: Int
    public let completedGoals: Int
    public let stalledGoals: Int

    // Aggregated progress
    public let averageProgress: Double     // Mean of all goal progress
    public let medianProgress: Double      // Median (more robust to outliers)
    public let minProgress: Double
    public let maxProgress: Double

    // Distribution
    public let goalsOnTrack: Int           // progress >= timeProgress
    public let goalsBehind: Int            // progress < timeProgress
    public let goalsAhead: Int             // progress > timeProgress + 0.1

    // Individual goal summaries
    public let goalProgress: [GoalProgressSummary]

    // Metadata
    public let calculatedAt: Date
}

/// Compact summary of goal progress (for lists)
public struct GoalProgressSummary: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // goalId
    public let title: String?
    public let combinedProgress: Double
    public let progressStatus: ProgressStatus
    public let trend: ProgressTrend
}
```

### PeriodProgressData (Abstract)

```swift
/// Abstract progress data for ANY time period (not just terms)
///
/// Use cases:
/// - Custom date ranges ("Show progress for Q1 2025")
/// - Rolling windows ("Show progress for last 30 days")
/// - Fiscal years, sprints, arbitrary periods
public struct PeriodProgressData: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // Generated ID for the period
    public let periodType: PeriodType
    public let startDate: Date
    public let endDate: Date

    // Same structure as TermProgressData
    public let timeProgress: Double
    public let daysElapsed: Int
    public let daysRemaining: Int
    public let totalGoals: Int
    public let activeGoals: Int
    public let averageProgress: Double
    public let goalProgress: [GoalProgressSummary]
    public let calculatedAt: Date
}

public enum PeriodType: String, Codable, Sendable {
    case term          // GoalTerm (structured planning)
    case custom        // User-defined range
    case rolling       // Last N days
    case quarter       // Calendar quarter
    case year          // Calendar year
}
```

### PortfolioProgressData

```swift
/// Portfolio-wide progress summary
public struct PortfolioProgressData: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // Portfolio ID (could be userId in future)

    // Overall metrics
    public let totalGoals: Int
    public let activeGoals: Int
    public let completedGoals: Int
    public let stalledGoals: Int

    // Progress distribution
    public let averageProgress: Double
    public let goalsOnTrack: Int
    public let goalsBehind: Int
    public let goalsAhead: Int

    // Velocity & momentum
    public let portfolioVelocity: Double   // Average velocity across active goals
    public let momentumScore: Double       // 0.0 to 1.0 (based on trend + velocity)

    // By term breakdown
    public let termProgress: [TermProgressSummary]

    // Top insights
    public let focusGoals: [GoalProgressSummary]  // Top 3-5 priorities
    public let strugglingGoals: [GoalProgressSummary]  // Needs attention

    public let calculatedAt: Date
}

public struct TermProgressSummary: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID  // termId
    public let termNumber: Int
    public let status: String
    public let averageProgress: Double
    public let goalsCount: Int
}
```

## Repository Enhancements

### Add to GoalRepository

```swift
extension GoalRepository {
    /// Fetch active goals with enhanced filtering
    public func fetchActiveGoals(
        includeTermStatus: Bool = true
    ) async throws -> [GoalData] {
        // Existing query + JOIN with termGoalAssignments + goalTerms
        // Filter: WHERE (targetDate IS NULL OR targetDate >= date('now'))
        //         AND (termStatus IS NULL OR termStatus IN ('active', 'planned'))
    }

    /// Fetch goals for dashboard focus set
    public func fetchFocusGoals(
        limit: Int = 5
    ) async throws -> [GoalData] {
        // Active goals sorted by: importance + urgency + recentActivity
    }
}
```

### Add to ActionRepository

```swift
extension ActionRepository {
    /// Fetch actions contributing to a goal (for progress calculation)
    public func fetchByGoal(
        goalId: UUID,
        since: Date? = nil
    ) async throws -> [ActionData] {
        // Already exists internally, expose as public
    }

    /// Aggregate measured values by goal and measure
    public func aggregateMeasurements(
        goalId: UUID
    ) async throws -> [UUID: Double] {
        // Returns: [measureId: sumOfValues]
        // SQL: SELECT measureId, SUM(ma.value)
        //      FROM measuredActions ma
        //      JOIN actionGoalContributions agc ON ma.actionId = agc.actionId
        //      WHERE agc.goalId = ?
        //      GROUP BY measureId
    }
}
```

### Add to TimePeriodRepository

```swift
extension TimePeriodRepository {
    /// Fetch active terms
    public func fetchActiveTerms() async throws -> [TimePeriodData] {
        // WHERE status IN ('active', 'planned')
        // AND endDate >= date('now')
    }

    /// Fetch current term (contains today)
    public func fetchCurrentTerm() async throws -> TimePeriodData? {
        // WHERE startDate <= date('now') AND endDate >= date('now')
        // AND status = 'active'
        // LIMIT 1
    }
}
```

### Add to MilestoneRepository

```swift
extension MilestoneRepository {
    /// Fetch milestones by status (upcoming, due, overdue)
    public func fetchByStatus(
        status: MilestoneStatus
    ) async throws -> [MilestoneWithDetails] {
        // Filter based on targetDate relative to current date
        // upcoming: targetDate > now + 7 days
        // due: targetDate between now and now + 7 days
        // overdue: targetDate < now
    }

    /// Fetch milestones in date range
    public func fetchInRange(
        startDate: Date,
        endDate: Date
    ) async throws -> [MilestoneWithDetails] {
        // WHERE targetDate BETWEEN ? AND ?
        // ORDER BY targetDate ASC
    }

    /// Fetch upcoming milestones (next 30 days)
    public func fetchUpcoming(
        days: Int = 30
    ) async throws -> [MilestoneWithDetails] {
        // WHERE targetDate BETWEEN date('now') AND date('now', '+N days')
        // ORDER BY targetDate ASC
    }
}
```

### Add to ObligationRepository

```swift
extension ObligationRepository {
    /// Fetch obligations by status (pending, approaching, overdue)
    public func fetchByStatus(
        status: ObligationStatus
    ) async throws -> [ObligationWithDetails] {
        // Filter based on deadline relative to current date
        // pending: deadline > now + 7 days
        // approaching: deadline between now and now + 7 days
        // overdue: deadline < now
    }

    /// Fetch obligations in date range
    public func fetchInRange(
        startDate: Date,
        endDate: Date
    ) async throws -> [ObligationWithDetails] {
        // WHERE deadline BETWEEN ? AND ?
        // ORDER BY deadline ASC
    }

    /// Fetch obligations by urgency level
    public func fetchByUrgency(
        minimumUrgency: Int
    ) async throws -> [ObligationWithDetails] {
        // JOIN with expectations to filter by expectationUrgency
        // WHERE e.expectationUrgency >= ?
        // ORDER BY e.expectationUrgency DESC, deadline ASC
    }
}
```

## Status Management Strategy

### Recommendation: Keep Current Architecture

**DO NOT add status to TimePeriod** because:
1. TimePeriod is intentionally a **pure chronological container**
2. Planning semantics belong to GoalTerm (already has `TermStatus`)
3. Adding status to TimePeriod would blur abstraction/basic layer separation

**Instead, use existing GoalTerm.status**:

```swift
// Term.swift already has this:
public enum TermStatus: String, Codable {
    case planned
    case active
    case completed
    case delayed
    case onHold = "on_hold"
    case cancelled
}
```

**Active Term Detection**:
```swift
// Use status field + date validation
let activeTerm = term.status == .active
    && term.startDate <= Date()
    && term.endDate >= Date()
```

## Implementation Phases

### Phase 1: Foundation Services (Week 1)

**Goal**: Core calculation logic without UI for all Expectation types

Files to create:
- `Sources/Services/Progress/ProgressCalculationService.swift`
- `Sources/Services/Progress/ProgressAggregationService.swift`
- `Sources/Services/Progress/ActiveStatusService.swift`
- `Sources/Models/DataTypes/ProgressData.swift` (all progress data types)

**Deliverables**:
- ✅ Calculate individual goal progress (time + action)
- ✅ Calculate milestone status (upcoming, due, overdue)
- ✅ Calculate obligation status (pending, approaching, overdue)
- ✅ Aggregate progress by goal, term, period
- ✅ Enhanced active detection logic for all expectation types
- ✅ Unit tests for calculation accuracy

### Phase 2: Repository Integration (Week 1-2)

**Goal**: Expose progress data through repositories for all Expectation types

Files to modify:
- `Sources/Services/Repositories/GoalRepository.swift` (add fetchActiveGoals, fetchFocusGoals)
- `Sources/Services/Repositories/MilestoneRepository.swift` (add fetchByStatus, fetchUpcoming)
- `Sources/Services/Repositories/ObligationRepository.swift` (add fetchByStatus, fetchByUrgency)
- `Sources/Services/Repositories/ActionRepository.swift` (add aggregateMeasurements)
- `Sources/Services/Repositories/TimePeriodRepository.swift` (add fetchActiveTerms)

**Deliverables**:
- ✅ Efficient SQL queries for progress data (Goals, Milestones, Obligations)
- ✅ Status-based filtering for Milestones and Obligations
- ✅ Avoid N+1 queries (bulk fetch patterns)
- ✅ Pagination support for large datasets

### Phase 3: ViewModel Integration (Week 2)

**Goal**: Wire services to existing ViewModels for all Expectation types

Files to modify:
- `Sources/App/ViewModels/ListViewModels/GoalsListViewModel.swift` (add progress loading)
- `Sources/App/ViewModels/ListViewModels/MilestonesListViewModel.swift` (add status filtering)
- `Sources/App/ViewModels/ListViewModels/ObligationsListViewModel.swift` (add deadline tracking)
- `Sources/App/ViewModels/DashboardViewModel.swift` (create new ViewModel for dashboard)

**Deliverables**:
- ✅ GoalsListViewModel loads progress data
- ✅ MilestonesListViewModel filters by status (upcoming, due, overdue)
- ✅ ObligationsListViewModel highlights approaching deadlines
- ✅ DashboardViewModel aggregates portfolio progress across all types
- ✅ Loading states and error handling

### Phase 4: UI Enhancement (Week 3 - After Foundation)

**Goal**: Update UI to display progress and status data for all Expectation types

Files to modify:
- `Sources/App/Views/Components/GoalComponents/ProgressIndicator.swift` (use real data)
- `Sources/App/Views/RowViews/MilestoneRowView.swift` (add status badges)
- `Sources/App/Views/RowViews/ObligationRowView.swift` (add deadline indicators)
- `Sources/App/Views/Dashboard/DashboardView.swift` (add progress cards)
- `Sources/App/Views/ListViews/GoalsListView.swift` (show progress in rows)
- `Sources/App/Views/ListViews/MilestonesListView.swift` (group by status)
- `Sources/App/Views/ListViews/ObligationsListView.swift` (sort by deadline)

**Deliverables**:
- ✅ ProgressIndicator receives calculated progress (Goals)
- ✅ Status badges for Milestones (upcoming/due/overdue with color coding)
- ✅ Deadline indicators for Obligations (approaching deadlines highlighted)
- ✅ Dashboard shows portfolio-wide metrics across all types
- ✅ Goal list shows individual progress
- ✅ Milestone list grouped by status with counts
- ✅ Obligation list sorted by deadline urgency

### Phase 5: LLM Integration (Week 3)

**Goal**: Implement GetProgressTool for Foundation Models

Files to modify:
- `Sources/Services/FoundationModels/Tools/GetProgressToolPlaceholder.swift` → `GetProgressTool.swift`

**Deliverables**:
- ✅ LLM can query progress data
- ✅ Structured responses for reflection conversations
- ✅ Integration with GoalCoachService

## Example Queries (SQL Performance)

### Efficient Progress Calculation Query

```sql
-- Aggregate measurements for a goal (single query)
SELECT
    em.measureId,
    m.title as measureTitle,
    m.unit as measureUnit,
    em.targetValue,
    COALESCE(SUM(ma.value), 0) as actualValue
FROM expectationMeasures em
JOIN measures m ON em.measureId = m.id
JOIN expectations e ON em.expectationId = e.id
JOIN goals g ON g.expectationId = e.id
LEFT JOIN (
    -- Get measurements from actions contributing to this goal
    SELECT ma.measureId, ma.value
    FROM measuredActions ma
    JOIN actionGoalContributions agc ON ma.actionId = agc.actionId
    WHERE agc.goalId = ?
) ma ON em.measureId = ma.measureId
WHERE g.id = ?
GROUP BY em.measureId, m.title, m.unit, em.targetValue;
```

**Performance**: O(1) query, single JOIN, returns all measure progress for a goal

### Term Progress Aggregation Query

```sql
-- Get progress for all goals in a term
SELECT
    g.id as goalId,
    e.title as goalTitle,
    g.targetDate,
    COUNT(DISTINCT agc.actionId) as actionCount,
    MAX(a.logTime) as lastActionDate
FROM goals g
JOIN expectations e ON g.expectationId = e.id
JOIN termGoalAssignments tga ON g.id = tga.goalId
LEFT JOIN actionGoalContributions agc ON g.id = agc.goalId
LEFT JOIN actions a ON agc.actionId = a.id
WHERE tga.termId = ?
GROUP BY g.id, e.title, g.targetDate;
```

**Performance**: O(1) query, returns all goals in term with action counts

### Milestone Status Query

```sql
-- Get all milestones with their status (upcoming, due, overdue)
SELECT
    m.id as milestoneId,
    e.title as milestoneTitle,
    m.targetDate,
    e.expectationImportance,
    e.expectationUrgency,
    CASE
        WHEN m.targetDate > date('now', '+7 days') THEN 'upcoming'
        WHEN m.targetDate >= date('now') AND m.targetDate <= date('now', '+7 days') THEN 'due'
        WHEN m.targetDate < date('now') THEN 'overdue'
    END as status
FROM milestones m
JOIN expectations e ON m.expectationId = e.id
WHERE e.expectationType = 'milestone'
ORDER BY m.targetDate ASC;
```

**Performance**: O(1) query, single JOIN, calculates status dynamically

### Obligation Deadline Query

```sql
-- Get all obligations with urgency indicators
SELECT
    o.id as obligationId,
    e.title as obligationTitle,
    o.deadline,
    o.requestedBy,
    o.consequence,
    e.expectationImportance,
    e.expectationUrgency,
    CASE
        WHEN o.deadline > date('now', '+7 days') THEN 'pending'
        WHEN o.deadline >= date('now') AND o.deadline <= date('now', '+7 days') THEN 'approaching'
        WHEN o.deadline < date('now') THEN 'overdue'
    END as status,
    CAST((julianday(o.deadline) - julianday('now')) AS INTEGER) as daysUntilDeadline
FROM obligations o
JOIN expectations e ON o.expectationId = e.id
WHERE e.expectationType = 'obligation'
ORDER BY o.deadline ASC;
```

**Performance**: O(1) query, single JOIN, calculates deadline proximity

### Combined Expectation Summary Query

```sql
-- Get summary of all active expectations across types
SELECT
    'goal' as expectationType,
    COUNT(*) as count,
    AVG(e.expectationImportance) as avgImportance,
    AVG(e.expectationUrgency) as avgUrgency
FROM goals g
JOIN expectations e ON g.expectationId = e.id
WHERE g.targetDate IS NULL OR g.targetDate >= date('now')

UNION ALL

SELECT
    'milestone' as expectationType,
    COUNT(*) as count,
    AVG(e.expectationImportance) as avgImportance,
    AVG(e.expectationUrgency) as avgUrgency
FROM milestones m
JOIN expectations e ON m.expectationId = e.id
WHERE m.targetDate >= date('now')

UNION ALL

SELECT
    'obligation' as expectationType,
    COUNT(*) as count,
    AVG(e.expectationImportance) as avgImportance,
    AVG(e.expectationUrgency) as avgUrgency
FROM obligations o
JOIN expectations e ON o.expectationId = e.id
WHERE o.deadline >= date('now');
```

**Performance**: O(1) query with three simple scans, returns portfolio-wide summary

## Testing Strategy

### Unit Tests

```swift
// ProgressCalculationServiceTests.swift
func testTimeProgress_midway() {
    let start = Date("2025-03-01")
    let target = Date("2025-05-10")  // 70 days
    let now = Date("2025-04-05")     // 35 days elapsed

    let progress = service.calculateTimeProgress(
        startDate: start,
        targetDate: target,
        currentDate: now
    )

    XCTAssertEqual(progress.progress, 0.5, accuracy: 0.01)
    XCTAssertEqual(progress.daysElapsed, 35)
    XCTAssertEqual(progress.daysRemaining, 35)
}

func testActionProgress_partial() {
    let targets = [
        GoalData.MeasureTarget(measureId: uuid1, targetValue: 120, ...)
    ]
    let actions = [
        ActionData(measurements: [
            ActionData.Measurement(measureId: uuid1, value: 30, ...)
        ])
    ]

    let progress = service.calculateActionProgress(
        measureTargets: targets,
        actions: actions
    )

    XCTAssertEqual(progress.measureProgress[0].progress, 0.25, accuracy: 0.01)
}

func testMilestoneStatus_upcoming() {
    let milestone = MilestoneWithDetails(
        milestone: Milestone(targetDate: Date.now + 30.days),
        expectation: Expectation(title: "Launch beta", expectationType: .milestone)
    )

    let status = service.calculateMilestoneStatus(
        milestone: milestone,
        currentDate: Date.now
    )

    XCTAssertEqual(status, .upcoming)
}

func testMilestoneStatus_due() {
    let milestone = MilestoneWithDetails(
        milestone: Milestone(targetDate: Date.now + 3.days),
        expectation: Expectation(title: "Launch beta", expectationType: .milestone)
    )

    let status = service.calculateMilestoneStatus(
        milestone: milestone,
        currentDate: Date.now
    )

    XCTAssertEqual(status, .due)
}

func testObligationStatus_approaching() {
    let obligation = ObligationWithDetails(
        obligation: Obligation(deadline: Date.now + 5.days),
        expectation: Expectation(title: "Submit report", expectationType: .obligation)
    )

    let status = service.calculateObligationStatus(
        obligation: obligation,
        currentDate: Date.now
    )

    XCTAssertEqual(status, .approaching)
}

func testObligationStatus_overdue() {
    let obligation = ObligationWithDetails(
        obligation: Obligation(deadline: Date.now - 2.days),
        expectation: Expectation(title: "Submit report", expectationType: .obligation)
    )

    let status = service.calculateObligationStatus(
        obligation: obligation,
        currentDate: Date.now
    )

    XCTAssertEqual(status, .overdue)
}
```

### Integration Tests

```swift
// ProgressAggregationServiceTests.swift
func testAggregateByTerm_withRealData() async throws {
    // Setup: Create term with 4 goals, various completion levels
    let term = try await createTestTerm()
    let goals = try await createTestGoals(termId: term.id, count: 4)
    try await createTestActions(goals: goals, progressLevels: [0.9, 0.7, 0.4, 0.1])

    // Execute
    let termProgress = try await service.aggregateByTerm(termId: term.id)

    // Assert
    XCTAssertEqual(termProgress.totalGoals, 4)
    XCTAssertEqual(termProgress.averageProgress, 0.525, accuracy: 0.01)
    XCTAssertEqual(termProgress.goalsOnTrack, 2)  // 0.9 and 0.7 are on track
    XCTAssertEqual(termProgress.goalsBehind, 2)   // 0.4 and 0.1 are behind
}
```

## Migration Path (No Breaking Changes)

This implementation is **additive only**:

✅ No schema changes required
✅ No existing code modification needed
✅ New services exist alongside current code
✅ Can be adopted incrementally in ViewModels
✅ UI can continue using placeholder data during development

## Benefits Summary

### For Users
- 📊 **Visibility**: Clear progress metrics at goal, term, and portfolio levels
- 🎯 **Focus**: Dashboard shows active goals only (no clutter from completed/cancelled)
- 💪 **Motivation**: See velocity and trend (momentum building)
- 🔍 **Insights**: Identify stalled goals needing attention

### For Codebase
- 🧩 **Modular**: Services are composable and reusable
- 🔄 **Testable**: Pure calculation functions (easy to unit test)
- 📈 **Scalable**: SQL aggregations efficient at any scale
- 🎨 **UI-Agnostic**: Logic separate from presentation (can support multiple UI patterns)

### For Future Features
- 🤖 **LLM Integration**: GetProgressTool can use these services
- 📱 **Widgets**: Portfolio progress card for home screen
- 📧 **Notifications**: "You're 80% to your goal!" reminders
- 📊 **Analytics**: Historical progress tracking (add TimeSeries later)

## Next Steps

1. **Review & Approve**: Confirm this architecture aligns with vision
2. **Prioritize**: Which phase should we start with?
3. **Begin Implementation**: Create first service (ProgressCalculationService)

## Questions for Discussion

1. **Weighting**: Should combined progress favor actions over time? (Currently: 70% action, 30% time)
2. **Stalled Definition**: How many days without action = "stalled"? (Currently: 14 days)
3. **Dashboard Priority**: What should "focus set" prioritize? (importance+urgency? recent activity? behind schedule?)
4. **Historical Data**: Should we store progress snapshots over time? (Not in this proposal, but Phase 6 possibility)

---

**Document Status**: Draft for Review
**Target Start Date**: Upon approval
**Estimated Completion**: 3 weeks (logic + UI)
