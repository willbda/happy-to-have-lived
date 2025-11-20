# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Do not run swift build without explicitely asking the user. It is inefficient, wasteful, and often uninformative to build prematurely in the middle of multiple changes.

## Project Overview

**Happy to Have Lived (HtHL)** - A Swift-based iOS/macOS/visionOS application for goal tracking and personal development.

- **Primary Language**: Swift 6.2
- **Platforms**: iOS 26+, macOS 26+, visionOS 26+
- **Database**: SQLite with SQLiteData ORM
- **Architecture**: Three-layer domain model with coordinators and repositories
- **Current Version**: 0.6.0 (Check `version.txt` for latest)



### Version Management

```bash
# Bump version (updates version.txt and creates git tag)
./bump_version.sh <version> "<message>"

# Example:
./bump_version.sh 0.7.0 "feat: Complete validation layer integration"
```


## Architecture Overview

### Three-Layer Domain Model

The codebase uses a normalized, layered architecture:

1. **Abstraction Layer** (`Sources/Models/Abstractions/`)
   - Base entities with full metadata (Action, Expectation, TimePeriod, Measure, PersonalValue)
   - All implement: `DomainAbstraction: Identifiable + Documentable + Timestamped`

2. **Basic Layer** (`Sources/Models/Basics/`)
   - User-friendly entities that reference abstractions (Goal, Milestone, Obligation, Term)
   - Lightweight operational data implementing `DomainBasic`

3. **Composit Layer** (`Sources/Models/Composits/`)
   - Junction tables for many-to-many relationships
   - Pure foreign key relationships with metadata

### Service Architecture

**Coordinators** (`Sources/Services/Coordinators/`)
- Handle multi-model atomic writes
- Create complex entity graphs in single transactions
- Example: `GoalCoordinator` creates Expectation + Goal + ExpectationMeasure[] + GoalRelevance[]

**Validators** (`Sources/Services/Validation/`)
- Enforce business rules before database writes
- Two-phase validation: `validateFormData()` then `validateComplete()`
- Throw user-friendly `ValidationError` messages

**Repositories** (`Sources/Services/Repositories/`) - ✅ **Complete (2025-11-13)**
- Abstract database queries from view layer
- All repositories have Sendable conformance
- Pattern varies by complexity:
  - **JSON Aggregation**: Goals, Actions (1:many relationships)
  - **#sql Macro**: PersonalValues (simple entities)
  - **Query Builder**: Terms (simple 1:1 JOINs)
- Map database errors to ValidationErrors
- Reference: `swift/docs/JSON_AGGREGATION_MIGRATION_PLAN.md`

### Database Schema

The database uses 3NF normalization with three conceptual layers:

@swift/Sources/Database/Schemas/schema_current.sql


## Current Development Status

### Phase Progress (v0.7.0)
- ✅ Phase 1-2: Model compilation
- ✅ Phase 3: Coordinator pattern implementation
- ✅ Phase 4: Validation layer integration
- ✅ Phase 5: Repository + ViewModel pattern (completed 2025-11-13)
- ✅ Phase 6: Coordinator composition + Semantic services (completed 2025-11-17)
- ⏳ Phase 7: LLM Tool Integration + Dashboard features

### Recent Completions (2025-11-17)
- ✅ **Measure Coordinator Composition** - Single source of truth for all measure creation
  - MeasureCoordinator.getOrCreate() idempotent pattern
  - GoalCoordinator and ActionCoordinator use coordinator composition
  - UI layer removed from direct database access
  - Duplicate prevention across all creation paths
- ✅ **Schema Updated** - Removed UNIQUE constraints for CloudKit sync
  - Application-level uniqueness via coordinators
  - Backward compatible with existing databases
- ✅ **Semantic Services Scaffolded** - Ready for embedding + LLM integration
  - EmbeddingGenerationService for NLEmbedding vectors
  - LLM ViewModels (GoalCoachViewModel, ValuesAlignmentCoach, ActionSuggestions)
  - SemanticMatchingService for similarity search
  - MeasureDeduplicationCoordinator for catalog cleanup

### Active Work Areas
1. **LLM Tool Integration** - Connect Foundation Models tools to coordinators
2. **Embedding Backfill** - Pre-generate embeddings for existing entities
3. **Semantic Deduplication** - Use embeddings for intelligent measure matching
4. **Dashboard/Analytics** - Aggregation queries using measure relationships
5. **HealthKit Integration** - Live tracking with measure coordinator

