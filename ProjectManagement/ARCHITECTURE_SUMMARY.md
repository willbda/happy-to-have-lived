# Happy to Have Lived - Codebase Architecture Map

**Generated:** 2025-11-19
**Total Files:** 166 Swift source files
**Version:** 0.7.0+

---

## Architecture Overview

This codebase follows a **layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────────┐
│                        SwiftUI Views (60 files)                 │
│  • Form Views (6)  • List Views (6)  • Row Views (6)           │
│  • Components (7)  • Templates (7)   • CSV/Health/Debug (8)    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    ViewModels (16 files)                        │
│  • Form VMs (6)  • List VMs (6)  • LLM VMs (1)  • Utility (3) │
│  Pattern: @Observable @MainActor                                │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                   Coordinators (18 files)                       │
│  • Multi-model atomic transactions                              │
│  • FormData definitions (10)                                    │
│  • Composition pattern (MeasureCoordinator)                     │
│  Pattern: Sendable, NO @MainActor                               │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    Services (42 files)                          │
│  • LLM/Foundation Models (12)  • Import/Export (10)            │
│  • Progress (3)  • Semantic (3)  • Embedding (2)               │
│  • HealthKit (3)  • Validation (3)  • Deduplication (4)        │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                   Repositories (13 files)                       │
│  • BaseRepository + Core (4)                                    │
│  • Entity Repositories (9): Goal, Action, PersonalValue, etc.  │
│  • Patterns: JSON aggregation, #sql macro, query builder       │
│  Pattern: Sendable, NO @MainActor                               │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                      Models (30 files)                          │
│  • Abstractions (6): DomainAbstraction entities (@Table)       │
│  • Basics (5): DomainBasic entities (@Table)                   │
│  • Composits (4): Junction tables (@Table)                     │
│  • DataTypes (6): Canonical Codable structures                 │
│  • Semantic (4): Embedding and alignment types                 │
│  • Deduplication (2): Duplicate detection models               │
│  • HealthKit (3): HealthKit data wrappers                      │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                   Database (3 files)                            │
│  • Bootstrap  • SyncConfiguration  • CloudKitManualSync        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Statistical Summary

### Files by Layer

| Layer | Files | Percentage |
|-------|-------|------------|
| Service-LLM | 12 | 7.2% |
| Coordinator-FormData | 10 | 6.0% |
| Service-Import/Export | 10 | 6.0% |
| Repository | 9 | 5.4% |
| Coordinator | 8 | 4.8% |
| View-Component | 7 | 4.2% |
| View-Template | 7 | 4.2% |
| Model-Abstraction | 6 | 3.6% |
| Model-DataType | 6 | 3.6% |
| ViewModel-Form | 6 | 3.6% |
| ViewModel-List | 6 | 3.6% |
| View-Form | 6 | 3.6% |
| View-List | 6 | 3.6% |
| View-Row | 6 | 3.6% |
| **Other Layers** | 55 | 33.1% |
| **TOTAL** | **166** | **100%** |

### Files by Domain Entity

| Domain Entity | Files | Primary Focus |
|---------------|-------|---------------|
| Cross-cutting | 33 | Infrastructure, shared utilities |
| PersonalValue | 17 | Values alignment and hierarchy |
| Goal | 16 | Goal creation, tracking, progress |
| Measure | 12 | Measurement catalog and targeting |
| LLM | 12 | Foundation Models integration |
| Action | 11 | Action logging and contributions |
| TimePeriod | 10 | Time periods and term planning |
| HealthKit | 10 | Health data import and tracking |
| Milestone | 9 | Point-in-time checkpoints |
| Obligation | 9 | External commitments |
| **Other Domains** | 27 | Import, Export, Progress, etc. |

### Concurrency Patterns

| Pattern | Files | Usage |
|---------|-------|-------|
| Sendable | 85 | Background services, repositories, coordinators |
| @MainActor | 63 | ViewModels, Views, UI-bound services |
| @unchecked Sendable | 10 | Repositories with immutable DatabaseWriter |
| None | 8 | Protocols, utilities, static helpers |

### Complexity Distribution

