# Happy to Have Lived - Codebase Architecture Analysis

## Executive Summary

This is a Swift-based goal tracking and personal development app using a sophisticated three-layer domain model with SQLiteData ORM. The data architecture emphasizes normalization (3NF) with clean separation between abstraction, basic, and composit layers. A modern repository pattern ensures repositories handle reads while coordinators handle writes.

---

## Part 1: Data Models and Relationships

### Three-Layer Architecture

```
ABSTRACTION LAYER (Base entities with full metadata)
├── Action (what was done)
├── Expectation (base for goals/milestones/obligations)
├── Measure (unit of measurement catalog)
├── PersonalValue (life values and areas)
└── TimePeriod (pure chronological boundaries)

BASIC LAYER (User-friendly working entities)
├── Goal (expectation subtype with dates & action plan)
├── Milestone (expectation subtype with checkpoint date)
├── Obligation (expectation subtype with external deadline)
└── Term (planning scaffold with status, references TimePeriod)

COMPOSIT LAYER (Junction tables for relationships)
├── ExpectationMeasure (goals/expectations → measurements)
├── MeasuredAction (actions → measurements taken)
├── ActionGoalContribution (actions → goals they advance)
├── GoalRelevance (goals → personal values)
└── TermGoalAssignment (terms → goals assigned to them)
```

### Key Relationships

#### 1. **TimePeriod ↔ Term (GoalTerm) - Planning Scaffolds**

```
TimePeriod (Abstraction)
  ├── id, startDate, endDate, title
  └── Chronological FACTS (e.g., "March 1 - May 10")

    ↕ Referenced by

GoalTerm (Basic)
  ├── id, timePeriodId (FK)
  ├── termNumber, theme, reflection
  ├── status: TermStatus (planned, active, completed, delayed, on_hold, cancelled)
  └── Planning SEMANTICS with state
```

**Key Insight**: TimePeriods are pure time boundaries (can exist independently). GoalTerms add planning semantics and status tracking. This separation allows calendar periods to exist without goal planning attached.

#### 2. **Goal ↔ Expectation - Inheritance Pattern**

```
Expectation (Base Abstraction)
  ├── id, title, detailedDescription
  ├── expectationImportance (1-10)
  ├── expectationUrgency (1-10)
  └── expectationType: [goal, milestone, obligation]

    ↕ Subtyped via
  
Goal (Basic)
  ├── id, expectationId (FK)
  ├── startDate, targetDate
  ├── actionPlan, expectedTermLength
  └── Specific to goals with date ranges
```

**Default Importance/Urgency**:
- Goals: Importance=8, Urgency=5 (self-directed, flexible timing)
- Milestones: Importance=5, Urgency=8 (time-sensitive checkpoints)
- Obligations: Importance=2, Urgency=6 (external, deadline-driven)

#### 3. **Goal ↔ Measure - Target Metrics**

```
ExpectationMeasure (Junction)
  ├── expectationId (FK)
  ├── measureId (FK to Measure catalog)
  ├── targetValue (e.g., 120.0 km)
  └── freeformNotes (explanation of target)

Measure (Abstraction - Catalog)
  ├── unit (km, hours, occasions)
  ├── measureType (distance, time, count)
  ├── canonicalUnit, conversionFactor (for conversions)
  └── Single source of truth for units
```

**Example**: A goal "Spring into Running" might have:
- ExpectationMeasure(km, 120.0) - distance target
- ExpectationMeasure(hours, 20.0) - time target  
- ExpectationMeasure(occasions, 30) - frequency target

#### 4. **Action ↔ Goal - Tracking Progress**

Two separate paths for contribution:

**Path A: Measurements**
```
MeasuredAction (Junction)
  ├── actionId (FK)
  ├── measureId (FK)
  ├── value (e.g., 5.2 km)
  └── createdAt

Used for: Tracking what was actually measured
Example: "Morning run" measured 5.2 km
```

**Path B: Contributions (explicit linking)**
```
ActionGoalContribution (Junction)
  ├── actionId (FK)
  ├── goalId (FK)
  ├── contributionAmount (how much advanced)
  ├── measureId (which metric advanced)
  └── createdAt

Used for: Explicitly linking actions to goals they serve
Example: "Morning run" contributed 5.2km toward "Run 120km goal"
```

**Key Distinction**: 
- MeasuredAction: "I ran 5.2 km" (factual measurement)
- ActionGoalContribution: "My run advanced Goal X by 5.2 km" (intentional linking)

#### 5. **Goal ↔ PersonalValue - Alignment**

```
GoalRelevance (Junction)
  ├── goalId (FK)
  ├── valueId (FK)
  ├── alignmentStrength (1-10)
  ├── relevanceNotes
  └── createdAt

PersonalValue (Abstraction)
  ├── title, priority
  ├── valueLevel: [general, major, highest_order, life_area]
  ├── lifeDomain (optional category)
  └── alignmentGuidance (how to align)
```