### Known Issues
- EmbeddingGenerationService needs GRDB import fix (minor)
- LLM ViewModels scaffolded but not integrated with LanguageModelSession yet

## Code Patterns and Conventions

### Creating Entities

**Always use coordinators for multi-model writes:**

```swift
// Good: Use coordinator for atomic multi-model creation
let coordinator = GoalCoordinator(database: database)
let goal = try await coordinator.create(from: formData)

// Bad: Direct database writes
try await database.write { db in
    try expectation.save(to: db)
    try goal.save(to: db)
}
```

### Coordinator Composition Pattern (NEW - v0.7.0)

**Key Pattern**: Coordinators can call other coordinators for single source of truth.

**Example: MeasureCoordinator as Service Coordinator**

All measure creation (goals, actions, HealthKit, UI) goes through `MeasureCoordinator.getOrCreate()`:

```swift
// Pattern: Idempotent get-or-create
let coordinator = MeasureCoordinator(database: database)
let measure = try await coordinator.getOrCreate(
    unit: "km",
    measureType: "distance",
    title: "Kilometers"  // Optional custom title
)
// → Returns existing if duplicate, creates if new
```

**Integration with GoalCoordinator:**

```swift
public func create(from formData: GoalFormData) async throws -> Goal {
    // STEP 1: Pre-transaction measure resolution
    let measureCoordinator = MeasureCoordinator(database: database)
    var resolvedTargets: [(measureId: UUID, value: Double)] = []

    for target in formData.measureTargets where target.isValid {
        // Pattern 1: User selected existing measure
        if let existingId = target.measureId {
            resolvedTargets.append((existingId, target.targetValue))
        }
        // Pattern 2: User creating new measure inline
        else if let unit = target.unit, let measureType = target.measureType {
            let measure = try await measureCoordinator.getOrCreate(
                unit: unit,
                measureType: measureType,
                title: target.measureTitle
            )
            resolvedTargets.append((measure.id, target.targetValue))
        }
    }

    // STEP 2: Main transaction with guaranteed measure IDs
    return try await database.write { db in
        let expectation = try Expectation.insert { ... }.fetchOne(db)!
        let goal = try Goal.insert { ... }.fetchOne(db)!

        // Use resolved measure IDs (never fails on missing measure)
        for (measureId, targetValue) in resolvedTargets {
            try ExpectationMeasure.insert {
                ExpectationMeasure.Draft(
                    expectationId: expectation.id,
                    measureId: measureId,
                    targetValue: targetValue
                )
            }.execute(db)
        }

        return goal
    }
}
```

**Why This Pattern:**
- ✅ Single source of truth: All measures via getOrCreate()
- ✅ Duplicate prevention: Idempotent across all creation paths
- ✅ Atomic safety: Measures created before transaction, IDs guaranteed
- ✅ Composable: Other coordinators can call MeasureCoordinator
- ✅ User experience: Users can create measures inline during goal/action creation

**Where It's Used:**
- GoalCoordinator → calls MeasureCoordinator
- ActionCoordinator → calls MeasureCoordinator
- MetricTargetRow (UI) → calls MeasureCoordinator
- HealthKitImportService → calls MeasureCoordinator

See `swift/docs/20251117_MEASURE_COORDINATOR_COMPOSITION.md` for complete architecture details.

### Validation Pattern

Two-phase validation ensures data integrity:

```swift
// Phase 1: Business rules (before write)
try validator.validateFormData(formData)

// Write to database via coordinator
let entity = try await coordinator.create(from: formData)

// Phase 2: Referential integrity (after write, optional)
try validator.validateComplete(entity)
```

### List ViewModel Pattern (Current Standard - 2025-11-13)

**ALL list views now use the Repository + @Observable ViewModel pattern.**

```swift
// PATTERN: List ViewModel with Repository
@Observable
@MainActor
public final class GoalsListViewModel {
    // Observable state (internal - no visibility modifier needed)
    // Properties accessed only by corresponding view
    var goals: [GoalWithDetails] = []
    var isLoading: Bool = false
    var errorMessage: String?

    var hasError: Bool { errorMessage != nil }

    // Dependencies (not observable)
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    private lazy var repository: GoalRepository = {
        GoalRepository(database: database)
    }()

    public init() {}

    // Standard methods (public - called by views)
    public func loadGoals() async {
        isLoading = true
        errorMessage = nil

        do {
            goals = try await repository.fetchAll()
        } catch let error as ValidationError {
            // User-friendly validation messages (e.g., "Goal title is required")
            errorMessage = error.userMessage
        } catch {
            // Generic fallback for unexpected errors
            errorMessage = "Failed to load goals: \(error.localizedDescription)"
        }

        isLoading = false
    }

    public func deleteGoal(_ goal: GoalWithDetails) async {
        // Uses coordinator for delete, then reloads
        // Same ValidationError handling pattern
    }
}

// In View:
@State private var viewModel = GoalsListViewModel()

.task {
    await viewModel.loadGoals()
}
.refreshable {
    await viewModel.loadGoals()
}
```

