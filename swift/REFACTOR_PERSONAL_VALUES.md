# PersonalValues Canonical Type Refactoring

## Context

We're completing a canonical DataType refactoring pattern across the codebase. Three entity types are already complete (Goals, Actions, Terms). PersonalValues is the last one remaining.

**Architecture Goal**: Create ONE canonical data type per entity that serves BOTH display and export needs, eliminating duplication between display types (e.g., `PersonalValueWithDetails`) and export types (e.g., `PersonalValueExport`).

## Reference Examples (Already Completed)

Look at these three completed refactorings as templates:

### 1. **GoalData.swift** (Most Complex - Has Many Relationships)
```
swift/Sources/Models/DataTypes/GoalData.swift
```
- Flattens Goal + Expectation fields at top level
- Denormalized sub-structs: MeasureTarget, ValueAlignment, TermAssignment
- `.asDetails` extension for backward compatibility with GoalWithDetails
- `.csvRow` and `.csvHeader` for export

### 2. **TermData.swift** (Medium Complexity)
```
swift/Sources/Models/DataTypes/TermData.swift
```
- Flattens Term + TimePeriod fields
- Optional array of assigned goal IDs
- `.asWithPeriod` extension for backward compatibility
- Direct Codable for JSON/CSV export

### 3. **ActionData.swift** (Good Balance)
```
swift/Sources/Models/DataTypes/ActionData.swift
```
- Flattens Action fields at top level
- Denormalized Measurement and Contribution sub-structs
- `.asDetails` extension for backward compatibility
- Shows simpler pattern than GoalData

## What PersonalValues Needs

### Current State (Old Pattern)
```
swift/Sources/Services/Repositories/PersonalValueRepository.swift
```
- `fetchAll()` → returns `[PersonalValue]` (basic entity)
- `fetchForExport()` → returns `[PersonalValueExport]` (separate export type)
- TWO separate types for same data

### Target State (Canonical Pattern)
- Create `PersonalValueData.swift` in `swift/Sources/Models/DataTypes/`
- Update `PersonalValueRepository.fetchAll()` to return `[PersonalValueData]`
- Deprecate `fetchForExport()` (canonical type serves both needs)
- Update ViewModels/Views to use PersonalValueData

## Step-by-Step Process

### Phase 1: Create PersonalValueData Type
**File**: `swift/Sources/Models/DataTypes/PersonalValueData.swift`

**Structure** (based on current PersonalValue + PersonalValueExport):
```swift
public struct PersonalValueData: Identifiable, Hashable, Sendable, Codable {
    // Core PersonalValue fields
    public let id: UUID
    public let title: String
    public let detailedDescription: String?
    public let freeformNotes: String?
    public let priority: Int
    public let valueLevel: String  // ValueLevel enum as string for Codable
    public let lifeDomain: String?
    public let alignmentGuidance: String?
    public let logTime: Date

    // Denormalized relationship data (from goalRelevances)
    public let alignedGoalIds: [UUID]
    public let alignedGoalCount: Int  // Convenience from fetchForExport

    // Backward compatibility extension
    public var asValue: PersonalValue {
        // Reconstruct PersonalValue entity
    }

    // CSV export support
    public var csvRow: [String] { ... }
    public static var csvHeader: [String] { ... }
}
```

**Key Points**:
- Include ALL fields from PersonalValue entity
- Add `alignedGoalIds` (which goals reference this value)
- Add `alignedGoalCount` (computed count from export query)
- Implement `.asValue` for backward compatibility
- Make it Codable for direct JSON export

### Phase 2: Update PersonalValueRepository

**File**: `swift/Sources/Services/Repositories/PersonalValueRepository.swift`

**Changes**:
1. Rename existing `fetchAll()` → `fetchAllLegacy()` with deprecation
2. Create new `fetchAll()` returning `[PersonalValueData]`
3. Add date filtering to new `fetchAll(from:to:)`
4. Keep `fetchForExport()` temporarily but mark deprecated

**Example Pattern** (from GoalRepository.swift:78-107):
```swift
@available(*, deprecated, renamed: "fetchAll", message: "Use fetchAll() which returns canonical PersonalValueData")
public func fetchAllLegacy() async throws -> [PersonalValue] {
    // Old implementation
}

public func fetchAll(
    from startDate: Date? = nil,
    to endDate: Date? = nil
) async throws -> [PersonalValueData] {
    // Use existing SQL from fetchForExport but return PersonalValueData
    // Include LEFT JOIN with goalRelevances for aligned goals
}
```

