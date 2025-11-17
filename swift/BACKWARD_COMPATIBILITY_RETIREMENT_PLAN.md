# Backward Compatibility Retirement Plan

**Created**: 2025-11-16
**Status**: Planning
**Target**: v0.8.0 (after v0.7.0 testing phase)

## Overview

The canonical DataType refactoring introduced backward compatibility extensions (`.asValue`, `.asDetails`, `.asWithPeriod`) to enable incremental migration. This document tracks their usage and defines the safe retirement path.

## Current Dependencies

### 1. PersonalValue Ecosystem

**Backward Compatibility Method**: `PersonalValueData.asValue`

| Component | Location | Usage | Reason |
|-----------|----------|-------|--------|
| PersonalValuesRowView | `Views/RowViews/` | `let value: PersonalValue` | Display component expects entity |
| PersonalValuesFormView | `Views/FormViews/` | `let valueToEdit: PersonalValue?` | Form component expects entity |
| PersonalValuesListViewModel | `ViewModels/` | `valueData.asValue` → coordinator | Coordinator expects entity for delete |
| PersonalValuesListView | `Views/ListViews/` | Transform for row/form | Passes to child components |

**Retirement Blockers**:
- [ ] PersonalValuesRowView signature (`PersonalValue` → `PersonalValueData`)
- [ ] PersonalValuesFormView signature (`PersonalValue?` → `PersonalValueData?`)
- [ ] PersonalValueCoordinator.delete() signature (`PersonalValue` → `PersonalValueData`)

**Dependencies**: 2 views + 1 coordinator = **3 components**

---

### 2. Goal Ecosystem

**Backward Compatibility Method**: `GoalData.asDetails`

| Component | Location | Usage | Reason |
|-----------|----------|-------|--------|
| GoalRowView | `Views/RowViews/` | `let goalDetails: GoalWithDetails` | Display component expects nested structure |
| GoalFormView | `Views/FormViews/` | `let goalToEdit: GoalWithDetails?` | Form component expects nested structure |
| GoalsListViewModel | `ViewModels/` | `goalData.asDetails` → coordinator | Coordinator expects GoalWithDetails for delete |
| GoalsListView | `Views/ListViews/` | Transform for row/form | Passes to child components |
| GetGoalsTool | `FoundationModels/Tools/` | `goalDataArray.map { $0.asDetails }` | LLM tool expects GoalWithDetails |
| CreateGoalTool | `FoundationModels/Tools/` | `goalDataArray.map { $0.asDetails }` | LLM tool expects GoalWithDetails |
| CheckDuplicateGoalTool | `FoundationModels/Tools/` | `goalDataArray.map { $0.asDetails }` | LLM tool expects GoalWithDetails |

**Retirement Blockers**:
- [ ] GoalRowView signature (`GoalWithDetails` → `GoalData`)
- [ ] GoalFormView signature (`GoalWithDetails?` → `GoalData?`)
- [ ] GoalCoordinator.delete() signature (`GoalWithDetails` → `GoalData`)
- [ ] LLM tool response types (3 tools)

**Dependencies**: 2 views + 1 coordinator + 3 LLM tools = **6 components**

---

### 3. Action Ecosystem

**Backward Compatibility Method**: `ActionData.asDetails`

| Component | Location | Usage | Reason |
|-----------|----------|-------|--------|
| ActionRowView | `Views/RowViews/` | `let actionDetails: ActionWithDetails` | Display component expects nested structure |
| ActionFormView | `Views/FormViews/` | `let actionToEdit: ActionWithDetails?` | Form component expects nested structure |
| ActionsListViewModel | `ViewModels/` | `actionData.asDetails` → coordinator | Coordinator expects ActionWithDetails for delete |
| ActionsListView | `Views/ListViews/` | Transform for row/form + dashboard | Passes to child components |