**Why This Pattern:**
- ✅ No @Fetch wrappers needed
- ✅ Explicit async/await
- ✅ Better separation of concerns
- ✅ Easier testing
- ✅ Loading and error states built-in
- ✅ @Observable provides automatic UI updates

**Reference**: All 4 list views (Goals, Actions, PersonalValues, Terms) follow this pattern.

### Repository Query Patterns

Repositories use different patterns based on complexity:

```swift
// PATTERN 1: JSON Aggregation (for 1:many relationships)
// Used by: GoalRepository, ActionRepository
let sql = """
SELECT g.*,
    COALESCE(
        (SELECT json_group_array(json_object(...))
         FROM measures WHERE goalId = g.id),
        '[]'
    ) as measuresJson
FROM goals g
"""

// PATTERN 2: #sql Macro (for simple queries)
// Used by: PersonalValueRepository
return try await database.read { db in
    try #sql(
        """
        SELECT \(PersonalValue.columns)
        FROM \(PersonalValue.self)
        ORDER BY \(PersonalValue.priority) DESC
        """,
        as: PersonalValue.self
    ).fetchAll(db)
}

// PATTERN 3: Query Builder (for simple JOINs)
// Used by: TimePeriodRepository
let results = try GoalTerm.all
    .order { $0.termNumber.desc() }
    .join(TimePeriod.all) { $0.timePeriodId.eq($1.id) }
    .fetchAll(db)

// Models use @Table and @Column macros from SQLiteData
@Table("goals")
public struct Goal: DomainBasic {
    @Column("id") public let id: UUID
    @Column("expectationId") public let expectationId: UUID
    @Column("startDate") public let startDate: Date
    @Column("targetDate") public let targetDate: Date
    // ...
}
```


## Important Files and Locations

- **Database Schema**: `swift/Sources/Database/Schemas/schema_current.sql`
- **Package Definition**: `swift/Package.swift`
- **Migration Plan**: `swift/docs/JSON_AGGREGATION_MIGRATION_PLAN.md` ✅ Complete
- **Visual Design System**: `swift/docs/LIQUID_GLASS_VISUAL_SYSTEM.md`
- **Concurrency Migration**: `swift/docs/CONCURRENCY_MIGRATION_20251110.md`

## Development Guidelines

### Core Principles

1. **Atomic Multi-Model Operations**: Always use coordinators for writes involving multiple models
2. **Validation First**: Validate data before attempting database writes
3. **Type Safety**: Leverage SQLiteData's compile-time safety with @Table/@Column macros
4. **Error Handling**: Convert database errors to user-friendly ValidationErrors
5. **Async/Await**: All database operations must be async for thread safety


### Effective Development Practices

#### Scaffolding Before Implementation

When working on bigger features, scaffold first:

1. **Create all needed files with descriptive comments**:
```swift
// GoalRepository.swift
// Written by Claude Code on 2025-11-08
//
// PURPOSE: Abstract database queries for Goal entities
// PATTERN: Repository pattern for data access
//
// RESPONSIBILITIES:
// - Fetch goals with related entities (expectations, measures, relevances)
// - Check for duplicate titles before insert
// - Map database errors to ValidationErrors
// - Support pagination and filtering
//
// TODO: Implement after validation layer complete
```

2. **Why this works well**:
- Provides high-level planning before diving into details
- Creates clear reminders of work in progress
- Helps identify dependencies and integration points early
- Makes the architecture visible before implementation

**Example**: See how `Sources/Services/Repositories/` is scaffolded - each file has clear intent comments but minimal implementation, making the planned architecture clear.

#### Smart Commenting Strategy

**DO comment when**:
- Making a judgment call or trade-off decision
- After researching or problem-solving to get something working
- Explaining WHY not WHAT (the code shows what, comments explain why)
- Documenting assumptions that might not be obvious
- Marking TODOs with context about prerequisites

**DON'T over-comment**:
- Use descriptive variable/function names instead of comments
- Don't explain obvious Swift/SwiftUI patterns
- Avoid comments that just restate what the code does