### Phase 3: Update Exporter & CSVFormatter

**Files**:
- `swift/Sources/Services/ImportExport/Exporter.swift`
- `swift/Sources/Services/ImportExport/CSVFormatter.swift`

**Changes**:
1. `CSVFormatter.formatValues()` - Accept `[PersonalValueData]` instead of `[PersonalValueExport]`
2. `Exporter` - Use `repository.fetchAll()` instead of `fetchForExport()`

**Example Pattern** (from CSVFormatter.swift:73-74):
```swift
// Before:
public func formatValues(_ values: [PersonalValueExport]) throws -> Data

// After:
public func formatValues(_ values: [PersonalValueData]) throws -> Data
```

### Phase 4: Update PersonalValuesListViewModel

**File**: `swift/Sources/App/ViewModels/PersonalValuesListViewModel.swift`

**Changes**:
1. Change `var values: [PersonalValue]` → `var values: [PersonalValueData]`
2. Update `loadValues()` to use new `fetchAll()`
3. Update `deleteValue()` to accept `PersonalValueData`

**Example Pattern** (from GoalsListViewModel.swift:58, 104):
```swift
var values: [PersonalValueData] = []  // Changed type

public func loadValues() async {
    values = try await repository.fetchAll()  // Returns PersonalValueData
}

public func deleteValue(_ valueData: PersonalValueData) async {
    let value = valueData.asValue  // Transform for coordinator
    // Delete via coordinator
}
```

### Phase 5: Update PersonalValuesListView

**File**: `swift/Sources/App/Views/ListViews/PersonalValuesListView.swift`

**Changes**:
1. Update state variables to `PersonalValueData`
2. Transform to legacy types when passing to child components (if needed)

**Example Pattern** (from GoalsListView.swift:31-32, 58-59):
```swift
@State private var valueToEdit: PersonalValueData?
@State private var valueToDelete: PersonalValueData?

ForEach(viewModel.values) { valueData in
    PersonalValueRowView(value: valueData.asValue)  // Transform if needed
        .onTapGesture {
            valueToEdit = valueData  // Store canonical type
        }
}
```

## Files to Modify (Checklist)

- [ ] **CREATE**: `swift/Sources/Models/DataTypes/PersonalValueData.swift`
- [ ] **MODIFY**: `swift/Sources/Services/Repositories/PersonalValueRepository.swift`
- [ ] **MODIFY**: `swift/Sources/Services/ImportExport/CSVFormatter.swift`
- [ ] **MODIFY**: `swift/Sources/Services/ImportExport/Exporter.swift`
- [ ] **MODIFY**: `swift/Sources/App/ViewModels/PersonalValuesListViewModel.swift`
- [ ] **MODIFY**: `swift/Sources/App/Views/ListViews/PersonalValuesListView.swift`

## Success Criteria

1. ✅ `PersonalValueData` type created with all fields + relationships
2. ✅ Repository returns `PersonalValueData` from `fetchAll()`
3. ✅ Export uses `PersonalValueData` directly (no separate export type)
4. ✅ ViewModels store `PersonalValueData`
5. ✅ Views transform at display boundary only
6. ✅ Old types deprecated with compiler warnings
7. ✅ Code compiles without errors
8. ✅ Net negative lines of code (should remove ~200-300 lines)

## Important Notes

- PersonalValue is **simpler** than Goals/Actions (fewer relationships)
- Main relationship: `goalRelevances` table (which goals align with this value)
- The existing `fetchForExport()` query already computes aligned goal count
- Just need to add `alignedGoalIds` array to complete the picture

## Testing After Refactor

```bash
# From swift/ directory
swift build 2>&1 | grep -E "PersonalValue|error:"
```

Should show:
- No compilation errors
- Deprecation warnings on old methods (expected)
- Reduced total line count

## Questions to Ask If Stuck

1. "How does GoalData handle its relationships?" (check GoalData.swift:126-149)
2. "How does the repository transformation work?" (check GoalRepository.swift:112-164)
3. "How do views handle the canonical type?" (check GoalsListView.swift:58-65)
