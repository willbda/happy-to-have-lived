# Vertical Slice Impact Analysis
## Refactoring ActionWithDetails → ActionData

**Date**: 2025-11-15
**Purpose**: Document the cascade of changes if we adopt the single canonical data type pattern (ActionData) instead of multiple wrapper types (ActionQueryRow, ActionWithDetails, ActionExport).

---

## Current Architecture (Before Refactor)

### Data Flow

```
Database → ActionQueryRow → [ActionWithDetails | ActionExport]
                                     ↓                    ↓
                              ViewModels/Views       Export/CSV
```

### Type Proliferation

1. **ActionQueryRow** (ActionRepository.swift:437)
   - Raw SQL result with JSON strings
   - `Codable`, `FetchableRecord`, `Sendable`
   - Internal to repository

2. **ActionWithDetails** (Models/WrapperTypes/ActionWithDetails.swift)
   - Nested entity structure for SwiftUI
   - `Identifiable`, `Hashable`, `Sendable` (NOT `Codable`)
   - Used by: ViewModels, Views

3. **ActionExport** (ActionRepository.swift:51)
   - Flat structure for CSV/JSON export
   - `Codable`, `Sendable`
   - Used by: Export services

### Assembly Functions

- `assembleActionWithDetails()` (ActionRepository.swift:489) - 94 lines
- `assembleActionExport()` (ActionRepository.swift:595) - 48 lines
- **Total duplication**: ~140 lines of similar parsing logic

---

## Proposed Architecture (After Refactor)

### Data Flow

```
Database → ActionQueryRow → ActionData
                                  ↓
                    [Direct use | .asDetails transformation]
                           ↓                      ↓
                    Export/CSV              ViewModels/Views
```

### Single Canonical Type

**ActionData** (ActionRepositoryUpdated.swift:50)
- Flat structure with nested `Measurement` and `Contribution`
- `Codable`, `Sendable`, `Identifiable`, `Hashable`
- Extension provides `.asDetails` for views that need it

### Assembly Functions

- `assembleActionData()` - Single function (~60 lines)
- **Reduction**: ~80 lines eliminated

---

## Impact on Vertical Slice

### Layer 1: Repository

#### Current (ActionRepository.swift)

```swift
// Two fetch methods
func fetchAll() async throws -> [ActionWithDetails]
func fetchForExport() async throws -> [ActionExport]

// Two assembly functions
func assembleActionWithDetails(from row: ActionQueryRow) -> ActionWithDetails
func assembleActionExport(from row: ActionQueryRow) -> ActionExport
```

#### Proposed (ActionRepositoryUpdated.swift)

```swift
// One fetch method
func fetchAll() async throws -> [ActionData]

// One assembly function
func assembleActionData(from row: ActionQueryRow) -> ActionData
```

**Changes Required**:
- ✅ Already implemented in ActionRepositoryUpdated.swift.disabled
- Remove `fetchForExport()` method
- Remove `assembleActionWithDetails()` and `assembleActionExport()`
- Keep only `assembleActionData()`

---

### Layer 2: ViewModel

#### Current (ActionsListViewModel.swift:60)

```swift
@Observable
@MainActor
public final class ActionsListViewModel {
    var actions: [ActionWithDetails] = []  // ← Uses ActionWithDetails

    public func loadActions() async {
        actions = try await actionRepository.fetchAll()  // ← Returns [ActionWithDetails]
    }

    public func deleteAction(_ actionDetails: ActionWithDetails) async {
        // Extract nested entities for coordinator
        try await coordinator.delete(
            action: actionDetails.action,
            measurements: actionDetails.measurements.map(\.measuredAction),
            contributions: actionDetails.contributions.map(\.contribution)
        )
    }
}
```

#### Proposed

```swift
@Observable
@MainActor
public final class ActionsListViewModel {
    var actions: [ActionData] = []  // ← Uses ActionData directly

    public func loadActions() async {
        actions = try await actionRepository.fetchAll()  // ← Returns [ActionData]
    }

    public func deleteAction(_ actionData: ActionData) async {
        // Pass ActionData directly to coordinator
        try await coordinator.delete(actionData: actionData)
    }
}
```

