# Measure Coordinator Composition Pattern

## Session: November 17, 2025
## Phase 6: Consolidating Measure Creation Paths

---

## Overview

This session implemented a critical architectural pattern: **Coordinator Composition**. All measure creation now flows through a single, idempotent `MeasureCoordinator.getOrCreate()` path, eliminating duplicate prevention logic spread across the codebase.

### What Changed
- 8 logical commits consolidating measure creation patterns
- UI layer removed from direct database access
- GoalCoordinator and ActionCoordinator now use coordinator composition
- Schema updated for CloudKit sync compatibility

### Files Affected: 22 modified, 4 deleted, 6 added, 1 documentation

---

## Problem Statement: Before

### Problem 1: Multiple Measure Creation Paths

**MetricTargetRow.swift (UI Layer)**
```swift
// ❌ Direct database write from UI component
let newMeasure = try await database.write { db in
    try Measure.upsert { Measure.Draft(...) }.fetchOne(db)!
}
```

**HealthKitImportService.swift (Service Layer)**
```swift
// ❌ Duplicate findOrCreateMeasure() inside transaction
try await database.write { db in
    let durationMeasure = try findOrCreateMeasure(unit: "hours", measureType: "time", in: db)
}
```

**ActionCoordinator.swift (Coordinator Layer)**
```swift
// ❌ Validation fails if measure doesn't exist
for measurement in formData.measurements where measurement.measureId != nil {
    let measureExists = try Measure.find(measurement.measureId!).fetchOne(db) != nil
    guard measureExists else {
        throw ValidationError.invalidMeasure(...)
    }
}
```

### Problem 2: No Deduplication

Measures created through different paths weren't deduplicated:
- User manually creates "km" in MetricTargetRow
- HealthKit import creates "kilometers" (different spelling)
- No case-insensitive matching
- Result: Duplicate measures in catalog

### Problem 3: Architecture Violation

Separation of concerns broken:
- UI components wrote directly to database
- Services had inline measure creation logic
- Coordinators failed on missing measures (no get-or-create)
- Tests couldn't mock measure creation

---

## Solution: Coordinator Composition Pattern

### Architecture

```
GoalCoordinator.create(formData)
├─ 1. Pre-transaction: MeasureCoordinator.getOrCreate()
│      ├─ repository.exists(unit, measureType)
│      ├─ If exists → return existing
│      └─ If not → create new (guaranteed)
│
├─ 2. Resolve all measure IDs to guaranteed existing
│
├─ 3. Main transaction: database.write { db in }
│      ├─ Insert Expectation
│      ├─ Insert Goal
│      ├─ Insert ExpectationMeasure[] (with resolved IDs)
│      └─ Insert GoalRelevance[]
│
└─ 4. Return Goal
```

### Key Insight: Get-or-Create is Idempotent

```swift
// Call 1: Measure doesn't exist
let measure = try await measureCoordinator.getOrCreate(unit: "km", measureType: "distance")
// → Creates new measure, returns it

// Call 2: Same measure, same parameters
let measure = try await measureCoordinator.getOrCreate(unit: "km", measureType: "distance")
// → Finds existing, returns it (no duplicate created!)
```

---

## Implementation Details

### New Infrastructure (Commit 1)

**MeasureCoordinator.swift**
```swift
public final class MeasureCoordinator: Sendable {
    public func getOrCreate(
        unit: String,
        measureType: String,
        title: String? = nil
    ) async throws -> Measure {
        let repository = MeasureRepository(database: database)

        // Pattern 1: Existing measure
        if let existing = try await repository.fetchByUnitAndType(unit, measureType) {
            return existing
        }

        // Pattern 2: Create new
        let formData = MeasureFormData(
            title: title ?? unit.capitalized,
            unit: unit,
            measureType: measureType
        )
        return try await create(from: formData)
    }
}
```

**ExpectationMeasureFormData.swift** - Supports Both Patterns
```swift
public struct ExpectationMeasureFormData: Identifiable {
    // Pattern 1: User selects existing measure
    public var measureId: UUID?

    // Pattern 2: User creates new measure inline
    public var unit: String?
    public var measureType: String?
    public var measureTitle: String?

    // Value for the metric target
    public var targetValue: Double

    public var isValid: Bool {
        (measureId != nil || (unit != nil && measureType != nil)) && targetValue > 0
    }
}
```

### Goal Coordinator Refactoring (Commit 2)

**Before**: Validate measureIds exist inside transaction (fails if missing)