| Complexity | Files | Percentage | Notes |
|------------|-------|------------|-------|
| Simple | 91 | 54.8% | < 150 lines, straightforward logic |
| Medium | 57 | 34.3% | 150-400 lines, moderate complexity |
| Complex | 18 | 10.8% | > 400 lines, sophisticated logic |

---

## Architectural Patterns

### Key Patterns in Use

| Pattern | Count | Where Used |
|---------|-------|------------|
| **SwiftUI Views** | 44 | All UI layer (Forms, Lists, Rows, Components) |
| **@Table Models (SQLiteData)** | 17 | Abstractions, Basics, Composits layers |
| **@Observable ViewModels** | 16 | All ViewModels (Form, List, LLM, Utility) |
| **Repository Pattern** | 15 | Data access abstraction with BaseRepository |
| **Sendable Value Types** | 10 | FormData, DataTypes for actor boundaries |
| **LLM Tools (@Tool)** | 8 | Foundation Models tools for on-device LLM |
| **JSON Aggregation (Complex SQL)** | 3 | Goal, Action repositories (avoid N+1) |

### Repository Query Strategies

Three distinct patterns based on complexity:

1. **JSON Aggregation** (Goal, Action) - Most complex
   - Aggregates 1:many relationships via `json_group_array()`
   - Single SQL query, avoids N+1 problem
   - Example: GoalRepository fetches goal + measures + values + term in one query

2. **#sql Macro** (PersonalValue, Measure) - Medium complexity
   - Type-safe SQL with compile-time checking
   - Simple entities with optional JOINs
   - Example: `#sql("SELECT * FROM measures WHERE unit = ?", Measure.self)`

3. **Query Builder** (TimePeriod) - Simplest
   - SQLiteData query builder API
   - Simple 1:1 JOINs
   - Example: `GoalTerm.all.join(TimePeriod.all).fetchAll(db)`

### Coordinator Patterns

**Single Source of Truth via Composition:**

- `MeasureCoordinator.getOrCreate()` - Idempotent measure creation
- `GoalCoordinator` calls `MeasureCoordinator` before transaction
- `ActionCoordinator` calls `MeasureCoordinator` before transaction
- `MetricTargetRow` (UI) calls `MeasureCoordinator` for inline creation

**Transaction Complexity:**

| Coordinator | Models Created | Complexity |
|-------------|----------------|------------|
| GoalCoordinator | 5+ (Expectation + Goal + Measures + Values + Term) | Most Complex |
| ActionCoordinator | 3 (Action + Measurements + Contributions) | Complex |
| TimePeriodCoordinator | 2 (TimePeriod + GoalTerm?) | Medium |
| PersonalValueCoordinator | 1 (PersonalValue) | Simple |

---

## Most Complex Files (18 total)

These files exceed 400 lines and contain sophisticated logic:

### Repositories (3)
- `BaseRepository.swift` - Template method pattern with generic DataType
- `GoalRepository.swift` - 3 JSON aggregations (measures, values, terms)
- `ActionRepository.swift` - 2 JSON aggregations (measurements, contributions)

### Coordinators (2)
- `GoalCoordinator.swift` - 5+ model atomic transaction with composition
- `ActionCoordinator.swift` - 3 model transaction with get-or-create pattern

### Services (6)
- `SemanticService.swift` - NLEmbedding integration with caching
- `EmbeddingGenerationService.swift` - Text builders + cache management
- `ProgressCalculationService.swift` - Aggregation across measures
- `HealthKitManager.swift` - Authorization + multi-type queries
- `HealthKitImportService.swift` - ETL from HealthKit to database
- `GoalCoachService.swift` - LLM orchestration with tools

### Import/Export (3)
- `DataImporter.swift` - Generic import orchestrator
- `Importers.swift` - Entity-specific importer implementations

### Views & ViewModels (4)
- `GoalFormView.swift` - Multi-section form with nested relationships
- `GoalFormViewModel.swift` - Complex form state management
- `GoalCoachView.swift` - LLM chat interface
- `GoalCoachViewModel.swift` - Conversation history + tool integration
- `MetricTargetRow.swift` - Inline measure creation with get-or-create

