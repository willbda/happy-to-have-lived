# Versioning Strategy - Happy to Have Lived

**Current Version:** 0.6.5 (Repository + ViewModel pattern complete - 2025-11-13)
**Next Release:** 0.7.0 (Testing, refinement, CSV enhancements)
**Future Release:** 0.7.5 (Semantic foundation + basic LLM integration - pre-launch)

## Version History

| Version | Date | Milestone | Notes |
|---------|------|-----------|-------|
| 0.2.0 | - | Git history begins | Python implementation starts |
| 0.2.5 | - | Flask deployment | Python Flask API deployed |
| 0.3.0 | - | Swift journey begins | Initial Swift project setup |
| 0.5.0 | 2025-10-25 | Foundation complete, rearchitecture needed | SQLiteData working, protocols defined, but needs structural rethink |
| 0.6.0 | 2025-11-08 | Coordinator pattern complete | Phases 1-3 done: 3NF schema, models migrated, all 4 coordinators with full CRUD |
| **0.6.5** | **2025-11-13** | **Repository + ViewModel complete** | All 4 entities migrated to @Observable pattern, repositories with Sendable, query wrappers eliminated |
| **0.7.0** | **TBD** | **Testing + refinement** | Manual/automated testing, CSV enhancements, performance optimizations, bug fixes, **schema cleanup** ([#17](https://github.com/willbda/happy-to-have-lived/issues/17)) |
| **0.7.5** | **TBD** | **Semantic foundation + basic LLM** | Unified semantic layer for deduplication/search/LLM, conversational goal setting |

## Current Implementation Focus

**Active:** Swift (iOS 26+ / macOS 26+)
**On Hold:** Python backend

The two implementations have diverged significantly and **no longer share a database**.

## Swift Milestones (v0.5.0 Honest Assessment)

### ✅ Proven Concepts
- SQLiteData integration works (@Table, @Column decorators)
- Protocol system compiles (temporal separation: Completable/Doable)
- Basic SwiftUI views functional (can test on phone)
- Database operations confirmed working

### ⚠️ Needs Rearchitecture
- **Data structures**: Too many optionals, dictionary→array conversion pain
- **Protocol system**: 9 protocols - unclear if solving problems or adding ceremony
- **SwiftUI integration**: Struct ↔ @State conversion is awkward
- **Design language**: Minimal/immature - no visual identity defined
- **Generalization**: Goal/Milestone separation might be over-engineered

### ❌ Not Started (Critical for 1.0)
- Design language definition (visual identity, component library)
- Accessibility (VoiceOver labels) - **CRITICAL**
- Dynamic Type support (migrate from custom zoom)
- Platform integrations (AppIntents, EventKit)
- Test suite (broken after database migration)

## Path to 1.0 (Revised - 7-Phase Rearchitecture + Semantic Layer)

**Based on**: [swift/docs/REARCHITECTURE_COMPLETE_GUIDE.md](swift/docs/REARCHITECTURE_COMPLETE_GUIDE.md)

```
0.5.0 - Phases 1-2 complete: Schema & Models ✅
0.6.0 - Phase 3: Coordinator pattern complete ✅ (current)
0.7.0 - Phase 4: Validation + Repository layer complete
0.7.5 - SEMANTIC FOUNDATION + BASIC LLM (pre-launch enhancement) 🆕
0.8.0 - Phases 5-6: ViewModels + Views (UI fully functional)
0.9.0 - Phase 7: Testing & Migration complete + Advanced semantic features
1.0.0 - First stable release (Swift only)
```

**Phase Timeline**:
- ✅ Phase 1-2 (Schema & Models): 2 weeks (complete)
- ✅ Phase 3 (Coordinators): 1 week (complete)
- ✅ Phase 4 (Validation + Repositories): 3-4 weeks (complete 2025-11-13)
- ✅ Phase 5 (ViewModels): 1 week (complete 2025-11-13)
- ⏳ **v0.7.0 (Testing + Performance)**: 1-2 weeks (see Performance Optimizations below)
- **🆕 v0.7.5 (Semantic Foundation)**: 24-28 hours (parallel to testing)
- Phase 6 (Views): 1 week
- Phase 7 (Testing/Migration): 1-2 weeks

**Estimated Time to 1.0**: 4-6 weeks from v0.6.5

### v0.7.5 Semantic Foundation Details

**Goal:** Build unified semantic infrastructure that serves deduplication, search, and LLM integration

**Deliverables:**
1. **SemanticService** - NLEmbedding wrapper for sentence embeddings + cosine similarity
2. **EmbeddingCache** - Database storage for semantic embeddings (semanticEmbeddings table)
3. **Enhanced DuplicationDetector** - Hybrid LSH + semantic similarity (catches paraphrases)
4. **Basic LLM Integration** - 3 tools (GetGoals, GetValues, CreateGoal) + conversational UI
5. **Database Schema** - semantic_llm_schema.sql (embeddings + conversation persistence)

**Architecture Decision:** Single semantic layer serves all use cases
- ✅ Deduplication: Hybrid scoring (60% semantic, 40% syntactic/LSH)
- ✅ Search: Semantic similarity queries (future - Phase 2)
- ✅ LLM Tools: RAG via RetrieveMemoryTool (future - Phase 2)

**Integration Points:**
- Uses existing Coordinators (GoalCoordinator, etc.) for validated writes
- Uses existing FetchKeyRequest patterns for database queries
- No new write paths, minimal risk to existing functionality

**Why v0.7.5 (not v0.8.0)?**
- Pre-launch enhancement, not part of core rearchitecture phases
- Can develop in parallel with Phase 4 (Validation + Repositories)
- Sets foundation for post-launch semantic features (v0.9+)

**Future Semantic Phases:**
- v0.8-0.9: Semantic search, RAG memory retrieval, conversation persistence
- v1.0+: Values alignment coach, reflection prompts, advanced LLM features

### v0.7.0 Performance Optimizations

**Goal:** Fix inefficient looping patterns identified in import/CSV paths

**Identified Issues (2025-11-15 Performance Audit):**

1. **HealthKit Import Batch Processing** (HIGH priority)
   - **Issue**: Sequential database writes in `importWorkouts()` loop
   - **Impact**: 5-10x slower for batch imports (100 workouts = 100 transactions)
   - **Fix**: Wrap all imports in single `database.write { }` transaction
   - **File**: `HealthKitImportService.swift:126-135`
   - **Estimated time**: 1-2 hours

2. **HealthKit Measure Lookup** (HIGH priority)
   - **Issue**: `findOrCreateMeasure()` fetches ALL measures for single lookup
   - **Impact**: O(n) table scan × 3 per workout (15,000 unnecessary reads for 100 workouts)
   - **Fix**: Replace `fetchAll()` with indexed WHERE query
   - **Schema change**: Add `CREATE INDEX idx_measures_unit_type ON measures(unit, measureType)`
   - **File**: `HealthKitImportService.swift:148`
   - **Estimated time**: 1 hour

3. **CSV Import Value Lookup** (MEDIUM priority)
   - **Issue**: `lookupValueByTitle()` linear search in Swift instead of SQL query
   - **Impact**: O(n×m) - 20,000 comparisons for 100 goals with 100 values
   - **Fix**: Use SQL `LOWER()` for case-insensitive indexed lookup
   - **Schema change**: Add `CREATE INDEX idx_personal_values_title_lower ON personalValues(LOWER(title))`
   - **File**: `GoalMapper.swift:277-290`
   - **Estimated time**: 1 hour

**Database Schema Changes:**
```sql
-- Add to schema_current.sql PERFORMANCE INDEXES section
CREATE INDEX idx_measures_unit_type ON measures(unit, measureType);
CREATE INDEX idx_personal_values_title_lower ON personalValues(LOWER(title));
```

**Testing Strategy:**
- [ ] Test HealthKit import with 100+ workouts (measure time before/after)
- [ ] Test CSV import with 50+ goals (measure time before/after)
- [ ] Verify index usage with SQLite EXPLAIN QUERY PLAN
- [ ] Ensure no regression in core data flow (repositories already optimized)

**Deliverables:**
1. ✅ Optimized HealthKit batch import (single transaction)
2. ✅ Indexed measure lookups (no table scans)
3. ✅ Indexed value title lookups (SQL vs Swift)
4. ✅ Updated schema with performance indexes
5. ✅ Performance benchmarks documented

**Total Effort:** 3-4 hours

**Why v0.7.0 (not v0.6.6)?**
- Core architecture (repositories, ViewModels) already optimized in v0.6.5
- Import/CSV paths are auxiliary features, not critical path
- Schema changes (new indexes) justify minor version bump
- Fits naturally with "testing + refinement" phase

**Note:** Core data flow (repositories with JSON aggregation) already excellent - these fixes target import workflows only.

### v0.7.0 Schema Cleanup

**Goal:** Finalize schema design before v1.0.0 public launch

**Identified Issue:**
- `actionGoalContributions` table has unused fields (`contributionAmount`, `measureId`)
- 193 records in production database, **all have NULL values** for these fields
- Auto-matching pattern (JOIN on measure type) handles multi-goal scenarios elegantly
- No proven use case for fine-grained contribution splitting in 200+ real-world actions

**Proposed Solution:**
Remove unused fields to simplify schema (see [Issue #17](https://github.com/willbda/happy-to-have-lived/issues/17))

**Rationale:**
1. Current auto-match pattern is more robust than per-contribution overrides
2. Measure transformation is semantic (record multiple measures), not structural
3. YAGNI principle - don't build for hypothetical needs
4. Can re-add fields later if genuine use case emerges (backwards compatible)

**Impact:**
- Schema migration (DROP COLUMN)
- Update Swift model (remove properties)
- Simplify coordinator initialization
- No data loss (fields already NULL)

**Timeline:** 1-2 hours

**Decision Deadline:** Before v1.0.0 (schema changes post-launch become migration burden)

- First stable release
- **Criteria for 1.0:**
  - ✅ All tests passing
  - ✅ Accessibility complete (VoiceOver support)
  - ✅ Documentation up-to-date
  - ✅ At least one platform integration (AppIntents OR EventKit)
  - ✅ App Store ready

### When to bump MAJOR (1.0.0 → 2.0.0)
- Breaking changes (database schema changes)
- Major architectural rewrites
- Removing deprecated features

## Single Source of Truth

**File:** `version.txt` (project root)
**Content:** Plain text version number (e.g., `0.8.0`)

**Python reads from:** `python/version.py` → reads `../version.txt`
**Swift reads from:** `swift/Sources/App/Version.swift` → reads version.txt

## Bump Version Script

```bash
#!/bin/bash
# Usage: ./bump_version.sh 0.8.1 "Fix test suite after SQLiteData migration"

NEW_VERSION=$1
MESSAGE=$2

if [ -z "$NEW_VERSION" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: ./bump_version.sh <version> <message>"
    echo "Example: ./bump_version.sh 0.8.1 'Fix test suite'"
    exit 1
fi

# Update version.txt
echo "$NEW_VERSION" > version.txt

# Git commit and tag
git add version.txt
git commit -m "chore: Bump version to $NEW_VERSION

$MESSAGE"
git tag -a "v$NEW_VERSION" -m "v$NEW_VERSION - $MESSAGE"

echo "✓ Version bumped to $NEW_VERSION"
echo "Run 'git push && git push --tags' to publish"
```

## Current Status Summary (Updated 2025-11-13)

**Swift Implementation:** Phases 1-5 complete (v0.6.5)
- ✅ Phase 1: 3NF schema designed and tested
- ✅ Phase 2: Swift models migrated to SQLiteData
- ✅ Phase 3: Coordinator pattern complete (ActionCoordinator, GoalCoordinator, PersonalValueCoordinator, TimePeriodCoordinator)
- ✅ Phase 4: Validation + Repository layer (complete 2025-11-13)
  - ✅ Validation rules framework (ValidationRules.swift, ValidationUtilities.swift, ValidationError.swift)
  - ✅ All 4 repositories complete (Goal, Action, PersonalValue, TimePeriod)
  - ✅ Repository patterns established:
    - JSON Aggregation: Goals, Actions (1:many relationships, 2-3x faster)
    - #sql Macro: PersonalValues (simple entities)
    - Query Builder: Terms (simple 1:1 JOINs)
  - ✅ All repositories have Sendable conformance (Swift 6 compliant)
  - ✅ GoalCoordinator validation integration (two-phase: validateFormData → validateComplete)
- ✅ Phase 5: ViewModels refactor (complete 2025-11-13)
  - ✅ All 4 list ViewModels created (Goals, Actions, PersonalValues, Terms)
  - ✅ @Observable pattern throughout (no ObservableObject)
  - ✅ All views use @State (not @StateObject)
  - ✅ All query wrappers eliminated (Queries/ directory empty)
  - Reference: `swift/docs/JSON_AGGREGATION_MIGRATION_PLAN.md`
- ⏳ Phase 6: Views refinement & testing
- ⏳ Phase 7: Testing & Migration
- ❌ Design language: Liquid Glass foundation in place, refinement ongoing
- ❌ Accessibility: Not started (target: before 1.0)

**Python Implementation:** Archived
- Last stable: 0.2.5 (Flask deployment) - Tagged as v1.0-python
- No longer actively developed

**Breaking Changes**: Intentional during rearchitecture
- MatchingService, GoalFormView, ActionsViewModel, GoalsViewModel
- Will be fixed in Phases 3-6