**Good Example**:
```swift
// Use bulk queries to avoid N+1 problem (was 763 queries, now 3)
// Pattern from SyncUpDetail.swift:47 - .where { ids.contains($0.id) }
let allMeasurementResults = try MeasuredAction
    .where { actionIds.contains($0.actionId) }
    .join(Measure.all) { $0.measureId.eq($1.id) }
    .fetchAll(db)

// Group by action ID for O(1) lookup during assembly
let measurementsByAction = Dictionary(grouping: allMeasurementResults) { $0.actionId }
```

**Bad Example**:
```swift
// Set isSaving to true
isSaving = true

// Create a new goal
let goal = Goal()

// Add the goal to the array
goals.append(goal)
```

## Common Tasks

### Adding a New Entity Type

1. Create model in appropriate layer (`Abstractions/`, `Basics/`, or `Composits/`)
2. Add @Table and @Column attributes for SQLiteData
3. Create FormData structure in `Services/Coordinators/FormData/`
4. Implement Coordinator in `Services/Coordinators/` (**MUST be `Sendable`, NO `@MainActor`**)
5. Implement Validator in `Services/Validation/`
6. Create Repository in `Services/Repositories/` (when pattern is complete)
7. Add database migration if schema changes
8. Write tests for coordinator and validator

### Creating a New Coordinator (Swift 6 Pattern)

**Template** (based on PersonalValueCoordinator):
```swift
/// SWIFT 6 CONCURRENCY PATTERN:
/// - NO @MainActor: Database I/O runs in background
/// - Sendable: Safe to pass from @MainActor ViewModels
/// - Immutable state: Only private let properties
public final class MyEntityCoordinator: Sendable {
    private let database: any DatabaseWriter  // Must be immutable (let, not var)

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    public func create(from formData: MyEntityFormData) async throws -> MyEntity {
        try await database.write { db in
            // Database operations here
        }
    }
}
```

**Key Requirements**:
- ✅ Mark `Sendable` (required for actor boundaries)
- ❌ NO `@MainActor` (database I/O should be background)
- ❌ NO `ObservableObject` (legacy pattern)
- ✅ Only `private let` properties (immutable state)
- ✅ All public methods must be `async throws`

### Creating a New ViewModel (Swift 6 Pattern)

**Form ViewModel Template** (based on ActionFormViewModel):
```swift
@Observable
@MainActor
public final class MyEntityFormViewModel {
    // UI state properties (auto-tracked by @Observable)
    var isSaving: Bool = false
    var errorMessage: String?

    // Dependencies (mark with @ObservationIgnored)
    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    // Coordinator (lazy var with @ObservationIgnored)
    @ObservationIgnored
    private lazy var coordinator: MyEntityCoordinator = {
        MyEntityCoordinator(database: database)
    }()

    public init() {}

    public func save(from formData: MyEntityFormData) async throws -> MyEntity {
        isSaving = true  // ← Main actor
        defer { isSaving = false }

        // This automatically switches to background, then back to main
        let entity = try await coordinator.create(from: formData)
        errorMessage = nil
        return entity
    }
}
```

**List ViewModel Template** (based on GoalsListViewModel):
```swift
@Observable
@MainActor
public final class MyEntitiesListViewModel {
    // Observable state (internal, not public - no visibility modifier needed)
    var items: [MyEntity] = []
    var isLoading: Bool = false
    var errorMessage: String?

    var hasError: Bool { errorMessage != nil }

    // Dependencies (not observable)
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    private lazy var repository: MyEntityRepository = {
        MyEntityRepository(database: database)
    }()

    public init() {}

    public func loadItems() async {
        isLoading = true
        errorMessage = nil

        do {
            items = try await repository.fetchAll()
        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ MyEntitiesListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic error fallback
            errorMessage = "Failed to load items: \(error.localizedDescription)"
            print("❌ MyEntitiesListViewModel: \(error)")
        }

        isLoading = false
    }

    public func deleteItem(_ item: MyEntity) async {
        isLoading = true
        errorMessage = nil

        do {
            let coordinator = MyEntityCoordinator(database: database)
            try await coordinator.delete(item: item)
            await loadItems()
        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ MyEntitiesListViewModel ValidationError: \(error.userMessage)")
        } catch {
            // Generic error fallback
            errorMessage = "Failed to delete item: \(error.localizedDescription)"
            print("❌ MyEntitiesListViewModel: \(error)")
        }

        isLoading = false
    }
}
```