---

## Domain Model Architecture

### Three-Layer Model (3NF Normalized)

```
┌──────────────────────────────────────────────────────────┐
│         ABSTRACTION LAYER (DomainAbstraction)            │
│  Full metadata entities: id + Documentable + Timestamped │
│  • Action (past-oriented records)                        │
│  • Expectation (table inheritance base)                  │
│  • Measure (measurement catalog)                         │
│  • PersonalValue (values + life areas)                   │
│  • TimePeriod (chronological boundaries)                 │
└──────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────┐
│              BASIC LAYER (DomainBasic)                   │
│  Lightweight entities: id + FK references + type fields  │
│  • Goal (Expectation subtype)                            │
│  • Milestone (Expectation subtype)                       │
│  • Obligation (Expectation subtype)                      │
│  • GoalTerm (planning scaffold)                          │
│  • ExpectationMeasure (target junction)                  │
└──────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────┐
│            COMPOSIT LAYER (DomainComposit)               │
│  Junction tables: id + FK1 + FK2 + relationship data    │
│  • ActionGoalContribution                                │
│  • GoalRelevance                                         │
│  • MeasuredAction                                        │
│  • TermGoalAssignment                                    │
└──────────────────────────────────────────────────────────┘
```

### Canonical Data Types (Export & Display)

Each entity has a **single canonical type** for both display and export:

- `GoalData` - Replaces GoalWithDetails + GoalExport (flattened structure)
- `ActionData` - Replaces ActionWithDetails + ActionExport
- `PersonalValueData` - Denormalized value with aligned goals
- `TimePeriodData` - Period + optional GoalTerm
- `MeasureData` - Pure measure entity
- `ProgressData` - Progress calculations and metadata

**Benefits:**
- No transformation needed between display and export
- All types are `Codable & Sendable & Identifiable`
- Eliminates duplicate type definitions
- Simplifies repository APIs

---

## Service Architecture

### Service Categories

#### 1. Foundation Models / LLM (12 files)

On-device LLM integration using iOS 26+ FoundationModels:

- **Tools** (8): CreateGoalTool, GetGoalsTool, GetValuesTool, etc.
- **Services** (3): GoalCoachService, ConversationHistory, ModelAvailability
- **Types** (1): ConversationError

**Pattern:** `@Tool` protocol + `LanguageModelSession` orchestration

#### 2. Import/Export (10 files)

CSV/JSON import and export pipeline:

- **Export** (2): Exporter, CSVFormatter
- **Import** (8): DataImporter, CSVParser, JSONParser, Validators, Importers

**Pattern:** Parse → Validate → Transform → Persist (via Coordinators)

#### 3. Progress Tracking (3 files)

Goal progress calculation and aggregation:

- ProgressCalculationService (measures actuals vs targets)
- ProgressAggregationService (weighted averages)
- ActiveStatusService (lifecycle management)

**Pattern:** Repository queries → Aggregation → ProgressData

#### 4. Semantic / LLM (5 files)

Semantic similarity and embedding generation:

- SemanticService (NLEmbedding wrapper + cache)
- EmbeddingGenerationService (title-only, full-context variants)
- EmbeddingBackfillService (batch generation)
- ValueAlignmentService (goal-value similarity)

**Pattern:** Text → NLEmbedding → Cache → Similarity calculation

#### 5. Deduplication (4 files)

Semantic duplicate detection:

- SemanticDuplicateDetector (generic detector)
- SemanticGoalDetector (goal-specific)
- DuplicationResult, SemanticDetectable (types)

**Pattern:** Embedding similarity → Threshold check → Block or warn

#### 6. HealthKit (3 files)

Health data import and tracking:

- HealthKitManager (authorization + queries)
- HealthKitImportService (ETL to database)
- HealthKitLiveTrackingService (real-time observer)

**Pattern:** HKHealthStore → Parse → MeasureCoordinator → MeasuredAction

#### 7. Validation (3 files)

Business rule validation:

- ValidationError (user-friendly error types)
- ValidationRules (two-phase validation)
- ValidationUtilities (string/date helpers)

**Pattern:** FormData → Validate → Coordinator → Database

