# Backward Compatibility Retirement Plan

**Created**: 2025-11-16
**Updated**: 2025-11-16 (Phase 1 Complete)
**Status**: Phase 2 In Progress
**Target**: v0.8.0 (after v0.7.0 testing phase)

## Overview

The canonical DataType refactoring introduced backward compatibility extensions (`.asValue`, `.asDetails`, `.asWithPeriod`) to enable incremental migration. This document tracks their usage and defines the safe retirement path.

## Current Dependencies

### 1. PersonalValue Ecosystem

**Backward Compatibility Method**: `PersonalValueData.asValue`

| Component | Location | Usage | Reason |
|-----------|----------|-------|--------|
| PersonalValuesRowView | `Views/RowViews/` | `let value: PersonalValue` | Display component expects entity |
| PersonalValu esFormView | `Views/FormViews/` | `let valueToEdit: PersonalValue?` | Form component expects entity |
| PersonalValuesListViewModel | `ViewModels/` | `valueData.asValue` → coordinator | Coordinator expects entity for delete |
| PersonalValuesListView | `Views/ListViews/` | Transform for row/form | Passes to child components |

**Retirement Blockers**:
- [x] PersonalValuesRowView signature (`PersonalValue` → `PersonalValueData`) ✅ Phase 1
- [x] PersonalValuesFormView signature (`PersonalValue?` → `PersonalValueData?`) ✅ Phase 1
- [ ] PersonalValueCoordinator.delete() signature (`PersonalValue` → `PersonalValueData`)

**Dependencies**: ~~2 views~~ + 1 coordinator = **1 component** remaining

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
- [x] GoalRowView signature (`GoalWithDetails` → `GoalData`) ✅ Phase 1
- [x] GoalFormView signature (`GoalWithDetails?` → `GoalData?`) ✅ Phase 1
- [ ] GoalCoordinator.delete() signature (`GoalWithDetails` → `GoalData`)
- [ ] LLM tool response types (3 tools)

**Dependencies**: ~~2 views~~ + 1 coordinator + 3 LLM tools = **4 components** remaining

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
- [x] ActionRowView signature (`ActionWithDetails` → `ActionData`) ✅ Phase 1
- [x] ActionFormView signature (`ActionWithDetails?` → `ActionData?`) ✅ Phase 1
- [ ] ActionCoordinator.delete() signature (`ActionWithDetails` → `ActionData`)

**Dependencies**: ~~2 views~~ + 1 coordinator = **1 component** remaining

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
- [x] TermRowView signature (separate entities → `TimePeriodData`) ✅ Phase 1
- [x] TermFormView signature (tuple → `TimePeriodData?`) ✅ Phase 1
- [ ] TimePeriodCoordinator.delete() signature (separate entities → `TimePeriodData`)

**Dependencies**: ~~2 views~~ + 1 coordinator = **1 component** remaining

---

## Retirement Strategy

### Phase 1: Update Child Components (Views) ✅ COMPLETE
**Target**: v0.7.5
**Status**: ✅ Complete (2025-11-16)
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
1. ✅ Update 4 RowView signatures (Goals, Actions, Terms, Values)
2. ✅ Update 4 FormView signatures (Goals, Actions, Terms, Values)
3. ✅ Update view internals to work with canonical types
4. ✅ Update 4 ListViews to remove .asDetails/.asValue/.asWithPeriod transformations

**Completed**: All 8 views + 4 list views now accept canonical types directly

**Actual Effort**: ~2 hours

---

### Phase 2: Update Coordinators 🔄 IN PROGRESS
**Target**: v0.7.5
**Status**: 🔄 In Progress
**Risk**: Medium (affects write operations)
**Strategy**: Replace signatures + keep deprecated legacy methods as safety net

Update coordinator delete methods to accept canonical types:

```swift
// BEFORE
public func delete(value: PersonalValue) async throws

// AFTER (with safety net)
public func delete(_ valueData: PersonalValueData) async throws {
    try await database.write { db in
        try PersonalValue.deleteOne(db, id: valueData.id)
    }
}

@available(*, deprecated, message: "Use delete(_:PersonalValueData) instead")
public func deleteLegacy(value: PersonalValue) async throws {
    // Keep old implementation temporarily
}
```