**Key Requirements**:
- ✅ Mark `@Observable` (modern pattern, NOT ObservableObject)
- ✅ Mark `@MainActor` (UI state management)
- ✅ Use `@State` in views (NOT `@StateObject`)
- ✅ Mark dependencies with `@ObservationIgnored`
- ✅ Use lazy repository/coordinator with `@ObservationIgnored`
- ✅ Internal properties (not public)


## Documentation Research with doc-fetcher

### When to Use doc-fetcher

The doc-fetcher skill is highly effective for researching API documentation and should be your first step when:
- Looking up Swift/SwiftUI APIs from developer.apple.com
- Researching SQLiteData or other package documentation
- Encountering JS-heavy documentation pages that can't be fetched directly
- Needing to understand modern patterns or recent API changes
- Cross-referencing concepts across different documentation sources

### How to Use doc-fetcher Effectively

```bash
# Search pre-indexed documentation (most efficient)
cd ~/.claude/skills/doc-fetcher
python doc_fetcher.py search "Observable @MainActor Swift 6" --limit 10

# Fetch and index new documentation
python doc_fetcher.py fetch "https://developer.apple.com/documentation/swiftui/observable" --crawl --depth 2

# For complex research questions, consider using an agent
# The agent can search with doc-fetcher and review pre-loaded data more efficiently
```

### Why doc-fetcher is Token-Efficient

- Pre-indexes documentation for fast searching
- Returns relevant snippets rather than full pages
- Handles JavaScript-rendered pages that normal fetch tools can't access
- Maintains a searchable database of previously fetched content
- Avoids redundant fetching of already-indexed pages

**Tip**: When researching unfamiliar APIs or checking if patterns have changed in recent iOS/macOS versions, always start with doc-fetcher rather than trying to fetch pages directly.

## Reference Documentation Library

A comprehensive collection of indexed documentation is available at `/Users/davidwilliams/Coding/REFERENCE/documents/`.

### Directory Structure

```
REFERENCE/documents/
├── SwiftLanguage/          [113 files: Swift 6.2 Programming Language book]
├── appleDeveloper/         [34 files: SwiftUI, SwiftData, Foundation Models]
├── hig_docs/               [17 files: Human Interface Guidelines]
└── GRDB/                   [1 file: Historical SQLite reference]
```

### 1. Swift Language Guide (113 files)

**Path**: `/Users/davidwilliams/Coding/REFERENCE/documents/SwiftLanguage/`
**Source**: Official Swift Programming Language (v6.2) from docs.swift.org
**Format**: Markdown + 84 PNG diagrams
**Last Updated**: 2025-10-21

#### Core Sections

**Introduction** (`01-Introduction/`)
- About Swift, Version Compatibility, A Swift Tour

**Language Guide** (`02-LanguageGuide/`) - 29 chapters
- Fundamentals: The Basics, Basic Operators, Strings and Characters, Collection Types, Control Flow
- Functions & Closures: Functions, Closures
- Type System: Classes and Structures, Enumerations, Properties, Methods, Subscripts, Inheritance
- Advanced Types: Optional Chaining, Type Casting, Nested Types, Extensions, Protocols, Generics, Opaque Types
- Memory & Safety: Initialization, Deinitialization, Automatic Reference Counting, Memory Safety, Access Control
- Modern Features: **Concurrency** (Swift 6 patterns), **Macros** (@Observable, @Table, etc.), Error Handling
- Operators: Advanced Operators

**Language Reference** (`03-ReferenceManual/`) - 10 files
- Technical specifications: Lexical Structure, Types, Expressions, Statements, Declarations, Attributes, Patterns, Generic Parameters and Arguments, Grammar Summary

**Most Relevant to Project**:
- `02-LanguageGuide/18-Concurrency.md` - Swift 6 async/await, actors, Sendable, @MainActor
- `02-LanguageGuide/19-Macros.md` - Understanding @Observable, @Table, @Column macros
- `02-LanguageGuide/24-Protocols.md` - Protocol-oriented programming patterns
- `02-LanguageGuide/25-Generics.md` - Type-safe generic patterns
- `02-LanguageGuide/27-AutomaticReferenceCounting.md` - Memory management, reference cycles

### 2. Apple Developer Documentation (34 files)

**Path**: `/Users/davidwilliams/Coding/REFERENCE/documents/appleDeveloper/`

#### 2.1 SwiftUI (13 files) - `appleDeveloper/swiftui/`