#### 8. Matching (1 file)

Action-goal matching logic:

- MatchingService (eligible goal detection)

**Pattern:** Action + Measures → Find matching Goals

---

## Concurrency Architecture (Swift 6 Strict Concurrency)

### Actor Isolation Strategy

```
┌─────────────────────────────────────────────────────────┐
│                    @MainActor                           │
│  • All ViewModels (@Observable)                         │
│  • All SwiftUI Views                                    │
│  • UI-bound services (HealthKitManager, etc.)           │
└──────────────────────────┬──────────────────────────────┘
                           │
                           │ async/await
                           │ (automatic context switching)
                           │
┌──────────────────────────▼──────────────────────────────┐
│                    Sendable (nonisolated)               │
│  • All Coordinators (multi-model atomic writes)        │
│  • All Repositories (database queries)                  │
│  • All Services (business logic)                        │
│  • All FormData (value types)                           │
│  • All DataTypes (Codable structures)                   │
└─────────────────────────────────────────────────────────┘
```

### Key Rules

1. **@MainActor on ViewModels** - Ensures UI updates on main thread
2. **NO @MainActor on Coordinators** - Database I/O runs in background
3. **Sendable on Coordinators** - Safe to pass from @MainActor to nonisolated contexts
4. **Lazy Coordinator Storage** - Use `lazy var` with `@ObservationIgnored` in ViewModels
5. **Automatic Context Switching** - Swift handles main → background → main automatically

### Example Flow

```swift
// ViewModel (Main Actor)
@Observable
@MainActor
public final class GoalFormViewModel {
    var isSaving: Bool = false  // ← Main actor (UI state)

    @ObservationIgnored
    private lazy var coordinator: GoalCoordinator = {
        GoalCoordinator(database: database)
    }()

    public func save() async throws {
        isSaving = true  // ← Main actor
        let goal = try await coordinator.create(...)  // ← Background (I/O)
        isSaving = false  // ← Main actor
    }
}

// Coordinator (Sendable, nonisolated)
public final class GoalCoordinator: Sendable {
    private let database: any DatabaseWriter  // Immutable

    public func create(...) async throws -> Goal {
        try await database.write { db in
            // Heavy database I/O - runs off main thread
        }
    }
}
```

---

## Data Flow Patterns

### 1. Create Entity (User-initiated)

```
User Input → FormView → FormViewModel (@MainActor)
                ↓
            FormData (Sendable)
                ↓
        Validation.validateFormData()
                ↓
        Coordinator.create(formData) (Sendable, background)
                ↓
        database.write { ... } (atomic transaction)
                ↓
            Database
                ↓
        Repository.fetchAll() (background)
                ↓
        ListView (Main Actor, automatic update via @Observable)
```

### 2. Display Entity List

```
ListView.onAppear → ListViewModel.loadItems() (@MainActor)
                        ↓
                Repository.fetchAll() (Sendable, background)
                        ↓
                database.read { ... }
                        ↓
                [DataType] (Sendable, Codable)
                        ↓
            ListViewModel.items = ... (@MainActor)
                        ↓
            ListView updates (automatic via @Observable)
```

### 3. Export to CSV

```
ExportView → ExportViewModel (@MainActor)
                ↓
        Exporter.export(from:to:) (Sendable, background)
                ↓
        Repository.fetchForExport(from, to) (date filtering)
                ↓
        [DataType] (Codable, ready for serialization)
                ↓
        CSVFormatter.format([DataType])
                ↓
        Write to file
```

### 4. Import from CSV

```
File Picker → ImportPreviewView → ExportViewModel (@MainActor)
                    ↓
        CSVParser.parse(fileURL) (Sendable)
                    ↓
        [ParsedRow] (intermediate type)
                    ↓
        ImportValidator.validate()
                    ↓
        FormDataTransformer.transform([ParsedRow])
                    ↓
        [FormData] (Sendable)
                    ↓
        Coordinator.create(formData) for each item (atomic)
                    ↓
        Database
```

### 5. LLM Goal Creation

