# Resource Map and Quick Reference
## Ten Week Goal App - Development Resources

**Created**: 2025-11-19
**Purpose**: Central navigation hub for all project resources, documentation, and tools

---

## Project Overview

**Happy to Have Lived (HtHL)** - Native iOS/macOS/visionOS goal tracking application
- **Current Version**: v0.6.0 (Active Development)
- **Target Release**: v1.0.0 - Winter 2025-26
- **Platforms**: iOS 26+, macOS 26+ (Tahoe), visionOS 26+
- **Tech Stack**: Swift 6.2, SwiftUI, SQLite with SQLiteData ORM

### Core Architecture
- **Three-Layer Domain Model**: Abstraction → Basic → Composit layers
- **Coordinator Pattern**: Atomic multi-model writes
- **Repository Pattern**: Query abstraction (completed 2025-11-13)
- **Validation Layer**: Business rule enforcement
- **Design System**: Liquid Glass (iOS 26+)

---

## Directory Structure

### Primary Locations

```
/Users/davidwilliams/Coding/01_ACTIVE_PROJECTS/ten_week_goal_app/
├── swift/                          # Main Swift codebase
│   ├── Sources/                    # Production code
│   ├── Tests/                      # Test suite
│   ├── docs/                       # Architecture & design docs
│   └── Package.swift              # SPM configuration
├── ProjectManagement/              # Architecture automation
│   ├── architecture.db            # SQLite tracking database
│   ├── update_architecture_docs.py # Automation script
│   └── QUICKSTART.md              # Quick command reference
├── README.md                       # Project overview
├── CLAUDE.md                       # Development guidelines (★★★)
└── VERSIONING.md                  # Version history
```

### Reference Documentation

```
/Users/davidwilliams/Coding/REFERENCE/documents/
├── SwiftLanguage/                  # Swift 6.2 Language Guide (113 files)
├── appleDeveloper/                 # SwiftUI, SwiftData, Foundation Models (34 files)
├── hig_docs/                       # Human Interface Guidelines (17 files)
└── GRDB/                          # Historical SQLite reference
```

---

## Essential Documentation Files

### For Daily Development

| File | Purpose | Location |
|------|---------|----------|
| **CLAUDE.md** | Development patterns, architecture guide | `/ten_week_goal_app/CLAUDE.md` |
| **README.md** | Project overview, setup, features | `/ten_week_goal_app/README.md` |
| **LIQUID_GLASS_VISUAL_SYSTEM.md** | iOS 26+ design implementation | `/swift/docs/LIQUID_GLASS_VISUAL_SYSTEM.md` |
| **QUICKSTART.md** | Architecture automation commands | `/ProjectManagement/QUICKSTART.md` |

### For Architecture Research

| File | Purpose | Location |
|------|---------|----------|
| **Swift Concurrency** | Swift 6 async/await, actors, @MainActor | `/REFERENCE/documents/SwiftLanguage/02-LanguageGuide/18-Concurrency.md` |
| **Macros** | @Observable, @Table, @Column explained | `/REFERENCE/documents/SwiftLanguage/02-LanguageGuide/19-Macros.md` |
| **Foundation Models** | iOS 26+ on-device LLM APIs | `/REFERENCE/documents/appleDeveloper/foundationmodels/foundation-models.md` |
| **Adopting Liquid Glass** | SwiftUI design system guide | `/REFERENCE/documents/appleDeveloper/swiftui/adopting-liquid-glass.md` |

---

## Development Skills Available

### 1. swift_design_docs
**Location**: `/Users/davidwilliams/.claude/skills/swift_design_docs/`

**Purpose**: Search and navigate indexed Swift, GRDB, SwiftUI, SwiftData, and HIG documentation

**Key Commands**:
```bash
cd /Users/davidwilliams/.claude/skills/swift-guide-navigator

# Search for topics
python3 query.py "protocol extension" --verbose

# Look up specific concepts
python3 query.py --concept "Sendable"

# Check learning progress
python3 query.py --dashboard

# Add learning notes (marks as reviewed)
python3 query.py --concept "Actor" --note "Isolated state for concurrency"
```