**Core Framework**:
- `swiftui.md` - Framework overview
- `app.md`, `app-organization.md` - App structure and lifecycle
- `scenes.md`, `windows.md` - Scene management
- `view.md` - View fundamentals
- `appkit.md`, `uikit.md` - Legacy framework integration

**Modern Design**:
- `adopting-liquid-glass.md` - iOS 26+ visual design system
- `landmarks-building-an-app-with-liquid-glass.md` - Liquid Glass tutorial

**Tutorials**:
- `building-a-document-based-app-with-swiftui.md`
- `bot-anist.md`, `destination-video.md`

**Project Relevance**: Core framework currently in use. See `swift/docs/LIQUID_GLASS_VISUAL_SYSTEM.md` for project-specific design implementation.

#### 2.2 SwiftData (11 files) - `appleDeveloper/swiftdata/`

**Core APIs**:
- `swiftdata.md` - Framework overview
- `model.md` - @Model macro and entity definition
- `query.md` - @Query property wrapper
- `index_.md` - Performance indexing
- `attribute_originalnamehashmodifier.md` - Schema evolution
- `relationship_deleteruleminimummodelcountmaximummodelcountoriginalnameinversehashmodifier.md` - Relationships
- `unique_.md` - Uniqueness constraints

**Tutorials**:
- `adding-and-editing-persistent-data-in-your-app.md`
- `adopting-inheritance-in-swiftdata.md`
- `adopting-swiftdata-for-a-core-data-app.md`
- `preserving-your-apps-model-data-across-launches.md`

**Project Note**: This project uses **SQLiteData**, not SwiftData. These docs are useful for:
- Comparison and understanding alternative approaches
- Potential migration considerations
- Understanding Apple's modern data persistence patterns

#### 2.3 Foundation Models (10 files) - `appleDeveloper/foundationmodels/`

**Core APIs** (iOS 26+ on-device LLM):
- `foundation-models.md` - Framework overview
- `systemlanguagemodel.md` - System model access
- `languagemodelsession.md` - Session management
- `prompt.md`, `instructions.md` - Prompt engineering
- `tool.md` - Function calling / tool use
- `transcript.md` - Conversation history

**Advanced Features**:
- `generating-swift-data-structures-with-guided-generation.md` - Structured output (guided generation)
- `improving-the-safety-of-generative-model-output.md` - Safety controls
- `support-languages-and-locales-with-foundation-models.md` - Localization

**Project Status**: Planned integration for on-device assistance. See "Active Work Areas" in Current Development Status.

### 3. Human Interface Guidelines (17 files)

**Path**: `/Users/davidwilliams/Coding/REFERENCE/documents/hig_docs/`
**Platforms**: iOS, macOS, visionOS design patterns

**Design Foundations**:
- `foundations.md` - Core design principles
- `color.md`, `typography.md` - Visual language
- `layout.md` - Spatial organization
- `patterns.md` - Common interaction patterns
- `modality.md` - Modal presentation

**Components**:
- `buttons.md` - Button styles and usage
- `text-fields.md` - Text input patterns
- `lists-and-tables.md` - Data presentation
- `toolbars.md` - Toolbar design
- `progress-indicators.md` - Loading states
- `feedback.md` - User feedback patterns
- `entering-data.md` - Form design

**Framework-Specific**:
- `swiftui.md` - SwiftUI component guidelines
- `swiftdata.md` - Data persistence UX patterns
- `designing-for-macos.md` - macOS-specific patterns
- `technology-overviews.md` - Framework overviews

**Project Relevance**: Primary reference for UI/UX implementation. Complements `swift/docs/LIQUID_GLASS_VISUAL_SYSTEM.md`.

### 4. GRDB Reference (1 file)

**Path**: `/Users/davidwilliams/Coding/REFERENCE/documents/GRDB/`

- `README.md` - GRDB.swift SQLite toolkit documentation

**Project Note**: Historical reference. The project previously considered GRDB but evolved toward SQLiteData. Useful for understanding:
- Alternative SQLite approaches in Swift
- Performance optimization patterns
- Migration strategies

### Quick Access Patterns

```bash
# Swift 6 Concurrency patterns
/Users/davidwilliams/Coding/REFERENCE/documents/SwiftLanguage/02-LanguageGuide/18-Concurrency.md

# Macro system (@Observable, @Table)
/Users/davidwilliams/Coding/REFERENCE/documents/SwiftLanguage/02-LanguageGuide/19-Macros.md

# SwiftUI modern patterns
/Users/davidwilliams/Coding/REFERENCE/documents/appleDeveloper/swiftui/adopting-liquid-glass.md

# Foundation Models API
/Users/davidwilliams/Coding/REFERENCE/documents/appleDeveloper/foundationmodels/foundation-models.md

# HIG design guidelines
/Users/davidwilliams/Coding/REFERENCE/documents/hig_docs/foundations.md
```