```
User Message → GoalCoachView → GoalCoachViewModel (@MainActor)
                    ↓
        GoalCoachService.sendMessage() (@MainActor)
                    ↓
        LanguageModelSession.run()
                    ↓
        LLM calls tools: GetGoalsTool, GetValuesTool, CheckDuplicateGoalTool
                    ↓
        CreateGoalTool returns GoalFormData (guided generation)
                    ↓
        GoalCoordinator.create(formData) (Sendable, background)
                    ↓
        Database
                    ↓
        ListView updates automatically
```

### 6. HealthKit Import

```
HealthDashboardView → Trigger Import → HealthKitManager (@MainActor)
                            ↓
        HKHealthStore.requestAuthorization()
                            ↓
        HealthKitImportService.importWorkouts() (Sendable)
                            ↓
        HKSampleQuery.execute()
                            ↓
        [HKWorkout] → Parse → [HealthWorkout]
                            ↓
        MeasureCoordinator.getOrCreate() (unit, measureType)
                            ↓
        ActionCoordinator.create(measurements) (via coordinator composition)
                            ↓
        Database (Action + MeasuredActions)
```

---

## File Organization

```
swift/Sources/
├── Database/                      (3 files)
│   ├── DatabaseBootstrap.swift
│   ├── SyncConfiguration.swift
│   └── CloudKitManualSync.swift
│
├── Models/                        (30 files)
│   ├── Abstractions/             (6 files: Action, Expectation, Measure, PersonalValue, TimePeriod, Protocols)
│   ├── Basics/                   (5 files: Goal, Milestone, Obligation, Term, ExpectationMeasure)
│   ├── Composits/                (4 files: ActionGoalContribution, GoalRelevance, MeasuredAction, TermGoalAssignment)
│   ├── DataTypes/                (6 files: GoalData, ActionData, PersonalValueData, TimePeriodData, MeasureData, ProgressData)
│   ├── SemanticTypes/            (4 files: EmbeddingVector, EmbeddingCacheEntry, SemanticConfiguration, AlignmentMatrix)
│   ├── Deduplication/            (2 files: DuplicateCandidate, EntitySignature)
│   └── [HealthKit Models]        (3 files: HealthWorkout, HealthSleep, HealthMindfulness)
│
├── Services/                      (42 files)
│   ├── Repositories/             (13 files)
│   │   ├── Core/                (4 files: RepositoryProtocols, BaseRepository, QueryStrategies, ExportSupport)
│   │   └── [Entity Repos]       (9 files: Goal, Action, PersonalValue, Measure, TimePeriod, Milestone, Obligation, Conversation, EmbeddingCache)
│   │
│   ├── Coordinators/             (18 files)
│   │   ├── FormData/            (10 files: Goal, Action, PersonalValue, Measure, TimePeriod, Milestone, Obligation, Expectation base, ExpectationMeasure, ValueAlignment)
│   │   └── [Coordinators]       (8 files: Goal, Action, PersonalValue, Measure, TimePeriod, Milestone, Obligation, MeasureDeduplication)
│   │
│   ├── Validation/               (3 files: ValidationError, ValidationRules, ValidationUtilities)
│   ├── Progress/                 (3 files: ProgressCalculation, ProgressAggregation, ActiveStatus)
│   ├── Semantic/                 (3 files: SemanticService, EmbeddingBackfill, ValueAlignment)
│   ├── Embedding/                (2 files: EmbeddingGeneration, SourceTextBuilders)
│   ├── Deduplication/            (4 files: DuplicationResult, SemanticDetectable, SemanticDuplicateDetector, SemanticGoalDetector)
│   ├── HealthKit/                (3 files: HealthKitManager, HealthKitImport, HealthKitLiveTracking)
│   ├── ImportExport/             (10 files: Exporter, CSVFormatter, DataImporter, CSVParser, JSONParser, ImportTypes, ImportValidator, Importers, EntityParsers, FormDataTransformer)
│   ├── FoundationModels/         (12 files)
│   │   ├── Services/            (3 files: GoalCoach, ConversationHistory, ModelAvailability)
│   │   ├── Tools/               (8 files: CreateGoal, GetGoals, CheckDuplicate, GetValues, GetMeasures, GetRecentActions, GetProgress placeholder, AnalyzeAlignment placeholder)
│   │   └── [Types]              (1 file: ConversationError)
│   │
│   └── [Utilities]               (2 files: MatchingService, Dependencies+Semantic)
│
└── App/                           (76 files)
    ├── ViewModels/               (16 files)
    │   ├── FormViewModels/      (6 files: Goal, Action, PersonalValue, TimePeriod, Milestone, Obligation)
    │   ├── ListViewModels/      (6 files: Goals, Actions, PersonalValues, Terms, Milestones, Obligations)
    │   ├── LLMViewModels/       (1 file: GoalCoach)
    │   └── [Utilities]          (3 files: Export, HealthDashboard, ValueAlignmentHeatmap)
    │
    └── Views/                    (60 files)
        ├── FormViews/           (6 files: Goal, Action, PersonalValue, Term, Milestone, Obligation)
        ├── ListViews/           (6 files: Goals, Actions, PersonalValues, Terms, Milestones, Obligations)
        ├── RowViews/            (6 files: Goal, Action, PersonalValue, Term, Milestone, Obligation)
        ├── Components/          (7 files: MeasurementInput, MetricTarget, MultiSelect, Repeating, Timing, ProgressIndicator, QuickAdd)
        ├── Templates/           (7 files: Badge, DateGrouping, DocumentableFields, EntityRow, FormHelpers, MeasurementDisplay, ValidationFeedback)
        ├── CSV/                 (3 files: CSVExportImport, ImportPreview, ImportResult)
        ├── Health/              (3 files: HealthDashboardTest, WorkoutsTest, WorkoutDetail)
        ├── Debug/               (2 files: MeasureDeduplication, SyncDebug)
        ├── LLM/                 (1 file: GoalCoach)
        ├── Dashboard/           (1 file: Dashboard)
        ├── Analytics/           (1 file: ValueAlignmentHeatmap)
        └── [Root]               (1 file: ContentView)
```