**After**: Resolve all measures BEFORE transaction
```swift
public func create(from formData: GoalFormData) async throws -> Goal {
    try GoalValidation.validateFormData(formData)

    // BEFORE TRANSACTION: Get-or-create measures
    let measureCoordinator = MeasureCoordinator(database: database)
    var resolvedTargets: [(measureId: UUID, value: Double, notes: String?)] = []

    for target in formData.measureTargets where target.isValid {
        let measure: Measure
        if let existingId = target.measureId {
            // Pattern 1: Existing measure
            measure = try await repository.fetch(existingId)!
        } else if let unit = target.unit, let measureType = target.measureType {
            // Pattern 2: Get-or-create new
            measure = try await measureCoordinator.getOrCreate(
                unit: unit,
                measureType: measureType,
                title: target.measureTitle
            )
        } else {
            continue
        }

        resolvedTargets.append((
            measureId: measure.id,
            value: target.targetValue,
            notes: target.notes
        ))
    }

    // THEN TRANSACTION: Use resolved IDs
    return try await database.write { db in
        let expectation = try Expectation.insert { ... }.fetchOne(db)!
        let goal = try Goal.insert { ... }.fetchOne(db)!

        for target in resolvedTargets {
            try ExpectationMeasure.insert {
                ExpectationMeasure.Draft(
                    expectationId: expectation.id,
                    measureId: target.measureId,  // Guaranteed to exist
                    targetValue: target.value
                )
            }.execute(db)
        }

        return goal
    }
}
```

### Action Coordinator Refactoring (Commit 3)

Applied same pattern to actions:
```swift
// MeasurementInput extended with get-or-create fields
public struct MeasurementInput {
    public var measureId: UUID?          // Pattern 1: Existing
    public var unit: String?             // Pattern 2: Create new
    public var measureType: String?
    public var measureTitle: String?
    public var value: Double
}

// ActionCoordinator.create() uses same composition
for measurement in formData.measurements where measurement.isValid {
    let measureId: UUID
    if let existingId = measurement.measureId {
        measureId = existingId
    } else if let unit = measurement.unit, let measureType = measurement.measureType {
        let measure = try await measureCoordinator.getOrCreate(...)
        measureId = measure.id
    } else {
        continue
    }
    // ... use guaranteed measureId
}
```

### UI Layer Cleanup (Commit 4)

**MetricTargetRow.swift** - Removed Direct Database Access
```swift
// Before: Direct write
let newMeasure = try await database.write { db in
    try Measure.upsert { ... }.fetchOne(db)!
}

// After: Coordinator call (idempotent)
let coordinator = MeasureCoordinator(database: database)
let newMeasure = try await coordinator.getOrCreate(
    unit: unit,
    measureType: type,
    title: title
)
```

Benefits:
- ✅ No direct database access in UI
- ✅ Returns existing if duplicate (idempotent)
- ✅ ValidationError handling instead of crashes

### Service Layer Integration (Commit 5)

**HealthKitImportService.swift** - Coordinator Composition

Removed inline measure creation (`findOrCreateMeasure` function - 35 lines):
```swift
// Before: Duplicate logic inside transaction
try await database.write { db in
    let durationMeasure = try findOrCreateMeasure(unit: "hours", ..., in: db)
    let distanceMeasure = try findOrCreateMeasure(unit: "km", ..., in: db)
}

// After: Coordinator composition before transaction
let measureCoordinator = MeasureCoordinator(database: database)
let durationMeasure = try await measureCoordinator.getOrCreate(unit: "hours", measureType: "time")
let distanceMeasure = try await measureCoordinator.getOrCreate(unit: "km", measureType: "distance")

try await database.write { db in
    // Use guaranteed measure IDs
}
```

---

## Schema Changes (Commit 6)

### Removed UNIQUE Constraints

**Before**:
```sql
CREATE TABLE expectationMeasures (
    expectationId TEXT NOT NULL,
    measureId TEXT NOT NULL,
    UNIQUE(expectationId, measureId)  -- Database enforces uniqueness
);
```

**After**:
```sql
CREATE TABLE expectationMeasures (
    expectationId TEXT NOT NULL,
    measureId TEXT NOT NULL
    -- UNIQUE constraint removed
);
```

### Why?

**CloudKit Sync Problem**: UNIQUE constraints can't be enforced reliably during distributed sync
- Device A creates (expectationId=1, measureId=2)
- Device B creates (expectationId=1, measureId=2) offline
- When syncing, constraint violation on both devices

**Solution**: Application-level uniqueness

```swift
// MeasureRepository checks before insert
public func getOrCreateExpectationMeasure(
    expectationId: UUID,
    measureId: UUID
) async throws -> ExpectationMeasure {
    // Check if exists
    if let existing = try await repository.find(expectationId, measureId) {
        return existing
    }

    // Create if not
    return try await coordinator.create(...)
}
```