### Research Workflow

1. **For Swift language questions**: Start with `SwiftLanguage/02-LanguageGuide/` relevant chapter
2. **For framework APIs**: Check `appleDeveloper/swiftui/` or `appleDeveloper/foundationmodels/`
3. **For design decisions**: Reference `hig_docs/` for platform patterns
4. **For complex research**: Use doc-fetcher skill to search indexed documentation
5. **For live APIs**: Use doc-fetcher to fetch and index new developer.apple.com pages

### File Format Summary

- **Total files**: 145 reference documents
- **Markdown files**: 96 (all documentation)
- **Images**: 84 (Swift Language diagrams - bitwise ops, memory cycles, etc.)
- **README files**: 2 (SwiftLanguage, GRDB)

## Modern Swift/SwiftUI Patterns (iOS 26+, Swift 6.2)

### Critical Pattern Updates

The codebase targets iOS 26+ and should use modern patterns throughout:

#### 1. Observable Pattern (Use @Observable, NOT ObservableObject)

**Modern Pattern (Correct)**:
```swift
@Observable
@MainActor
public final class ActionFormViewModel {
    var isSaving: Bool = false  // No @Published needed
    var errorMessage: String?   // Auto-tracked by @Observable

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database
}

// In View:
@State private var viewModel = ActionFormViewModel()  // NOT @StateObject
```

**Legacy Pattern (Avoid)**:
```swift
// DON'T DO THIS - ObservableObject is legacy
class OldViewModel: ObservableObject {
    @Published var isSaving = false  // Avoid @Published
}

// DON'T DO THIS - @StateObject is legacy
@StateObject private var viewModel = OldViewModel()
```

#### 2. Concurrency (Swift 6 Strict Concurrency) - ✅ Migrated 2025-11-10

**IMPORTANT**: All coordinators, ViewModels, and services have been migrated to modern Swift 6 concurrency patterns.
See `swift/docs/CONCURRENCY_MIGRATION_20251110.md` for complete migration history.

**Modern Patterns** (Current as of v0.6.0):

**ViewModels - @Observable + @MainActor**:
```swift
// ✅ CORRECT: ViewModels manage UI state
@Observable
@MainActor
public final class ActionFormViewModel {
    var isSaving: Bool = false  // UI state tracked by @Observable
    var errorMessage: String?

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    // Lazy coordinator pattern (Swift 6 strict concurrency)
    @ObservationIgnored
    private lazy var coordinator: ActionCoordinator = {
        ActionCoordinator(database: database)
    }()

    func save() async throws {
        isSaving = true  // ← Main actor (UI update)
        let result = try await coordinator.create(...)  // ← Background (I/O)
        isSaving = false  // ← Main actor (UI update)
    }
}
```

**Coordinators - Sendable, NO @MainActor**:
```swift
// ✅ CORRECT: Coordinators are stateless I/O services
public final class ActionCoordinator: Sendable {
    private let database: any DatabaseWriter  // Immutable

    // All methods run in background (not on main actor)
    public func create(from formData: ActionFormData) async throws -> Action {
        try await database.write { db in
            // Heavy database I/O - runs off main thread
        }
    }
}
```

**Data Types - Sendable for Actor Boundaries**:
```swift
// ✅ CORRECT: Types passed between actors must be Sendable
public struct ActionWithDetails: Identifiable, Hashable, Sendable {
    public let action: Action
    public let measurements: [MeasuredActionWithMeasure]
    public let contributions: [ActionGoalContributionWithGoal]
}
```

**Key Rules** (Swift 6 Strict Concurrency):
1. **@MainActor on ViewModels**: Ensures UI updates on main thread
2. **NO @MainActor on Coordinators**: Database I/O runs in background
3. **Sendable on Coordinators**: Safe to pass from @MainActor to nonisolated contexts
4. **Lazy Coordinator Storage**: Use `lazy var` with `@ObservationIgnored` in ViewModels
5. **Automatic Context Switching**: Swift handles main → background → main automatically

**Why This Matters**:
- Database operations no longer block the UI thread
- Automatic context switching between main actor and background
- Type-safe actor isolation with compile-time checking
- Professional-grade concurrency without manual thread management