---

## Dependencies Summary

### External Frameworks

- **Foundation** - All files (standard library)
- **SwiftUI** - All views (60 files)
- **SQLiteData** - All models + repositories + coordinators (58 files)
- **GRDB** - Repository layer (13 files)
- **FoundationModels** - LLM integration (12 files)
- **HealthKit** - Health data import (13 files: 3 services + 10 views/viewmodels)
- **CloudKit** - Sync infrastructure (3 files)
- **NaturalLanguage** - Semantic embedding (5 files)
- **Dependencies** - Dependency injection (2 files)

### Internal Dependencies

- **Models** → (no dependencies)
- **Database** → Models, SQLiteData
- **Repositories** → Models, Database, GRDB
- **Coordinators** → Models, Database, Repositories (for get-or-create)
- **Services** → Models, Database, Repositories, Coordinators
- **ViewModels** → Models, Coordinators, Repositories, Services
- **Views** → Models, ViewModels

---

## Key Design Decisions

### 1. Three-Layer Model (3NF Normalization)

**Decision:** Use three distinct model layers (Abstraction, Basic, Composit)

**Benefits:**
- Clear separation of concerns
- 3NF normalization eliminates data duplication
- Type-safe table inheritance (Expectation → Goal/Milestone/Obligation)
- Junction tables make relationships explicit

**Trade-offs:**
- More complex than denormalized models
- Requires JOINs for full entity graph

### 2. Canonical DataTypes (Single Type for Display + Export)

**Decision:** Use single `DataType` for both display and export (no separate ExportType)

**Benefits:**
- No transformation needed between display and export
- Eliminates duplicate type definitions
- Simpler repository APIs
- All types are `Codable & Sendable & Identifiable`

**Trade-offs:**
- DataTypes are larger (include all fields for both display and export)

### 3. Repository Query Strategies (Not One-Size-Fits-All)

**Decision:** Use different query patterns based on complexity

**Patterns:**
1. JSON Aggregation (Goal, Action) - Complex 1:many relationships
2. #sql Macro (PersonalValue, Measure) - Simple entities
3. Query Builder (TimePeriod) - Simple 1:1 JOINs