**Retirement Blockers**:
- [ ] ActionRowView signature (`ActionWithDetails` → `ActionData`)
- [ ] ActionFormView signature (`ActionWithDetails?` → `ActionData?`)
- [ ] ActionCoordinator.delete() signature (`ActionWithDetails` → `ActionData`)

**Dependencies**: 2 views + 1 coordinator = **3 components**

---

### 4. Term Ecosystem

**Backward Compatibility Method**: `TimePeriodData.asWithPeriod`
**Note**: Renamed from `TermData` to `TimePeriodData` on 2025-11-16 for architectural clarity.

| Component | Location | Usage | Reason |
|-----------|----------|-------|--------|
| TermRowView | `Views/RowViews/` | `let term: GoalTerm, timePeriod: TimePeriod` | Display component expects separate entities |
| TermFormView | `Views/FormViews/` | `let termToEdit: (TimePeriod, GoalTerm)?` | Form component expects tuple |
| TermsListViewModel | `ViewModels/` | `timePeriodData.asWithPeriod` → coordinator | Coordinator expects separate entities for delete |
| TermsListView | `Views/ListViews/` | Transform for display | Passes to child components |

**Retirement Blockers**:
- [ ] TermRowView signature (separate entities → `TimePeriodData`)
- [ ] TermFormView signature (tuple → `TimePeriodData?`)
- [ ] TimePeriodCoordinator.delete() signature (separate entities → `TimePeriodData`)

**Dependencies**: 2 views + 1 coordinator = **3 components**

---

## Retirement Strategy

### Phase 1: Update Child Components (Views)
**Target**: v0.7.5
**Risk**: Low (isolated view changes)

Update row and form views to accept canonical types:

```swift
// BEFORE
public struct PersonalValuesRowView: View {
    let value: PersonalValue
}

// AFTER
public struct PersonalValuesRowView: View {
    let value: PersonalValueData
}
```

**Tasks**:
1. Update 4 RowView signatures (Goals, Actions, Terms, Values)
2. Update 4 FormView signatures (Goals, Actions, Terms, Values)
3. Update view internals to work with canonical types
4. Test all views thoroughly

**Estimated Effort**: 4-6 hours

---

### Phase 2: Update Coordinators
**Target**: v0.7.5
**Risk**: Medium (affects write operations)

Update coordinator delete methods to accept canonical types:

```swift
// BEFORE
public func delete(value: PersonalValue) async throws

// AFTER
public func delete(value: PersonalValueData) async throws
```

**Tasks**:
1. Update 4 coordinator delete signatures
2. Extract entity data from canonical types internally
3. Update all call sites in ViewModels
4. Test delete operations thoroughly

**Estimated Effort**: 2-3 hours

---

### Phase 3: Update LLM Tools (Goals Only)
**Target**: v0.8.0
**Risk**: Low (internal tool implementation)

Update Foundation Models tools to work with GoalData:

```swift
// BEFORE
let goals: [GoalWithDetails] = goalDataArray.map { $0.asDetails }

// AFTER
let goals: [GoalData] = try await repository.fetchAll()
```

**Tasks**:
1. Update GetGoalsTool to use GoalData
2. Update CreateGoalTool to use GoalData
3. Update CheckDuplicateGoalTool to use GoalData
4. Update tool response types if needed
5. Test LLM tool functionality

**Estimated Effort**: 2-3 hours

---

### Phase 4: Remove Backward Compatibility Extensions
**Target**: v0.8.0
**Risk**: Low (nothing should depend on them)

Remove the `.asValue`, `.asDetails`, `.asWithPeriod` extensions:

```swift
// DELETE from PersonalValueData.swift
public var asValue: PersonalValue { ... }

// DELETE from GoalData.swift
public var asDetails: GoalWithDetails { ... }

// DELETE from ActionData.swift
public var asDetails: ActionWithDetails { ... }

// DELETE from TimePeriodData.swift
public var asWithPeriod: TermWithPeriod { ... }
```

**Safety Checks Before Removal**:
```bash
# Should return NO results
grep -r "\.asValue\|\.asDetails\|\.asWithPeriod" --include="*.swift" Sources/
```