#### 6. **Term ↔ Goal - Planning**

```
TermGoalAssignment (Junction)
  ├── termId (FK to GoalTerm)
  ├── goalId (FK)
  ├── assignmentOrder
  └── createdAt

Shows which goals are being worked on in which term
```

---

## Part 2: Current Status/State Management

### Status Fields

#### 1. **GoalTerm Status** (Planning State)

Defined in `Term.swift` as `TermStatus` enum:

```swift
public enum TermStatus: String, Codable, CaseIterable {
    case planned = "planned"          // Future term, not yet started
    case active = "active"            // Currently working on goals
    case completed = "completed"      // Successfully finished
    case delayed = "delayed"          // Behind schedule
    case onHold = "on_hold"           // Paused, may resume
    case cancelled = "cancelled"      // Abandoned
}
```

**Stored in**: `goalTerms.status` column

#### 2. **Goal Active Status** (Derived)

There is NO status column on goals themselves. Instead, "active" is determined by:

```swift
// From GoalData.swift
public var isActive: Bool {
    guard let target = targetDate else { return true }
    return target > Date()
}
```

**Logic**: A goal is "active" if it has NO target date OR target date is in the future.

#### 3. **How Active Goals Are Currently Determined**

From `GoalRepository.fetchActiveGoals()`:

```sql
WHERE g.targetDate IS NULL OR g.targetDate >= date('now')
```

This query filters goals by:
1. No target date (open-ended goals), OR
2. Target date hasn't passed yet

**Use Case**: "Quick Add" in ActionsListView shows active goals for quick contribution logging.

### Current Filtering Logic

| View/Feature | Filter Applied | Repository Method |
|---|---|---|
| Goals List | All goals | `fetchAll()` |
| Active Goals (QuickAdd) | targetDate IS NULL OR targetDate >= today | `fetchActiveGoals()` |
| Goals by Term | termId matches | `fetchByTerm(termId)` |
| Goals by Value | valueId matches | `fetchByValue(valueId)` |
| Current Term | today falls in timePeriod date range | `TimePeriodRepository.fetchCurrentTerm()` |
| Terms by Status | status = ? | `TimePeriodRepository.fetchByStatus(status)` |

---

## Part 3: Progress Tracking

### What Exists

#### 1. **Measurement Targets (ExpectationMeasure)**

Stored goals for metrics:
```swift
public struct GoalData.MeasureTarget: Identifiable {
    public let measureId: UUID
    public let measureTitle: String?
    public let measureUnit: String        // km, hours, occasions
    public let targetValue: Double        // 120, 20, 30
}
```

#### 2. **Actual Measurements (MeasuredAction)**

What was actually done:
```swift
public struct ActionData.Measurement: Identifiable {
    public let measureId: UUID
    public let measureTitle: String?
    public let value: Double              // 5.2 km, 1 hour, 3 occasions
    public let createdAt: Date
}
```

#### 3. **Goal Contributions (ActionGoalContribution)**

How actions advance goals:
```swift
public struct ActionData.Contribution: Identifiable {
    public let goalId: UUID
    public let goalTitle: String?
    public let contributionAmount: Double?  // How much this action advanced the goal
    public let measureId: UUID?
    public let createdAt: Date
}
```

### What's Missing (As of v0.7.0)

**There is NO aggregation of progress yet.** The pieces exist:
- ✅ Target metrics defined (ExpectationMeasure)
- ✅ Actual measurements recorded (MeasuredAction, ActionGoalContribution)
- ❌ **Progress calculation not implemented** (actual vs target aggregation)
- ❌ **Progress visualization** (UI to show "120 km of 120 km target")

**Where progress calculation would happen**: Dashboard/analytics views or a new `ProgressService`.

---

## Part 4: Repositories and Data Access

### Repository Architecture

All repositories extend `BaseRepository<T>` which provides:
- Error mapping (DatabaseError → ValidationError)
- Read/write async wrappers
- Pagination helpers
- Date filtering utilities

### Repository Implementations

#### **GoalRepository** (Most Complex)
```
Query Pattern: JSON Aggregation
Relations: 3 (measures, values, term assignment)
Methods:
  - fetchAll()                    # All goals with full graph
  - fetchForExport()              # Goals filtered by date
  - fetchActiveGoals()            # targetDate NULL or future
  - fetchByTerm(termId)           # Goals in a specific term
  - fetchByValue(valueId)         # Goals aligned to a value
  - fetch(limit:offset:)          # Paginated
  - fetchRecent(limit:)           # Most recent by targetDate
  - exists(id:)                   # Check existence
```

