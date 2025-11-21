# Happy to Have Lived (HtHL)

A native iOS/macOS/visionOS application for structured goal planning and progress tracking.

## Overview

Happy to Have Lived helps you set, track, and achieve personal goals through structured time periods. Built with Swift 6.2 and SwiftUI, it provides a modern, native experience across all Apple platforms.

### Key Features

- **Structured Goal Planning**: Set goals with clear start and target dates
- **Measurable Progress**: Track actions with quantifiable measurements
- **Value Alignment**: Connect goals to personal values and life domains
- **Ten-Week Terms**: Organize goals into focused planning periods
- **Apple Health Integration**: Import workouts and health data as actions
- **CSV Import/Export**: Bulk data management and backup

## Platform Requirements

- iOS 26+
- macOS 26+ (Tahoe)
- visionOS 26+
- Xcode 26+

## Installation

### For Users

The app is currently in development. Release information will be added when available.

### For Developers

Clone and have fun.

## Architecture

### Three-Layer Domain Model

The app uses a normalized database design with three conceptual layers:

1. **Abstraction Layer**: Core entities with full metadata (Action, Expectation, PersonalValue, TimePeriod, Measure)
2. **Basic Layer**: Working entities that reference abstractions (Goal, Milestone, Obligation, Term)
3. **Composit Layer**: Junction tables for relationships (MeasuredAction, GoalRelevance, ActionGoalContribution)

### Visual Design System (iOS 26+ Liquid Glass)

The app embraces Apple's Liquid Glass design language with a three-layer visual hierarchy:

1. **Content Layer**: Rich, vibrant backgrounds and goal cards with standard materials
2. **Glass Layer**: Navigation and controls floating above with Liquid Glass
3. **Overlay Layer**: Content on glass using vibrancy and fills

See [LIQUID_GLASS_VISUAL_SYSTEM.md](swift/docs/LIQUID_GLASS_VISUAL_SYSTEM.md) for complete design specifications.

### Technology Stack

- **Language**: Swift 6.2 with strict concurrency
- **UI Framework**: SwiftUI with Observation framework
- **Database**: SQLite with SQLiteData ORM
- **Architecture**: DataStore pattern (centralized @Observable store), Coordinator pattern for writes, Repository pattern for reads
- **Dependencies**: Point-Free libraries (SQLiteData, Dependencies, StructuredQueries)

## Project Structure

```
swift/
├── Sources/
│   ├── Models/           # Domain models (3 layers)
│   ├── Database/         # Schema, Bootstrap, SyncConfiguration
│   ├── Services/         # Business logic and data access
│   │   ├── Coordinators/ # Multi-model atomic writes
│   │   ├── Validation/   # Business rule enforcement
│   │   ├── Repositories/ # Query abstraction (✅ complete)
│   │   ├── HealthKit/    # Apple Health integration
│   │   ├── Semantic/     # Embedding generation (scaffolded)
│   │   └── ImportExport/ # CSV import/export
│   └── App/              # SwiftUI application layer
│       ├── DataStore.swift   # ⭐ Centralized @Observable store (v0.7.0)
│       └── Views/            # SwiftUI views
├── HappyToHaveLived/
│   ├── HappyToHaveLived.xcodeproj
│   └── Happy to Have Lived Tests/  # Swift Testing test suite
└── Package.swift         # Swift Package Manager configuration
```

## Development

### Agentic Coding

In addition to a structured goal planning application, this is also a documented exercise in using LLMs (principally Anthropic's Claude) as a coding aid. Please be mindful of that fact when considering or using this work.

### Database

The app uses a SQLite database with a 3NF normalized schema. Database location:

```
~/Library/Containers/com.willbda.happytohavelived/Data/Library/Application Support/GoalTracker/application_data.db
```

## Data Model

### Core Concepts

- **Actions**: Records of what you've done (past-oriented)
- **Goals**: Objectives with start and target dates (future-oriented)
- **Measures**: Units of measurement (hours, kilometers, pages, etc.)
- **Personal Values**: Life areas and values that goals align with
- **Terms**: Planning periods for organizing goals

### Relationships

- Actions can have multiple measurements
- Actions can contribute to multiple goals
- Goals can align with multiple values
- Goals can be assigned to terms

## Features in Development

### Current Phase (v0.7.0)

✅ Three-layer domain model
✅ Coordinator pattern for atomic writes
✅ Repository pattern with JSON aggregation (completed 2025-11-13)
✅ DataStore pattern - centralized @Observable store (completed 2025-11-20)
✅ Validation layer integration
✅ CloudKit sync preparation
✅ Basic HealthKit integration
✅ Swift Testing test suite

### Next Phase (v0.8.0)

🚧 CSV import/export enhancements
🚧 Performance optimizations (import workflows)
⏳ Dashboard and analytics
⏳ Enhanced HealthKit live tracking

### Future Phases (v0.9.0+)

⏳ LLM-powered insights (on-device via Foundation Models)
⏳ Semantic search and deduplication
⏳ Widgets and complications
⏳ Shortcuts and App Intents

## Contributing

This project is currently in active development. Contribution guidelines will be added when the project reaches v1.0.

### Development Practices

- **Scaffolding**: Plan features by creating files with descriptive comments first
- **Documentation**: Detailed in-line comments to guide both humans and LLMs; comments should be didactic and not merely descriptive -- if the usefulness of a comment would be obviated by better naming or archictecture, make the better choice and omit the comment; but do include comments if correcting anti-patterns or making judgment calls or if it took meaningful time to research/debug a problem that's now fixed. Do this to help the next person/LLM that comes along. And (my intuition) so that the context window contains more rather than fewer relevant guardrails/guides.

See [CLAUDE.md](CLAUDE.md) for addition guidelines meant for Claude.

## Testing

The project uses Swift Testing framework for validation and business logic testing.

### Test Suite

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter "CoordinatorValidationTests"

# Run in Xcode (Cmd+U)
open swift/HappyToHaveLived/HappyToHaveLived.xcodeproj
```

### Current Test Coverage

- ✅ **Coordinator Validation Tests** - Two-phase validation pattern (business rules + referential integrity)
- ✅ **Business Logic Tests** - MatchingService, query patterns
- ✅ **Schema Validation Tests** - Database structure compliance
- ✅ **Query Performance Tests** - N+1 detection, JSON aggregation efficiency

### Testing Philosophy

Tests focus on **informative and actionable** scenarios:
- Business rule enforcement (validation errors)
- Data integrity (cascade deletes, foreign keys)
- Performance patterns (bulk queries vs N+1)

The project also relies heavily on:
- **Compile-time safety** - Swift 6 strict concurrency, type safety, protocol conformance
- **Real-world usage** - Daily dogfooding on iOS/macOS devices 


## Documentation

- [CLAUDE.md](CLAUDE.md) - Development guidelines and architecture details
- [VERSIONING.md](VERSIONING.md) - Version history and changelog
- [swift/docs/](swift/docs/) - Further ramblings, notes, and reflections on what all this means and why; periodically archived. 

## License

All rights reserved. This is a personal project done in public, like your neighbor singing in the shower with the windows open. I doubt anyone besides friends and family I excitedly direct to this page will read this or have any interest in copying or contributing. 

That said, if you do come across this, and want to use my work, send me a note. I'm reasonable, and I know wouldn't be able to do this without the help and contributions of many who came before me. Similarly if you want to contribute.

License information will be re-evaluated as I approach v 1.0

## Contact

For questions or feedback, please open an issue in the repository.

---

**Current Status**: v0.7.0 - Active Development (DataStore pattern complete)
**Target Release**: v1.0.0 - Winter 2025-26