**Simplified Implementation** (thanks to ON DELETE CASCADE):
- **GoalCoordinator**: Delete Goal + Expectation (2 calls, cascades handle rest)
- **ActionCoordinator**: Delete Action (1 call, cascades handle rest)
- **PersonalValueCoordinator**: Delete PersonalValue (1 call, cascades handle rest)
- **TimePeriodCoordinator**: Delete GoalTerm + TimePeriod (2 calls, cascades handle rest)

**Tasks**:
1. [ ] Verify current delete usage with grep
2. [ ] Update GoalCoordinator.delete() → delete(_ goalData: GoalData)
3. [ ] Update ActionCoordinator.delete() → delete(_ actionData: ActionData)
4. [ ] Update PersonalValueCoordinator.delete() → delete(_ valueData: PersonalValueData)
5. [ ] Update TimePeriodCoordinator.delete() → delete(_ timePeriodData: TimePeriodData)
6. [ ] Update ViewModel delete calls (4 ViewModels)
7. [ ] Test delete operations thoroughly

**Estimated Effort**: 55-80 minutes (revised down from 2-3 hours due to cascade deletes)

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
**Status**: Pending Phase 2 & 3 completion
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
# Should return NO results (except extension definitions themselves)
grep -r "\.asValue\|\.asDetails\|\.asWithPeriod" --include="*.swift" Sources/ | \
  grep -v "extension.*{" | \
  grep -v "public var as"
```

**Tasks**:
1. [ ] Run safety check grep command
2. [ ] Remove deprecated deleteLegacy() methods from 4 coordinators
3. [ ] Remove .asValue extension from PersonalValueData.swift
4. [ ] Remove .asDetails extension from GoalData.swift
5. [ ] Remove .asDetails extension from ActionData.swift
6. [ ] Remove .asWithPeriod extension from TimePeriodData.swift
7. [ ] Update QuickAddSection to accept [ActionData] (bonus)
8. [ ] Final verification: grep reports 0 usages

**Estimated Effort**: 30-45 minutes

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

### Current Status (v0.6.5 → v0.7.5)

**Before Phase 1** (v0.6.5):
```
Total usages: 29
├─ Views (RowViews + FormViews): 8 usages
├─ ViewModels (delete transformations): 4 usages
├─ ListView (display transformations): 8 usages
├─ LLM Tools (GoalWithDetails transformations): 3 usages
└─ Documentation/comments: 6 usages
```

**After Phase 1 Complete** (v0.7.5 - 2025-11-16):
```
Total usages: ~13 (estimated)
├─ Views (RowViews + FormViews): 0 usages ✅
├─ ViewModels (delete transformations): 4 usages 🔄 Phase 2 target
├─ ListView (display transformations): 0 usages ✅
├─ LLM Tools (GoalWithDetails transformations): 3 usages ⏳ Phase 3 target
└─ Extension definitions: 4 usages (will be removed in Phase 4)
└─ Documentation/comments: ~2 usages
```

---

## Success Criteria

The backward compatibility extensions can be safely removed when:

1. ✅ All RowViews accept canonical types (4/4) - **COMPLETE Phase 1**
2. ✅ All FormViews accept canonical types (4/4) - **COMPLETE Phase 1**
3. ⏳ All Coordinators accept canonical types (4/4) - **Phase 2 in progress**
4. ⏳ All LLM Tools work with canonical types (3/3) - **Phase 3 pending**
5. ⏳ `check_backward_compat_usage.sh` reports 0 usages - **Phase 4 verification**
6. ⏳ All tests pass with updated signatures - **Phase 4 verification**
7. ⏳ Manual testing confirms no regressions - **Phase 4 verification**

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

| Phase | Version | Duration | Status | Risk |
|-------|---------|----------|--------|------|
| Phase 1: Update Views | v0.7.5 | ~~4-6 hours~~ **2 hours** | ✅ Complete | Low |
| Phase 2: Update Coordinators | v0.7.5 | ~~2-3 hours~~ **55-80 min** | 🔄 In Progress | Medium |
| Phase 3: Update LLM Tools | v0.8.0 | 2-3 hours | ⏳ Pending | Low |
| Phase 4: Remove Extensions | v0.8.0 | 30-45 min | ⏳ Pending | Low |
| **Total** | | ~~**9-12 hours**~~ **6-7 hours** | | |

**Recommendation**: Execute Phases 1-2 together in v0.7.5 (3-4 hours total), then Phases 3-4 in v0.8.0 after thorough testing (2.5-3.5 hours).

**Progress**: Phase 1 complete (2025-11-16), Phase 2 in progress.

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