**Benefits:**
- Right tool for the job
- JSON aggregation avoids N+1 problem for complex entities
- #sql macro provides type safety for simple queries
- Query builder is most readable for simple JOINs

**Trade-offs:**
- Inconsistent API across repositories
- Developers must learn multiple patterns

### 4. Coordinator Composition (MeasureCoordinator.getOrCreate)

**Decision:** Coordinators can call other coordinators for single source of truth

**Pattern:** All measure creation goes through `MeasureCoordinator.getOrCreate()`

**Benefits:**
- Idempotent measure creation
- Prevents duplicates across all creation paths
- User can create measures inline during goal/action creation
- Atomic safety (measures created before transaction)

**Trade-offs:**
- Pre-transaction calls add latency
- Coordinators are more coupled

### 5. Two-Phase Validation

**Decision:** Validate in two phases: FormData (before write) + Complete (after write)

**Phases:**
1. **Phase 1 (FormData):** Business rules (title not empty, date range valid, etc.)
2. **Phase 2 (Complete):** Referential integrity (FKs exist, no orphaned records)

**Benefits:**
- Catches errors early (before database write)
- FK validation after write ensures referential integrity
- Clear separation of business rules vs database constraints

**Trade-offs:**
- More complex validation logic
- Some validation happens after write (Phase 2)

### 6. Swift 6 Strict Concurrency

**Decision:** Adopt Swift 6 strict concurrency checking from start

**Rules:**
- @MainActor on ViewModels (UI state)
- Sendable on Coordinators/Repositories/Services (background I/O)
- NO @MainActor on Coordinators (database I/O runs in background)

**Benefits:**
- Database operations never block UI thread
- Automatic context switching (main → background → main)
- Type-safe actor isolation with compile-time checking
- Professional-grade concurrency

**Trade-offs:**
- More verbose (must mark Sendable, @MainActor explicitly)
- Learning curve for Swift concurrency

### 7. On-Device LLM (FoundationModels)

**Decision:** Use iOS 26+ FoundationModels for on-device LLM (not cloud API)

**Benefits:**
- Privacy-preserving (all data stays on device)
- No API costs
- Instant responses (no network latency)
- Offline capability

**Trade-offs:**
- iOS 26+ only (limits user base)
- Smaller model than cloud LLMs
- Requires A17 chip or later for best performance

### 8. Semantic Duplicate Detection

**Decision:** Use NLEmbedding for semantic similarity (not exact string matching)

**Pattern:** Title-only embeddings for fast duplicate detection

**Benefits:**
- Catches semantic duplicates ("run marathon" vs "complete 26.2 miles")
- Configurable thresholds (exact, high, moderate, low)
- Can block or warn user before creation

**Trade-offs:**
- Requires embedding generation (CPU cost)
- False positives possible (similar but not duplicate)

---

## Recent Changes (v0.7.0+)

### Completed Features

1. **Repository + ViewModel Pattern** (2025-11-13)
   - All list views use Repository + @Observable ViewModel
   - Eliminated @Fetch wrappers
   - Explicit async/await with loading/error states

2. **Coordinator Composition** (2025-11-17)
   - MeasureCoordinator.getOrCreate() pattern
   - GoalCoordinator and ActionCoordinator use composition
   - UI layer removed from direct database access

3. **Schema Updates** (2025-11-17)
   - Removed UNIQUE constraints for CloudKit sync
   - Application-level uniqueness via coordinators
   - Backward compatible with existing databases

4. **Semantic Services Scaffolded** (2025-11-17)
   - EmbeddingGenerationService
   - SemanticService with caching
   - Duplicate detection infrastructure
   - LLM ViewModels (scaffolded)

### Active Work (Phase 7)

- LLM Tool Integration (connect tools to coordinators)
- Embedding Backfill (generate for existing entities)
- Semantic Deduplication (use embeddings for measure matching)
- Dashboard/Analytics (aggregation queries)
- HealthKit Integration (live tracking)

---

## Usage Examples

### Example: Create a Goal via Coordinator