**SQL Strategy**: Single JSON aggregation query with 3 nested subqueries:
```sql
SELECT goals.*, 
  (SELECT json_group_array(...) FROM measures) as measuresJson,
  (SELECT json_group_array(...) FROM values) as valuesJson,
  (SELECT json_object(...) FROM term_assignment) as termAssignmentJson
```

**Performance**: O(1) database round trips regardless of goal count (was O(5n) before)

#### **ActionRepository** (Second Most Complex)
```
Query Pattern: JSON Aggregation
Relations: 2 (measurements, contributions)
Methods:
  - fetchAll()                    # All actions with measurements & contributions
  - fetchForExport()              # Actions filtered by date
  - fetchByGoal(goalId)           # Actions contributing to a goal
  - fetchByMeasure(measureId)     # Actions using a specific metric
  - fetch(limit:offset:)          # Paginated
  - fetchRecent(limit:)           # Most recent by logTime
  - exists(id:)                   # Check existence
```

#### **TimePeriodRepository** (Simple)
```
Query Pattern: 1:1 JOIN (no aggregation)
Relations: 1 (GoalTerm join)
Methods:
  - fetchAll()                    # Terms with time periods
  - fetchCurrentTerm()            # TODAY falls in period
  - fetchByStatus(status)         # Terms with specific status
  - fetch(limit:offset:)          # Paginated
  - fetchRecent(limit:)           # By termNumber DESC
  - exists(id:)                   # Check existence
  - exists(termNumber:)           # Uniqueness of term numbers
  - hasOverlap(start:end:)        # Detect date conflicts
```

#### **PersonalValueRepository** (Simple)
```
Query Pattern: Direct #sql macro
Methods:
  - fetchAll()                    # All values sorted by priority
  - exists(id:)                   # Check existence
  - exists(title:)                # Uniqueness of titles
```

### Query Patterns Used

| Pattern | Repository | Use Case |
|---------|------------|----------|
| **JSON Aggregation** | Goal, Action | Multiple nested relationships |
| **Query Builder JOIN** | TimePeriod | Simple 1:1 relationships |
| **#sql Macro** | PersonalValue | Direct, type-safe queries |

### Data Type Conversions

```
Database ← → Canonical Type ← → View
──────────────────────────────────────

goals + expectations + 3 relations → GoalData → GoalRowView
  (JSON aggregation assembled)

actions + measurements + contributions → ActionData → ActionRowView
  (JSON aggregation assembled)

goalTerms + timePeriods + assignments → TimePeriodData → TermRowView
  (JOIN assembled)
```

---

## Part 5: ViewModels and Display Logic

### ViewModel Pattern (All List Views)

Modern pattern using `@Observable` (Swift 5.9+):

```swift
@Observable
@MainActor
public final class GoalsListViewModel {
    // State
    var goals: [GoalData] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    // Dependencies (not observable)
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database
    
    @ObservationIgnored
    private lazy var repository: GoalRepository = {
        GoalRepository(database: database)
    }()
    
    // Methods
    public func loadGoals() async {
        isLoading = true
        goals = try await repository.fetchAll()
        isLoading = false
    }
}
```

**Key Pattern**:
- `@Observable`: Auto-tracked properties trigger UI updates
- `@MainActor`: Ensures UI updates on main thread
- `@ObservationIgnored`: Prevents repo/database from triggering updates
- `lazy var repository`: Created once, reused for all queries

### List ViewModels Implemented

| ViewModel | Repository | Displays |
|-----------|-----------|----------|
| **GoalsListViewModel** | GoalRepository | All goals |
| **ActionsListViewModel** | ActionRepository | All actions + active goals (for QuickAdd) |
| **TermsListViewModel** | TimePeriodRepository | All terms with periods |
| **PersonalValuesListViewModel** | PersonalValueRepository | All values |

### Current Display Components

#### **GoalRowView**
```swift
Receives: GoalData (flat structure, no DB access)
Displays:
  - Title + description (from flattened expectation)
  - Date range (startDate → targetDate)
  - Importance/Urgency badges
  - Value alignment badges
  - Measurements (targets only, no progress yet)
```

#### **ActionRowView**
```swift
Receives: ActionData (flat structure)
Displays:
  - Title + description
  - Duration + start time
  - Measurements taken
  - Goals this action contributed to
```

#### **TermRowView**
```swift
Receives: TimePeriodData (flattened term + period)
Displays:
  - Term number + status (active, completed, etc.)
  - Theme
  - Date range
  - Count of assigned goals
```

### Data Flow: Database → View