**When to Use**:
- Understanding Swift language features (protocols, generics, concurrency)
- Looking up SwiftUI/SwiftData APIs
- Researching Apple HIG design patterns
- Tracking learning progress on project concepts

### 2. doc-fetcher
**Location**: `/Users/davidwilliams/.claude/skills/doc-fetcher/`

**Purpose**: Fetch and index new technical documentation with intelligent search

**Key Commands**:
```bash
cd ~/.claude/skills/doc-fetcher

# Fetch single page
python doc_fetcher.py fetch "https://developer.apple.com/documentation/swiftui/view"

# Crawl with depth
python doc_fetcher.py fetch "URL" --crawl --depth 2 --max-pages 20

# Search indexed docs
python doc_fetcher.py search "async await concurrency"

# Search specific domain
python doc_fetcher.py search "protocol" --domain "developer.apple.com"

# View statistics
python doc_fetcher.py stats
```

**When to Use**:
- Need to fetch NEW Apple documentation pages
- JS-heavy documentation that can't be fetched directly
- Building searchable knowledge base
- Cross-referencing concepts across documentation sites

**Pre-Approved Domains**:
- `developer.apple.com` - Apple Developer Documentation
- `docs.python.org` - Python Documentation
- `swift.org` - Swift Language Documentation

### 3. personal-assistant
**Location**: `/Users/davidwilliams/.claude/skills/personal-assistant/`

**Purpose**: Session context analysis, memory querying, and vault navigation

**When to Use**:
- Starting a new coding session (analyze dashboards for urgent items)
- Need context about David's current work priorities
- Understanding working style and communication preferences

---

## Architecture Automation System

### ProjectManagement Tools

**Core Database**: `/ProjectManagement/architecture.db`
- Tracks all 166+ Swift files
- Detects changes (created/modified/deleted)
- Checks architectural violations
- Maintains historical changes

### Essential Commands

```bash
cd /Users/davidwilliams/Coding/01_ACTIVE_PROJECTS/ten_week_goal_app/ProjectManagement

# Initialize (first time only)
./update_architecture_docs.py --init

# Update everything (scan + violations + report)
./update_architecture_docs.py

# Export current architecture map
./update_architecture_docs.py --export-csv

# Check violations
sqlite3 architecture.db "SELECT * FROM open_violations;"

# View recent changes
sqlite3 architecture.db "SELECT * FROM recent_changes;"

# Track specific file history
sqlite3 architecture.db "
SELECT change_type, changed_at, previous_values, new_values
FROM file_history
WHERE file_path LIKE '%GoalRepository%'
ORDER BY changed_at DESC;
"
```

### Violation Types Tracked

| Type | Severity | Description |
|------|----------|-------------|
| `missing_baserepository` | HIGH | Repository not extending BaseRepository |
| `missing_sendable` | MEDIUM | Coordinator/Service not marked Sendable |
| `missing_mainactor` | HIGH | ViewModel missing @MainActor |
| `raw_sql_without_typed_row` | MEDIUM | Using Row instead of typed struct |

---

## Current Development Status

### ✅ Completed (v0.6.0)
- Three-layer domain model
- Coordinator pattern for atomic writes
- Repository + ViewModel pattern (2025-11-13)
- Validation layer integration
- Measure Coordinator Composition (2025-11-17)
- Swift 6 concurrency migration (2025-11-10)
- CloudKit sync foundation
- Basic HealthKit integration

### 🚧 Active Work Areas (v0.7.0)
1. **Dashboard Issues** - Goal/term filtering logic and time-based data presentation
2. **Xcode Build Failures** - Missing SwiftUI preview helpers blocking iOS archive
3. **LLM Tool Integration** - Connect Foundation Models tools to coordinators
4. **Embedding Backfill** - Pre-generate embeddings for existing entities
5. **Semantic Deduplication** - Use embeddings for intelligent measure matching

### ⏳ Planned Features
- Dashboard and analytics
- Enhanced HealthKit live tracking
- CSV import/export enhancements
- LLM-powered insights
- Widgets and complications
- Shortcuts and App Intents

---

## Design System: Liquid Glass

### Core Principles (iOS 26+)

