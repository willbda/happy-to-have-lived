# Architecture Documentation Index

**Generated:** 2025-11-19
**Codebase Version:** 0.7.0+
**Total Files Documented:** 166 Swift source files

---

## Quick Links

### Primary Documentation

1. **[ARCHITECTURE_MAP_COMPLETE.csv](./ARCHITECTURE_MAP_COMPLETE.csv)**
   - Complete file-by-file architectural map
   - CSV format: Layer, Domain Entity, File Path, Purpose, Pattern, Dependencies, etc.
   - 167 lines (1 header + 166 files)
   - **Use for:** Finding specific files, understanding dependencies, analyzing patterns

2. **[ARCHITECTURE_SUMMARY.md](./ARCHITECTURE_SUMMARY.md)**
   - Comprehensive architectural overview
   - Layer diagrams, data flow patterns, statistics
   - Design decisions and rationale
   - **Use for:** Understanding system architecture, onboarding, architectural discussions

3. **[CLAUDE.md](./CLAUDE.md)**
   - Project-specific guidance for Claude Code
   - Coding conventions, patterns, anti-patterns
   - **Use for:** AI-assisted development, contribution guidelines

---

## CSV Query Examples

The CSV can be opened in Excel/Numbers or queried programmatically:

### Find all repositories
```bash
grep "Repository," ARCHITECTURE_MAP_COMPLETE.csv
```

### Find complex files (>400 lines)
```bash
grep ",Complex," ARCHITECTURE_MAP_COMPLETE.csv
```

### Find all @MainActor files
```bash
grep "@MainActor" ARCHITECTURE_MAP_COMPLETE.csv
```

### Count files by layer
```bash
cut -d',' -f1 ARCHITECTURE_MAP_COMPLETE.csv | sort | uniq -c
```

### Find all Goal-related files
```bash
grep "Goal" ARCHITECTURE_MAP_COMPLETE.csv
```

---

## Statistics Summary

### By Layer
- **Views:** 60 files (36%)
- **Services:** 42 files (25%)
- **Models:** 30 files (18%)
- **Coordinators:** 18 files (11%)
- **ViewModels:** 16 files (10%)
- **Repositories:** 13 files (8%)
- **Database:** 3 files (2%)

### By Complexity
- **Simple:** 91 files (55%)
- **Medium:** 57 files (34%)
- **Complex:** 18 files (11%)

### By Concurrency
- **Sendable:** 85 files (51%)
- **@MainActor:** 63 files (38%)
- **@unchecked Sendable:** 10 files (6%)
- **None:** 8 files (5%)

---

## Key Architectural Patterns

1. **Three-Layer Model** (30 files)
   - Abstraction (6): Full metadata entities
   - Basic (5): Lightweight reference entities
   - Composit (4): Junction tables
   - DataTypes (6): Canonical Codable structures
   - Semantic (4): Embedding types
   - Deduplication (2): Duplicate detection
   - HealthKit (3): Health data wrappers

2. **Repository Pattern** (13 files)
   - BaseRepository + Core (4)
   - Entity Repositories (9)
   - Three query strategies: JSON aggregation, #sql macro, query builder

3. **Coordinator Pattern** (18 files)
   - FormData structures (10)
   - Coordinators (8)
   - Multi-model atomic transactions
   - Coordinator composition (MeasureCoordinator.getOrCreate)

4. **@Observable ViewModels** (16 files)
   - Form ViewModels (6)
   - List ViewModels (6)
   - LLM ViewModels (1)
   - Utility ViewModels (3)
   - Pattern: @Observable @MainActor with lazy repository access

5. **SwiftUI Views** (60 files)
   - Form Views (6)
   - List Views (6)
   - Row Views (6)
   - Components (7)
   - Templates (7)
   - Specialized: CSV (3), Health (3), Debug (2), LLM (1), Dashboard (1), Analytics (1)

---

## Most Complex Files (18 total)

These files exceed 400 lines and contain sophisticated logic:

### Repositories (3)
- `BaseRepository.swift` - Template method pattern
- `GoalRepository.swift` - 3 JSON aggregations
- `ActionRepository.swift` - 2 JSON aggregations

### Coordinators (2)
- `GoalCoordinator.swift` - 5+ model transaction
- `ActionCoordinator.swift` - 3 model transaction

### Services (6)
- `SemanticService.swift` - NLEmbedding + caching
- `EmbeddingGenerationService.swift` - Text builders + cache
- `ProgressCalculationService.swift` - Measure aggregation
- `HealthKitManager.swift` - Multi-type queries
- `HealthKitImportService.swift` - ETL pipeline
- `GoalCoachService.swift` - LLM orchestration

### Import/Export (3)
- `DataImporter.swift` - Generic orchestrator
- `Importers.swift` - Entity-specific implementations
- `MetricTargetRow.swift` - Inline measure creation

### Views & ViewModels (4)
- `GoalFormView.swift` - Multi-section form
- `GoalFormViewModel.swift` - Complex state management
- `GoalCoachView.swift` - LLM chat UI
- `GoalCoachViewModel.swift` - Conversation + tools

---

## Search by Domain Entity

### Goal (16 files)
- Model: Goal.swift, GoalData.swift
- Repository: GoalRepository.swift
- Coordinator: GoalCoordinator.swift, GoalFormData.swift
- Validation: (in ValidationRules.swift)
- Services: SemanticGoalDetector.swift
- LLM: GoalCoachService.swift, CreateGoalTool.swift, GetGoalsTool.swift, CheckDuplicateGoalTool.swift
- ViewModels: GoalFormViewModel.swift, GoalsListViewModel.swift, GoalCoachViewModel.swift
- Views: GoalFormView.swift, GoalsListView.swift, GoalRowView.swift, GoalCoachView.swift