```
                                    Database
                                       ↓
┌─────────────────────────────────────────────────────────────┐
│ Repository.fetchAll()                                       │
│ ├─ JSON aggregation SQL query (single round trip)          │
│ └─ Assemble canonical types (GoalData, ActionData, etc.)   │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
        ┌─────────────────────────────────┐
        │ ViewModel.loadGoals/Actions()    │
        │ ├─ Call repository async method │
        │ ├─ Update @Observable state     │
        │ └─ Handle errors                │
        └────────────────┬────────────────┘
                         ↓
            ┌────────────────────────┐
            │ SwiftUI View Tree       │
            │ ├─ List(viewModel.X)   │
            │ └─ XRowView(data)       │
            └────────────────────────┘
```

### Current Filtering/Prioritization

#### Goals Display Order
- `fetchAll()`: Ordered by `targetDate ASC NULLS LAST` (nearest deadlines first)
- `fetchActiveGoals()`: Same order
- `fetchByTerm()`: By term assignment

#### Actions Display Order
- `fetchAll()`: Ordered by `logTime DESC` (most recent first)

#### Terms Display Order
- `fetchAll()`: Ordered by `termNumber DESC` (recent terms first)

---

## Part 6: Key Patterns & Architecture Decisions

### Pattern: Coordinator Composition (v0.7.0)

Coordinators can call other coordinators for single source of truth:

```swift
// GoalCoordinator calls MeasureCoordinator
let measureCoordinator = MeasureCoordinator(database: database)
let measure = try await measureCoordinator.getOrCreate(
    unit: "km",
    measureType: "distance",
    title: "Kilometers"
)
```

**Benefits**:
- ✅ Duplicate prevention
- ✅ Single source of truth
- ✅ Idempotent operations

### Pattern: Canonical Data Types

One type per entity serves display + export:

```
GoalData  (not GoalWithDetails + GoalExport)
ActionData (not ActionWithDetails + ActionExport)
TimePeriodData (not TermWithPeriod + TermExport)
```

**Benefits**:
- ✅ Less boilerplate
- ✅ Single transformation
- ✅ Codable for direct JSON export

### Pattern: Denormalized Sub-Structures

Canonical types contain flat nested structs, not full entities:

```swift
public struct GoalData {
    public let id: UUID
    public let title: String?
    
    public struct MeasureTarget: Identifiable {
        public let measureTitle: String?
        public let targetValue: Double
    }
    
    public let measureTargets: [MeasureTarget]  // Not full Measure entities
}
```

**Benefits**:
- ✅ All display data in one fetch
- ✅ No follow-up queries needed
- ✅ Codable serialization works

---

## Part 7: Summary - Current State vs. Missing Features

### ✅ What's Complete

1. **Three-layer domain model** fully normalized
2. **Repository pattern** for all entities with JSON aggregation
3. **Status tracking** on GoalTerms (planned, active, completed, etc.)
4. **Active goal detection** (targetDate NULL or future)
5. **Measurement targets** (ExpectationMeasure)
6. **Measurement actuals** (MeasuredAction, ActionGoalContribution)
7. **List views** with proper ViewModel pattern
8. **Coordinators** for atomic writes
9. **Error mapping** and user-friendly messages

### ⏳ What's in Progress / Planned

1. **Progress calculation** (% of target achieved) - Phase 7
2. **Progress visualization** - Phase 7
3. **Dashboard aggregations** - Phase 7
4. **LLM Tool Integration** - Phase 7
5. **Semantic deduplication** - Phase 7
6. **HealthKit integration** - Planned

### 📊 Display Data Available Now

```
Goal Display:
  ✅ Title, description, importance, urgency
  ✅ Dates (start, target)
  ✅ Action plan, term length
  ✅ Measurement targets
  ✅ Value alignments
  ⏳ Progress % (targets exist but no aggregation)
  
Action Display:
  ✅ Title, description, duration
  ✅ Measurements taken
  ✅ Contributions to goals
  
Term Display:
  ✅ Term number, status, theme, reflection
  ✅ Assigned goals count
  ✅ Date range
```

---

## Quick Reference: Key File Locations

### Models
- `/Sources/Models/Abstractions/` - Base entities
- `/Sources/Models/Basics/` - Goal, Term (working entities)
- `/Sources/Models/Composits/` - Junction tables
- `/Sources/Models/DataTypes/` - GoalData, ActionData, TimePeriodData

### Services
- `/Sources/Services/Repositories/` - Read operations
- `/Sources/Services/Coordinators/` - Write operations
- `/Sources/Services/Validation/` - Business rule validation

### ViewModels
- `/Sources/App/ViewModels/ListViewModels/` - GoalsListViewModel, etc.
- `/Sources/App/ViewModels/FormViewModels/` - GoalFormViewModel, etc.

### Views
- `/Sources/App/Views/RowViews/` - GoalRowView, ActionRowView, TermRowView
- `/Sources/App/Views/Dashboard/` - DashboardView

### Database
- `/Sources/Database/Schemas/schema_current.sql` - Schema definition