```swift
// 1. Build FormData (Sendable value type)
let formData = GoalFormData(
    title: "Run a marathon",
    measureTargets: [
        MeasureTargetInput(
            unit: "km",
            measureType: "distance",
            targetValue: 120.0,
            measureTitle: "Kilometers"
        )
    ],
    valueAlignments: [
        ValueAlignmentInput(
            valueId: healthValueId,
            alignmentStrength: 9
        )
    ]
)

// 2. Create via Coordinator (Sendable, runs in background)
let coordinator = GoalCoordinator(database: database)
let goal = try await coordinator.create(from: formData)

// 3. Fetch full data via Repository
let repository = GoalRepository(database: database)
let goalData = try await repository.fetchAll().first(where: { $0.id == goal.id })
```

### Example: Display Goals List

```swift
// ViewModel (@Observable @MainActor)
@Observable
@MainActor
public final class GoalsListViewModel {
    var goals: [GoalData] = []
    var isLoading: Bool = false

    @ObservationIgnored
    private lazy var repository: GoalRepository = {
        GoalRepository(database: database)
    }()

    public func loadGoals() async {
        isLoading = true
        goals = try await repository.fetchAll()
        isLoading = false
    }
}

// View
@State private var viewModel = GoalsListViewModel()

.task {
    await viewModel.loadGoals()
}
```

### Example: Export to CSV

```swift
let exporter = Exporter(database: database)
let csvData = try await exporter.exportGoals(
    from: startDate,
    to: endDate,
    format: .csv
)
// GoalData is Codable, no transformation needed
```

### Example: LLM Goal Creation

```swift
// ViewModel (@MainActor)
@Observable
@MainActor
public final class GoalCoachViewModel {
    var messages: [Message] = []

    private lazy var service: GoalCoachService = {
        GoalCoachService(database: database)
    }()

    public func sendMessage(_ text: String) async {
        let response = try await service.sendMessage(text)
        // LLM can call tools:
        // - GetGoalsTool (see existing goals)
        // - GetValuesTool (align with values)
        // - CheckDuplicateGoalTool (prevent duplicates)
        // - CreateGoalTool (create via GoalCoordinator)
    }
}
```

---

## Testing Strategy

### Unit Tests

- **Models:** Codable round-trip, property validation
- **Repositories:** Query correctness, error mapping
- **Coordinators:** Atomic transactions, FK validation
- **Services:** Business logic, error handling

### Integration Tests

- **Repository + Coordinator:** End-to-end create/read/update/delete
- **Import/Export:** CSV round-trip, data integrity
- **HealthKit:** Mock HKHealthStore, ETL correctness

### UI Tests

- **Form Views:** Input validation, error display
- **List Views:** Data display, delete confirmation
- **LLM Views:** Conversation flow, tool calling

---

## Future Enhancements

### Phase 8: Dashboard & Analytics (Planned)

- Aggregation queries for progress tracking
- Value alignment heatmaps
- Term-based goal filtering
- Progress charts and visualizations

### Phase 9: CloudKit Sync (In Progress)

- Full sync with conflict resolution
- Manual sync triggers
- Sync status indicators

### Phase 10: HealthKit Live Tracking (Planned)

- Real-time workout tracking
- Background observers for HealthKit changes
- Automatic action creation from HealthKit

### Phase 11: Advanced LLM Features (Future)

- Context window management (summarization)
- RAG (retrieval-augmented generation)
- Multi-turn goal refinement
- Value alignment suggestions

---

## Documentation

- **ARCHITECTURE_MAP_COMPLETE.csv** - Complete file listing with metadata
- **ARCHITECTURE_SUMMARY.md** - This document
- **CLAUDE.md** - Project-specific guidance for Claude Code
- **swift/docs/** - Implementation docs
  - JSON_AGGREGATION_MIGRATION_PLAN.md
  - CONCURRENCY_MIGRATION_20251110.md
  - LIQUID_GLASS_VISUAL_SYSTEM.md
  - 20251117_MEASURE_COORDINATOR_COMPOSITION.md

---

## Contributors

- **David Williams** - Product vision, architecture
- **Claude Code** - Implementation partner

---

**Last Updated:** 2025-11-19
**Version:** 0.7.0+