**Changes Required**:
1. Change `actions` property type from `[ActionWithDetails]` to `[ActionData]`
2. Update `deleteAction()` parameter type
3. **Optional**: Keep transformation helper if views need it:
   ```swift
   var actionsAsDetails: [ActionWithDetails] {
       actions.map { $0.asDetails }
   }
   ```

**Impact**: LOW - Simple type swap, no logic changes

---

### Layer 3: View (List)

#### Current (ActionsListView.swift:34-36)

```swift
@State private var actionToEdit: ActionWithDetails?
@State private var actionToDelete: ActionWithDetails?
@State private var selectedAction: ActionWithDetails?
@State private var formData: ActionFormData?
```

#### Proposed (Option A: Direct usage)

```swift
@State private var actionToEdit: ActionData?
@State private var actionToDelete: ActionData?
@State private var selectedAction: ActionData?
@State private var formData: ActionFormData?
```

#### Proposed (Option B: Transform when needed)

```swift
// Same as current - views can transform in-place
@State private var actionToEdit: ActionWithDetails?

// Transform when setting
selectedAction = viewModel.actions.first?.asDetails
```

**Changes Required**:
- **Option A**: Change state variable types (simpler, more direct)
- **Option B**: Keep types, transform on access (less invasive)

**Impact**: LOW - State variable type changes only

---

### Layer 4: View (Row)

#### Current (ActionRowView.swift:30)

```swift
public struct ActionRowView: View {
    let actionDetails: ActionWithDetails  // ← Nested structure

    public var body: some View {
        VStack {
            Text(actionDetails.action.title ?? "Untitled")  // ← Nested access

            ForEach(actionDetails.measurements) { measurement in  // ← Nested entities
                Text("\(measurement.measure.title ?? ""): \(measurement.measuredAction.value)")
            }

            if !actionDetails.contributions.isEmpty {  // ← Nested array
                Text("\(actionDetails.contributions.count) goals")
            }
        }
    }
}
```

#### Proposed (Option A: Direct usage - flat access)

```swift
public struct ActionRowView: View {
    let action: ActionData  // ← Flat structure

    public var body: some View {
        VStack {
            Text(action.title ?? "Untitled")  // ← Direct access

            ForEach(action.measurements) { measurement in  // ← Flat structs
                Text("\(measurement.measureTitle ?? ""): \(measurement.value)")
            }

            if !action.contributions.isEmpty {  // ← Flat array
                Text("\(action.contributions.count) goals")
            }
        }
    }
}
```

**Key Differences**:
- `actionDetails.action.title` → `action.title` (one level less nesting)
- `measurement.measure.title` → `measurement.measureTitle` (flattened)
- `measurement.measuredAction.value` → `measurement.value` (flattened)

#### Proposed (Option B: Transform at boundary)

```swift
public struct ActionRowView: View {
    let actionDetails: ActionWithDetails  // ← Keep current interface

    init(action: ActionData) {
        self.actionDetails = action.asDetails  // ← Transform at init
    }

    // Body stays the same (no changes to SwiftUI code)
}
```

**Changes Required**:
- **Option A**: Update all property access paths (simpler data model, more view changes)
- **Option B**: Add transformation init (no view code changes, keeps nesting)

**Impact**: MEDIUM - Choice depends on whether we want views to know about nesting

---

### Layer 5: Coordinator

#### Current (ActionCoordinator delete method - hypothetical)

```swift
public func delete(
    action: Action,
    measurements: [MeasuredAction],
    contributions: [ActionGoalContribution]
) async throws {
    try await database.write { db in
        for measurement in measurements {
            try measurement.delete(db)
        }
        for contribution in contributions {
            try contribution.delete(db)
        }
        try action.delete(db)
    }
}
```

#### Proposed (Option A: Accept ActionData)

```swift
public func delete(actionData: ActionData) async throws {
    try await database.write { db in
        // Transform ActionData → database entities
        for measurement in actionData.measurements {
            try MeasuredAction.find(measurement.id)?.delete(db)
        }
        for contribution in actionData.contributions {
            try ActionGoalContribution.find(contribution.id)?.delete(db)
        }
        try Action.find(actionData.id)?.delete(db)
    }
}
```

#### Proposed (Option B: Keep current interface, transform at call site)