**Visual Hierarchy**:
```
Overlay Layer (vibrancy, fills) → on →
Glass Layer (navigation, controls) → refracts →
Content Layer (rich backgrounds, goal cards)
```

**Key Insight**: Liquid Glass adoption is **automatic** for system components when targeting iOS 26+

**Implementation**:
- Navigation bars, tab bars, toolbars get Liquid Glass automatically
- Custom controls use `.glassEffect()` modifier
- Content layer showcases rich backgrounds (NO blur!)
- Goal cards use standard materials (`.regularMaterial`)

### Design Files

1. **LIQUID_GLASS_VISUAL_SYSTEM.md** - Complete design specification
2. **liquidglass.md** (project root) - Apple's Liquid Glass introduction
3. **June_9__2025_-_liquid_glass_press_release.md** - Official press release

---

## Code Patterns & Conventions

### Modern Swift 6 Patterns

**ViewModels** - UI state management:
```swift
@Observable
@MainActor
public final class GoalsListViewModel {
    var goals: [GoalWithDetails] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database
    
    @ObservationIgnored
    private lazy var repository: GoalRepository = {
        GoalRepository(database: database)
    }()
}
```

**Coordinators** - Background I/O:
```swift
public final class GoalCoordinator: Sendable {
    private let database: any DatabaseWriter
    
    public func create(from formData: GoalFormData) async throws -> Goal {
        // Database operations run in background
    }
}
```

### Key Rules
- ✅ `@Observable` NOT `ObservableObject`
- ✅ `@State` NOT `@StateObject`
- ✅ `@MainActor` on ViewModels
- ✅ `Sendable` on Coordinators (NO @MainActor)
- ✅ Repository + ViewModel pattern (NO @Fetch wrappers)

---

## Database Schema

**Location**: `/swift/Sources/Database/Schemas/schema_current.sql`

**Architecture**: SQLite with 3NF normalization
- **Abstraction Layer**: Action, Expectation, PersonalValue, TimePeriod, Measure
- **Basic Layer**: Goal, Milestone, Obligation, Term
- **Composit Layer**: MeasuredAction, GoalRelevance, ActionGoalContribution

**Database File**: `~/Library/Containers/com.willbda.happytohavelived/Data/Library/Application Support/GoalTracker/application_data.db`

---

## Quick Navigation Patterns

### When You Need To...

**Understand Swift syntax**: `swift_design_docs` skill → query.py
**Fetch new Apple docs**: `doc-fetcher` skill → doc_fetcher.py fetch
**Check architecture violations**: ProjectManagement → sqlite3 architecture.db
**Review design patterns**: Read CLAUDE.md → Modern Swift/SwiftUI Patterns section
**Implement Liquid Glass**: Read LIQUID_GLASS_VISUAL_SYSTEM.md
**Research Foundation Models**: `/REFERENCE/documents/appleDeveloper/foundationmodels/`
**Debug concurrency issues**: `/REFERENCE/documents/SwiftLanguage/02-LanguageGuide/18-Concurrency.md`

### Before Starting Work

1. ✅ Check memory for context: Use `personal-assistant` skill
2. ✅ Review active issues in memory notes
3. ✅ Scan recent architecture changes: `./update_architecture_docs.py`
4. ✅ Check violations: `sqlite3 architecture.db "SELECT * FROM open_violations;"`

### During Development

1. ✅ Follow CLAUDE.md patterns religiously
2. ✅ Use coordinator composition (MeasureCoordinator as service)
3. ✅ Maintain Swift 6 concurrency safety (@MainActor, Sendable)
4. ✅ Repository pattern for all queries (NO @Fetch wrappers)
5. ✅ Test with realistic data

### After Implementation

1. ✅ Run architecture scan: `./update_architecture_docs.py`
2. ✅ Update version if significant: `./bump_version.sh`
3. ✅ Document decisions in swift/docs/ if architectural
4. ✅ Update memory with lessons learned

---

## Common Pitfalls to Avoid

### ❌ Don't Do This
- Use `ObservableObject` instead of `@Observable`
- Use `@StateObject` instead of `@State`
- Put `@MainActor` on Coordinators (blocks background I/O)
- Write direct database queries in ViewModels
- Use `@Fetch` wrappers (migrated away from)
- Skip validation layer
- Create measures directly without MeasureCoordinator