**Estimated Effort**: 30 minutes

---

## Detection & Monitoring

### Before Each Release

Run this check to ensure no new usage is introduced:

```bash
#!/bin/bash
# check_backward_compat_usage.sh

echo "🔍 Checking backward compatibility usage..."

# Count usages (excluding DataTypes definitions)
USAGES=$(grep -r "\.asValue\|\.asDetails\|\.asWithPeriod" \
  --include="*.swift" Sources/ | \
  grep -v "Sources/Models/DataTypes" | \
  wc -l | tr -d ' ')

echo "Found $USAGES usages of backward compatibility methods"

if [ "$USAGES" -eq 0 ]; then
  echo "✅ Safe to remove backward compatibility extensions!"
  exit 0
else
  echo "⚠️  Still have $USAGES usages - not safe to remove yet"
  echo ""
  echo "Usage breakdown:"
  grep -r "\.asValue\|\.asDetails\|\.asWithPeriod" \
    --include="*.swift" Sources/ | \
    grep -v "Sources/Models/DataTypes" | \
    cut -d: -f1 | sort | uniq -c | sort -rn
  exit 1
fi
```

### Current Status (v0.6.5)

```
Total usages: 29
├─ Views (RowViews + FormViews): 8 usages
├─ ViewModels (delete transformations): 4 usages
├─ ListView (display transformations): 8 usages
├─ LLM Tools (GoalWithDetails transformations): 3 usages
└─ Documentation/comments: 6 usages
```

---

## Success Criteria

The backward compatibility extensions can be safely removed when:

1. ✅ All RowViews accept canonical types (4/4)
2. ✅ All FormViews accept canonical types (4/4)
3. ✅ All Coordinators accept canonical types (4/4)
4. ✅ All LLM Tools work with canonical types (3/3)
5. ✅ `check_backward_compat_usage.sh` reports 0 usages
6. ✅ All tests pass with updated signatures
7. ✅ Manual testing confirms no regressions

---

## Benefits of Retirement

Once backward compatibility is removed:

1. **Simpler mental model** - Only one type per entity
2. **Reduced code surface area** - ~200 lines eliminated
3. **No transformation overhead** - Direct canonical usage
4. **Clearer architecture** - No "legacy" vs "new" confusion
5. **Faster development** - No need to support two patterns

---

## Risk Mitigation

### If Issues Are Found

1. **Rollback Plan**: Git revert to commit before extension removal
2. **Incremental Approach**: Remove one entity at a time (Values → Actions → Terms → Goals)
3. **Feature Flag**: Keep extensions but mark `@available(*, deprecated)` first
4. **Testing**: Full regression test suite before each phase

---

## Timeline

| Phase | Version | Duration | Risk |
|-------|---------|----------|------|
| Phase 1: Update Views | v0.7.5 | 4-6 hours | Low |
| Phase 2: Update Coordinators | v0.7.5 | 2-3 hours | Medium |
| Phase 3: Update LLM Tools | v0.8.0 | 2-3 hours | Low |
| Phase 4: Remove Extensions | v0.8.0 | 30 min | Low |
| **Total** | | **9-12 hours** | |

**Recommendation**: Execute Phases 1-2 together in v0.7.5, then Phases 3-4 in v0.8.0 after thorough testing.

---

## Related Documentation

- [REFACTOR_PERSONAL_VALUES.md](REFACTOR_PERSONAL_VALUES.md) - PersonalValues canonical type migration
- [JSON_AGGREGATION_MIGRATION_PLAN.md](docs/JSON_AGGREGATION_MIGRATION_PLAN.md) - Repository pattern evolution
- [VERSIONING.md](../VERSIONING.md) - Version history and planning

---

## Notes

- Backward compatibility extensions were necessary for incremental migration
- They served their purpose well - zero runtime issues during refactoring
- Removal is not urgent - extensions are low maintenance
- Primary benefit of removal is conceptual simplicity, not performance
 