```swift
// Coordinator stays the same

// ViewModel transforms when calling
let details = actionData.asDetails
try await coordinator.delete(
    action: details.action,
    measurements: details.measurements.map(\.measuredAction),
    contributions: details.contributions.map(\.contribution)
)
```

**Changes Required**:
- **Option A**: Coordinator accepts ActionData (coordinator knows about flat structure)
- **Option B**: Keep current coordinator (ViewModel handles transformation)

**Impact**: LOW - Either way works, Option A is cleaner

---

### Layer 6: Export

#### Current (DataExporter.swift:69-71)

```swift
case .actions:
    let repository = ActionRepository(database: database)
    let exports = try await repository.fetchForExport(from: startDate, to: endDate)
    return try formatData(exports, format: format, csvFormatter: csvFormatter.formatActions)
```

#### Proposed

```swift
case .actions:
    let repository = ActionRepository(database: database)
    let actions = try await repository.fetchAll(from: startDate, to: endDate)
    return try formatData(actions, format: format, csvFormatter: csvFormatter.formatActions)
```

**Changes Required**:
1. Change `fetchForExport()` → `fetchAll()` (same data, different name)
2. Update CSVFormatter to accept `[ActionData]` instead of `[ActionExport]`

#### CSV Formatter Changes

**Current** (CSVFormatter.swift:35):
```swift
public func formatActions(_ actions: [ActionExport]) throws -> Data {
    for action in actions {
        let goalsString = action.contributingGoalIds  // Array of UUIDs
            .map { $0.uuidString }
            .joined(separator: ";")
    }
}
```

**Proposed**:
```swift
public func formatActions(_ actions: [ActionData]) throws -> Data {
    for action in actions {
        let goalsString = action.contributingGoalIds  // Computed property
            .map { $0.uuidString }
            .joined(separator: ";")
    }
}
```

**Changes Required**:
- Change parameter type from `[ActionExport]` to `[ActionData]`
- Access remains the same (ActionData has `.contributingGoalIds` computed property)

**Impact**: MINIMAL - Type change only, property access stays the same

---

## Migration Strategy

### Phase 1: Add ActionData alongside existing types

1. ✅ Create ActionData in Models package
2. ✅ Add `.asDetails` extension
3. ✅ Keep ActionWithDetails for now (compatibility)

### Phase 2: Update Repository (low-risk)

1. Change `fetchAll()` to return `[ActionData]`
2. Add `fetchAllAsDetails()` convenience method (calls `fetchAll().map { $0.asDetails }`)
3. Update `fetchForExport()` → `fetchAll()` (same query, different return type)
4. Remove duplicate assembly functions

### Phase 3: Update ViewModels (medium-risk)

1. Update ActionsListViewModel to use `[ActionData]`
2. Add computed property `var actionsAsDetails` if views need it
3. Update delete methods to accept ActionData

### Phase 4: Update Views (choose strategy)

**Option A** (cleaner long-term):
- Update all views to use ActionData directly
- Simplify property access paths (remove nesting)

**Option B** (less invasive):
- Keep views using ActionWithDetails
- Transform at boundary (init or pass-through)

### Phase 5: Update Export

1. Change DataExporter to use `fetchAll()` instead of `fetchForExport()`
2. Update CSVFormatter parameter types
3. Remove ActionExport type

### Phase 6: Cleanup

1. Deprecate ActionWithDetails (if Option A chosen)
2. Remove assembleActionWithDetails() and assembleActionExport()
3. Remove ActionExport type
4. Update documentation

---

## Comparison: Current vs Proposed

| Aspect | Current | Proposed | Change |
|--------|---------|----------|--------|
| **Repository types** | 3 (Row, Details, Export) | 1 (Data) | -67% |
| **Assembly functions** | 2 (~140 LOC) | 1 (~60 LOC) | -57% |
| **ViewModel complexity** | Type-specific fetches | Single fetch | Simpler |
| **View access patterns** | Nested (`action.action.title`) | Flat (`action.title`) | Cleaner |
| **Export complexity** | Separate type + method | Same type as display | Unified |
| **Codable support** | Export only | All data | More flexible |
| **Learning curve** | Multiple types to understand | One canonical type | Easier |

---

## Decision Points

### 1. Should views use ActionData directly or transform?