### ✅ Do This Instead
- Use `@Observable` classes with `@MainActor`
- Use `@State` for ViewModel storage
- Keep Coordinators `Sendable`, NO `@MainActor`
- Call Repository methods from ViewModels
- Use Repository + ViewModel pattern
- Always use coordinators and validators
- Use MeasureCoordinator.getOrCreate() for all measures

---

## Learning & Research Workflow

### Researching New Concepts

1. **Search indexed docs first** (swift_design_docs):
   ```bash
   python3 query.py "actor sendable concurrency" --verbose
   ```

2. **If not found, fetch new pages** (doc-fetcher):
   ```bash
   python doc_fetcher.py fetch "URL" --crawl --depth 2
   ```

3. **Add learning notes**:
   ```bash
   python3 query.py --concept "Actor" --note "Your insights" --code "example"
   ```

4. **Check progress**:
   ```bash
   python3 query.py --dashboard
   ```

### Deep Dive References

For comprehensive learning:
- **Swift Language**: Read `/REFERENCE/documents/SwiftLanguage/` chapters
- **SwiftUI Patterns**: Read `/REFERENCE/documents/appleDeveloper/swiftui/` guides
- **Design Guidelines**: Read `/REFERENCE/documents/hig_docs/` for UI/UX
- **Foundation Models**: Read `/REFERENCE/documents/appleDeveloper/foundationmodels/` for LLM integration

---

## Tool Integration Workflow

### Using Multiple Tools Together

**Example: Researching + Implementing New Feature**

1. **Research API** (doc-fetcher):
   ```bash
   python doc_fetcher.py fetch "https://developer.apple.com/documentation/foundation/languagemodelsession"
   ```

2. **Understand pattern** (swift_design_docs):
   ```bash
   python3 query.py "async await structured concurrency"
   ```

3. **Check current architecture** (ProjectManagement):
   ```bash
   ./update_architecture_docs.py
   sqlite3 architecture.db "SELECT * FROM files_by_layer WHERE layer = 'Service';"
   ```

4. **Implement following CLAUDE.md patterns**

5. **Verify compliance**:
   ```bash
   ./update_architecture_docs.py --check-violations
   ```

6. **Document learnings** (swift_design_docs):
   ```bash
   python3 query.py --concept "LanguageModelSession" --note "Pattern for LLM integration"
   ```

---

## Emergency Reference

### Build Failures
- Check: `/swift/Package.swift` for dependencies
- Verify: All files have proper imports
- Review: CLAUDE.md for required patterns
- Check: architecture.db for missing Sendable/MainActor

### Architecture Violations
- Run: `./update_architecture_docs.py --check-violations`
- Query: `sqlite3 architecture.db "SELECT * FROM open_violations;"`
- Reference: CLAUDE.md for canonical patterns

### Design Questions
- Reference: `LIQUID_GLASS_VISUAL_SYSTEM.md` for iOS 26+ design
- Reference: `/REFERENCE/documents/hig_docs/` for Apple guidelines
- Check: Liquid Glass press releases in project root

---

## Version Information

- **Current**: v0.6.0 (Active Development)
- **Last Architecture Scan**: Check `architecture.db` scan_runs table
- **Swift Version**: 6.2
- **Xcode Version**: 26+
- **Target OS**: iOS 26+, macOS 26+, visionOS 26+

**Version Management**:
```bash
./bump_version.sh <version> "commit message"
```

---

## Next Steps Based on Current Work

### Priority 1: Fix Build Issues
- Missing SwiftUI preview helpers in GoalProgressViewModel
- Blocking TestFlight/App Store deployment
- Reference: CLAUDE.md concurrency patterns

### Priority 2: Dashboard Fixes
- Goal/term filtering logic issues
- Time-based data presentation
- Reference: Repository patterns in CLAUDE.md

### Priority 3: Foundation Models Integration
- Connect LLM tools to coordinators
- Implement semantic search
- Reference: `/REFERENCE/documents/appleDeveloper/foundationmodels/`

---

*This resource map should be your starting point for any development task. It connects all tools, documentation, and patterns into a cohesive workflow.*