### Action (11 files)
- Model: Action.swift, ActionData.swift
- Repository: ActionRepository.swift
- Coordinator: ActionCoordinator.swift, ActionFormData.swift
- Validation: (in ValidationRules.swift)
- LLM: GetRecentActionsTool.swift
- ViewModels: ActionFormViewModel.swift, ActionsListViewModel.swift
- Views: ActionFormView.swift, ActionsListView.swift, ActionRowView.swift

### PersonalValue (17 files)
- Model: PersonalValue.swift, PersonalValueData.swift
- Repository: PersonalValueRepository.swift
- Coordinator: PersonalValueCoordinator.swift, PersonalValueFormData.swift, ValueAlignmentInput.swift
- Services: ValueAlignmentService.swift
- LLM: GetValuesTool.swift
- Semantic: AlignmentMatrix.swift
- ViewModels: PersonalValuesFormViewModel.swift, PersonalValuesListViewModel.swift, ValueAlignmentHeatmapViewModel.swift
- Views: PersonalValuesFormView.swift, PersonalValuesListView.swift, PersonalValuesRowView.swift, ValueAlignmentHeatmapView.swift
- Composit: GoalRelevance.swift

### Measure (12 files)
- Model: Measure.swift, MeasureData.swift
- Repository: MeasureRepository.swift
- Coordinator: MeasureCoordinator.swift, MeasureFormData.swift, ExpectationMeasureFormData.swift, MeasureDeduplicationCoordinator.swift
- LLM: GetMeasuresTool.swift
- Views: MeasurementInputRow.swift, MetricTargetRow.swift, MeasurementDisplay.swift
- Debug: MeasureDeduplicationView.swift
- Basic: ExpectationMeasure.swift

---

## Data Flow Diagrams

Refer to ARCHITECTURE_SUMMARY.md for detailed data flow patterns:

1. **Create Entity** - User Input → FormView → ViewModel → Coordinator → Database → Repository → ListView
2. **Display List** - ListView → ViewModel → Repository → Database → DataType → View
3. **Export CSV** - ExportView → Exporter → Repository → DataType → CSVFormatter → File
4. **Import CSV** - File → CSVParser → Validator → Transformer → Coordinator → Database
5. **LLM Goal Creation** - User → LLM → Tools → Coordinator → Database
6. **HealthKit Import** - HealthKit → Parser → MeasureCoordinator → ActionCoordinator → Database

---

## Development Guidelines

### Adding a New Entity Type

1. Create model in `Models/Abstractions/` or `Models/Basics/`
2. Add FormData in `Services/Coordinators/FormData/`
3. Create Coordinator in `Services/Coordinators/`
4. Create Repository in `Services/Repositories/`
5. Add Validation in `Services/Validation/`
6. Create FormViewModel and ListView in `App/ViewModels/`
7. Create FormView, ListView, RowView in `App/Views/`
8. Add to CSV export in `Services/ImportExport/`

### Concurrency Rules

- **@MainActor**: ViewModels, Views, UI-bound services
- **Sendable**: Coordinators, Repositories, Services, FormData, DataTypes
- **NO @MainActor**: Coordinators (database I/O runs in background)
- **Lazy storage**: Use `lazy var` with `@ObservationIgnored` for coordinators in ViewModels

### Validation Pattern

1. **Phase 1:** Validate FormData (business rules) BEFORE database write
2. **Phase 2:** Validate Complete (referential integrity) AFTER database write

### Error Handling

- Database errors → `ValidationError` (user-friendly messages)
- FK violations → Specific error types (invalidMeasure, invalidGoal, etc.)
- Business rule violations → Descriptive ValidationError

---

## Related Documentation

### Project Documentation
- `swift/docs/JSON_AGGREGATION_MIGRATION_PLAN.md` - Repository query patterns
- `swift/docs/CONCURRENCY_MIGRATION_20251110.md` - Swift 6 migration history
- `swift/docs/LIQUID_GLASS_VISUAL_SYSTEM.md` - UI/UX design system
- `swift/docs/20251117_MEASURE_COORDINATOR_COMPOSITION.md` - Coordinator composition pattern

### Database Schema
- `swift/Sources/Database/Schemas/schema_current.sql` - Current database schema

### Package Definition
- `swift/Package.swift` - Swift package dependencies and targets

---

## Version History

### v0.7.0+ (Current)
- ✅ Repository + ViewModel pattern (all list views)
- ✅ Coordinator composition (MeasureCoordinator.getOrCreate)
- ✅ Schema updates (UNIQUE constraints removed for CloudKit)
- ✅ Semantic services scaffolded
- ⏳ LLM tool integration (in progress)
- ⏳ Embedding backfill (planned)
- ⏳ Dashboard/Analytics (planned)

### v0.6.0
- ✅ Phase 5: Repository + ViewModel pattern
- ✅ Phase 6: Coordinator composition + Semantic services

### v0.5.0
- ✅ Phase 4: Validation layer integration
- ✅ Phase 3: Coordinator pattern implementation

### v0.4.0
- ✅ Phase 2: Model compilation
- ✅ Phase 1: Three-layer model architecture

---

## Contact

**Project Owner:** David Williams
**Development Partner:** Claude Code (Anthropic)

**For Questions:**
- Architecture questions → Review ARCHITECTURE_SUMMARY.md
- File-specific questions → Search ARCHITECTURE_MAP_COMPLETE.csv
- Development patterns → Review CLAUDE.md
- Database schema → Review schema_current.sql

---

**Last Updated:** 2025-11-19
**Documentation Coverage:** 100% (166/166 files)