**Option A: Direct usage**
- ✅ Simpler data model (flat access)
- ✅ Less object creation overhead
- ❌ More view code changes

**Option B: Transform at boundary**
- ✅ Minimal view changes
- ❌ Extra transformation step
- ❌ Maintains nesting complexity

**Recommendation**: Start with Option B for safety, migrate to Option A over time.

### 2. Should coordinators accept ActionData or decomposed entities?

**Option A: Accept ActionData**
- ✅ Single parameter (cleaner API)
- ✅ Coordinator knows about canonical type

**Option B: Keep current interface**
- ✅ No coordinator changes
- ❌ ViewModel does transformation

**Recommendation**: Option A - coordinators should accept the canonical type.

### 3. Migration: Big bang or gradual?

**Big Bang**:
- Change everything at once
- ✅ Clean cut, no dual code paths
- ❌ High risk, large PR

**Gradual**:
- Add ActionData, keep ActionWithDetails
- Provide both `fetchAll()` and `fetchAllAsDetails()`
- Migrate views one by one
- ✅ Low risk, incremental
- ❌ Temporary code duplication

**Recommendation**: Gradual - add ActionData alongside, migrate incrementally.

---

## Estimated Impact

| Layer | Files Affected | LOC Changed | Risk Level |
|-------|----------------|-------------|------------|
| Repository | 1 (ActionRepository) | ~150 | LOW |
| ViewModel | 1 (ActionsListViewModel) | ~20 | LOW |
| Views (List) | 1 (ActionsListView) | ~10 | LOW |
| Views (Row) | 1 (ActionRowView) | ~30 | MEDIUM |
| Coordinator | 1 (ActionCoordinator) | ~15 | LOW |
| Export | 2 (DataExporter, CSVFormatter) | ~10 | LOW |
| **TOTAL** | **7 files** | **~235 LOC** | **LOW-MEDIUM** |

---

## Testing Strategy

### Unit Tests (Repository)

```swift
func testFetchAll_ReturnsActionData() async throws {
    let actions = try await repository.fetchAll()

    XCTAssertEqual(actions.count, 3)
    XCTAssertTrue(actions.allSatisfy { $0 is ActionData })

    // Verify Codable
    let encoded = try JSONEncoder().encode(actions)
    let decoded = try JSONDecoder().decode([ActionData].self, from: encoded)
    XCTAssertEqual(decoded.count, actions.count)
}

func testActionData_AsDetails_PreservesData() throws {
    let actionData = createMockActionData()
    let details = actionData.asDetails

    XCTAssertEqual(details.action.id, actionData.id)
    XCTAssertEqual(details.measurements.count, actionData.measurements.count)
    XCTAssertEqual(details.contributions.count, actionData.contributions.count)
}
```

### Integration Tests (ViewModel)

```swift
func testLoadActions_PopulatesActionData() async throws {
    let viewModel = ActionsListViewModel()
    await viewModel.loadActions()

    XCTAssertFalse(viewModel.actions.isEmpty)
    XCTAssertTrue(viewModel.actions.allSatisfy { $0 is ActionData })
}
```

### UI Tests (Views)

```swift
func testActionRowView_DisplaysActionData() throws {
    let action = createMockActionData()
    let view = ActionRowView(action: action)

    XCTAssertNotNil(view.body)
    // Snapshot testing or view hierarchy validation
}
```

---

## Rollback Plan

If issues arise during migration:

1. **Phase 2-3**: Keep `fetchAllAsDetails()` method, revert ViewModels to use it
2. **Phase 4**: Revert views to use ActionWithDetails via transformation
3. **Phase 5**: Keep separate `fetchForExport()` method
4. **Full rollback**: Restore ActionWithDetails as primary type, deprecate ActionData

**Git Strategy**: One phase per commit for easy rollback.

---

## Conclusion

The refactor from ActionWithDetails → ActionData:

✅ **Reduces code duplication** (~140 LOC → ~60 LOC in repository)
✅ **Simplifies data model** (3 types → 1 canonical type)
✅ **Unifies export** (no separate export types)
✅ **Maintains flexibility** (views can still use nested structure via `.asDetails`)
✅ **Low-medium risk** (~235 LOC changed across 7 files)

**Next Step**: Review ActionRepositoryUpdated.swift.disabled and decide on migration strategy.