**Research References**:
- Swift Language Guide: `/Users/davidwilliams/Coding/REFERENCE/documents/SwiftLanguage/02-LanguageGuide/18-Concurrency.md`
- Concurrency Migration: `swift/docs/CONCURRENCY_MIGRATION_20251110.md`
- @Observable macro docs: Use doc-fetcher to fetch latest Apple documentation

#### 3. Database Queries - Repository + ViewModel Pattern (Current Standard)

**CURRENT PATTERN** (as of 2025-11-13):
All list views use Repository + @Observable ViewModel pattern. **No @Fetch wrappers.**

```swift
// In Repository: JSON Aggregation, #sql, or Query Builder
public final class GoalRepository: Sendable {
    public func fetchAll() async throws -> [GoalWithDetails] {
        try await database.read { db in
            // JSON aggregation SQL here
            let rows = try GoalQueryRow.fetchAll(db, sql: sql)
            return try rows.map { row in
                try assembleGoalWithDetails(from: row)
            }
        }
    }
}

// In ViewModel: Lazy repository access
@Observable
@MainActor
public final class GoalsListViewModel {
    var goals: [GoalWithDetails] = []

    @ObservationIgnored
    private lazy var repository: GoalRepository = {
        GoalRepository(database: database)
    }()

    public func loadGoals() async {
        goals = try await repository.fetchAll()
    }
}

// In View: @State with .task
@State private var viewModel = GoalsListViewModel()

.task {
    await viewModel.loadGoals()
}
```

**Why This Pattern:**
- ✅ Explicit data flow (clear where data comes from)
- ✅ Loading/error states built-in
- ✅ Testable (mock repository)
- ✅ @Observable provides automatic updates
- ✅ No wrapper abstraction layer

**Anti-Patterns to Avoid**:
```swift
// ❌ DON'T use @Fetch wrappers (eliminated in migration)
@Fetch(wrappedValue: [], ActionsQuery())
private var actions: [ActionWithDetails]

// ❌ DON'T use raw SQL strings without type safety
let results = try database.execute("SELECT * FROM actions")  // Unsafe

// ❌ DON'T use SwiftData's @Query (we use SQLiteData, not SwiftData)
@Query(sort: \Item.title) var items  // Wrong library!
```

#### 4. Dependency Injection

**Modern Pattern**:
```swift
// Use @Dependency with @ObservationIgnored
@Observable
class ViewModel {
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database
}
```

#### 5. Form Data Pattern

**Modern Pattern**:
```swift
// Use structured FormData types for complex forms
struct ActionFormData {
    var title: String = ""
    var measurements: [MeasurementInput] = []
}

// Pass to coordinators for atomic writes
let action = try await coordinator.create(from: formData)
```

### Pitfalls to Avoid

1. **Mixing Observable Patterns**: Don't use `@Published` with `@Observable` classes
2. **Wrong State Storage**: Use `@State` not `@StateObject` for @Observable classes
3. **Manual Database Observation**: Use `@Fetch` with FetchKeyRequest for automatic updates
4. **Raw SQL Without Type Safety**: Always use `#sql` macros instead of raw SQL strings
5. **Synchronous Database Access**: All database operations must be async
6. **Missing Sendable**: Add `Sendable` conformance to types passed between actors
7. **Missing MainActor**: ViewModels without `@MainActor` can cause UI updates off main thread
8. **Wrong Query Pattern**: Use `FetchKeyRequest` with `#sql` for complex joins, not manual queries

### Migration Checklist

When updating existing code:
- [ ] Replace `ObservableObject` with `@Observable`
- [ ] Remove all `@Published` properties
- [ ] Change `@StateObject` to `@State` in views
- [ ] Add `@MainActor` to ViewModels
- [ ] Add `Sendable` to data types
- [ ] Convert raw SQL to `#sql` macros for type safety
- [ ] Use `FetchKeyRequest` with `@Fetch` for complex queries
- [ ] Mark dependencies with `@ObservationIgnored`
- [ ] Ensure all models have `@Table` and `@Column` attributes

### Platform Features (iOS 26+, macOS 26+)

The app targets the latest platforms:
- iOS 26+ (latest)
- macOS 26+ (Tahoe)
- visionOS 26+

This enables use of:
- Latest Swift 6.2 language features
- Modern SwiftUI APIs
- Strict concurrency checking
- @Observable macro (Observation framework)
- Enhanced @Query and data flow patterns