### Migration

✅ **No breaking changes**:
- Existing databases keep UNIQUE constraints
- New installations use constraint-free schema
- Application code handles both cases gracefully

---

## Testing & Validation (Commit 7)

Updated all tests to verify:

1. **Duplicate Detection**
   ```swift
   let measure1 = try await coordinator.getOrCreate(unit: "km", measureType: "distance")
   let measure2 = try await coordinator.getOrCreate(unit: "km", measureType: "distance")
   XCTAssertEqual(measure1.id, measure2.id)  // Same ID!
   ```

2. **Coordinator Composition**
   ```swift
   let goal = try await goalCoordinator.create(from: formData)
   // Verify GoalCoordinator called MeasureCoordinator
   // Verify measures created before goal transaction
   ```

3. **Both Patterns Work**
   ```swift
   // Pattern 1: Select existing
   formData.measureTargets[0].measureId = existingMeasure.id

   // Pattern 2: Create new
   formData.measureTargets[1].unit = "km"
   formData.measureTargets[1].measureType = "distance"

   let goal = try await coordinator.create(from: formData)
   // Both patterns should work together
   ```

---

## New Infrastructure (Commit 8)

### LLM ViewModels
- **GoalCoachViewModel**: Conversational goal creation via Foundation Models
- **ValuesAlignmentCoachViewModel**: Analyze goal-value alignment
- **ActionSuggestionCoachViewModel**: LLM-suggested next actions

### Semantic Services
- **EmbeddingGenerationService**: Create NLEmbedding vectors
- **EmbeddingSourceTextBuilders**: Build semantic-rich text for embedding
- **SemanticMatchingService**: Cosine similarity + fuzzy matching

### Debug Infrastructure
- **MeasureDeduplicationView**: Test measure deduplication UI
- **DebugViewModel**: Database inspection tools

---

## Architectural Insights

### Ontological Truth

From **MeasureRefactor.md**:

> "Measures are discovered through use, not pre-defined catalogs"

**Implication**: Users don't manually manage a measure catalog. Measures emerge naturally:
- User creates goal: "Run 120 km in 10 weeks"
- System ensures "km" measure exists (creates if needed)
- Catalog grows from actual usage, not predefined

### Coordinator Composition is Service Pattern

MeasureCoordinator is now a **service coordinator**:
- Called by GoalCoordinator (entity coordinator)
- Called by ActionCoordinator (entity coordinator)
- Called by UI (MetricTargetRow)
- Called by services (HealthKitImportService)

Not just "entity coordinators that create one thing" but coordinators that **serve other coordinators**.

### Single Source of Truth

All measure creation paths converge:
```
MetricTargetRow ──┐
ActionCoordinator ┤──→ MeasureCoordinator.getOrCreate()
GoalCoordinator ──┤
HealthKit Import ─┘
```

No duplicate logic, no inconsistent validation.

---

## What's Next

### Immediate (v0.7.0 - This Release)
- ✅ Measure coordinator composition implemented
- ✅ All measure creation paths consolidated
- ✅ Schema updated for CloudKit
- ✅ LLM infrastructure scaffolded
- ⏳ Semantic services prepared for integration

### Short Term (v0.7.5)
- [ ] LLM tool integration (CreateGoalTool, GetGoalsTool)
- [ ] Embedding backfill for existing entities
- [ ] Semantic deduplication for measure catalog
- [ ] Semantic search for goal discovery

### Medium Term (v0.8.0+)
- [ ] Dashboard analytics (using aggregated measures)
- [ ] HealthKit live tracking fully integrated
- [ ] CSV import/export with new measure patterns
- [ ] Performance optimization for semantic search

---

## Success Criteria

✅ **All measure creation goes through getOrCreate()**
- Every measure creation is deduplicated
- No duplicate prevention logic spread across codebase
- Idempotent: same input = same ID

✅ **Atomic Consistency**
- Measures created outside transaction
- Goal/action transaction uses guaranteed IDs
- Never fails on missing measure

✅ **Clean Architecture**
- UI layer doesn't write to database
- Coordinators compose other coordinators
- Services use coordinators, not direct DB access

✅ **User Experience**
- Can create measures inline during goal/action creation
- Don't need to pre-manage measure catalog
- Catalog emerges from actual usage

---

## References

- **MeasureRefactor.md**: Detailed problem analysis and architectural reasoning
- **CLAUDE.md**: Updated with v0.7.0 pattern descriptions
- **Commits**: ed0d84b through edcc450 (8 logical commits)
- **Schema**: `swift/Sources/Database/Schemas/schema_current.sql` (updated constraints)
