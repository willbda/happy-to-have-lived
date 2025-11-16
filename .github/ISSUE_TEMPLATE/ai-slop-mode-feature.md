---
name: AI-Slop Mode Feature
about: Add Foundation Models-powered theme system for personalized display text
title: '[v0.9.8] AI-Slop Mode: Theme-Based Display Text Generation'
labels: enhancement, ux, foundation-models, v0.9.8
assignees: ''
---

## Overview

**Target Version:** v0.9.8
**Category:** UX Refinement
**Effort:** ~21-29 hours (~3-4 weeks part-time)

Transform Happy to Have Lived from "a series of normalized database tables and SQL queries stitched together with buttons" into a personable, authentic, and special experience by adding AI-powered theme-based text generation.

Users can select from multiple personality themes (Gentle Parenting, David Goggins, TED Talk, Lean In, etc.) that transform empty states, help text, and instructions throughout the app using on-device Foundation Models.

## Motivation

**Current State:**
- Generic, database-centric UI text
- Professional but impersonal
- Lacks personality and emotional connection

**Desired State:**
- Personalized, theme-aware UI text
- Emotional resonance with user's preferred style
- Authentic feel that matches user's mindset
- UX candy that makes the app special

**Examples:**

| Element | Professional (Default) | Gentle Parenting | David Goggins |
|---------|------------------------|------------------|---------------|
| Empty State | "Set your first goal to start tracking progress" | "You're ready to explore what matters to you. Let's think about a goal that feels right." | "STOP WAITING. Set your first goal NOW. Progress starts when you DO THE WORK." |
| Loading | "Loading goals..." | "Gathering your goals..." | "Loading your targets..." |
| Form Help | "Importance (1-10)" | "How important does this feel to you?" | "How bad do you want this? RATE IT." |

## Architecture: Strict Separation of Concerns

### Design Principle: Views Stay Dumb

**Critical Requirement:** This feature MUST NOT couple views to theming logic. Views will be comprehensively audited later for Swift 6.2 + SwiftUI 26+ (Liquid Glass) compliance. Any theming logic must be isolated in ViewModels and Services.

### Layer Responsibilities

```
┌─────────────────────────────────────────────────────────┐
│ VIEW LAYER (SwiftUI)                                    │
│ - Pure declarative UI                                   │
│ - Binds to ViewModel properties: Text(viewModel.text)  │
│ - NO theme knowledge, NO service calls, NO logic       │
└─────────────────────────────────────────────────────────┘
                           ↓ binds to
┌─────────────────────────────────────────────────────────┐
│ VIEWMODEL LAYER (@Observable @MainActor)                │
│ - Exposes themed text as observable properties          │
│ - Handles theme selection via user actions              │
│ - Calls DisplayTextCoordinator for text generation      │
│ - Provides fallback text if generation fails            │
└─────────────────────────────────────────────────────────┘
                           ↓ calls
┌─────────────────────────────────────────────────────────┐
│ COORDINATOR LAYER (Sendable, no @MainActor)             │
│ - Orchestrates fetch-or-generate workflow               │
│ - Checks cache first, generates if missing              │
│ - Atomic operations for storing new text                │
└─────────────────────────────────────────────────────────┘
                    ↓ uses                ↓ uses
    ┌───────────────────────┐    ┌──────────────────────┐
    │ SERVICE LAYER         │    │ REPOSITORY LAYER     │
    │ (LLM Generation)      │    │ (Database Access)    │
    │ - DisplayTextService  │    │ - DisplayTextRepo    │
    │ - Foundation Models   │    │ - Cache management   │
    └───────────────────────┘    └──────────────────────┘
```

### Code Examples

**✅ CORRECT: View binds to ViewModel property**
```swift
// GoalsListView.swift
struct GoalsListView: View {
    @State private var viewModel = GoalsListViewModel()

    var body: some View {
        if viewModel.goals.isEmpty {
            ContentUnavailableView {
                Label(viewModel.emptyStateTitle, systemImage: "target")
            } description: {
                Text(viewModel.emptyStateDescription)  // ← Just render
            }
        }
    }
}
```

**❌ WRONG: View knows about themes or services**
```swift
// DON'T DO THIS
struct GoalsListView: View {
    let displayTextService: DisplayTextService  // ❌ View shouldn't know about services
    let currentTheme: DisplayTheme              // ❌ View shouldn't manage theme state

    var body: some View {
        Text(displayTextService.generate(...))  // ❌ View shouldn't call services
    }
}
```

## Implementation Phases

### Phase 1: Foundation (3-4 hours)

**Deliverables:**
- [ ] `DisplayTheme` enum with 5-6 themes
- [ ] `DisplayTextType` enum (title, description, help_text, etc.)
- [ ] `GeneratedDisplayText` model (matches database schema)
- [ ] Database migration: `generatedDisplayText` table + indexes
- [ ] Unit tests for theme system

**Files to Create:**
```
swift/Sources/Models/DisplayText/
├── DisplayTheme.swift
├── DisplayTextType.swift
└── GeneratedDisplayText.swift

swift/Sources/Database/Migrations/
└── Migration_AddGeneratedDisplayText.swift
```

**Acceptance Criteria:**
- [ ] Themes compile and have descriptive system prompts
- [ ] Database table created with proper indexes
- [ ] Migration runs successfully on clean database
- [ ] Models conform to `Sendable` for Swift 6 concurrency

---

### Phase 2: Data Layer (4-5 hours)

**Deliverables:**
- [ ] `DisplayTextRepository` (CRUD operations)
- [ ] `DisplayTextCoordinator` (orchestration logic)
- [ ] Cache invalidation strategy
- [ ] Integration tests for repository

**Files to Create:**
```
swift/Sources/Services/DisplayText/
├── DisplayTextRepository.swift
├── DisplayTextCoordinator.swift
└── DisplayTextCachePolicy.swift
```

**Repository API:**
```swift
public final class DisplayTextRepository: Sendable {
    public func fetch(
        entityType: String,
        entityId: String?,
        theme: DisplayTheme,
        textType: DisplayTextType
    ) async throws -> GeneratedDisplayText?

    public func save(_ text: GeneratedDisplayText) async throws
    public func updateRating(_ textId: UUID, rating: Int) async throws
    public func deleteExpired() async throws
}
```

**Coordinator API:**
```swift
public final class DisplayTextCoordinator: Sendable {
    public func getThemedText(
        entityType: String,
        entityId: String?,
        theme: DisplayTheme,
        textType: DisplayTextType,
        fallback: String
    ) async throws -> String

    public func regenerateText(...) async throws -> String
}
```

**Acceptance Criteria:**
- [ ] Repository follows existing repository patterns (GoalRepository, ActionRepository)
- [ ] Coordinator is `Sendable` (no `@MainActor`, only `private let` properties)
- [ ] Cache hit/miss logged for performance monitoring
- [ ] Fallback text returned if generation fails

---

### Phase 3: LLM Integration (3-4 hours)

**Deliverables:**
- [ ] `DisplayTextService` (wraps LanguageModelSession)
- [ ] `GenerateDisplayTextTool` (optional - for explicit tool calling)
- [ ] Theme-specific system prompts
- [ ] Fallback strategy for LLM unavailability
- [ ] Integration tests with mock LLM

**Files to Create:**
```
swift/Sources/Services/DisplayText/
└── DisplayTextService.swift

swift/Sources/Services/FoundationModels/Tools/
└── GenerateDisplayTextTool.swift  (optional)
```

**Service API:**
```swift
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
public final class DisplayTextService: Sendable {
    public func generate(
        originalText: String,
        theme: DisplayTheme,
        textType: DisplayTextType,
        context: String
    ) async throws -> String
}
```

**Theme System Prompts:**
```swift
public enum DisplayTheme: String, Codable, CaseIterable {
    case professional
    case gentleParenting
    case davidGoggins
    case tedTalk
    case leanIn
    case casual

    var systemPrompt: String {
        switch self {
        case .gentleParenting:
            return """
            You are helping rewrite UI text in a warm, encouraging, growth-mindset style.
            Use gentle language that validates the user's journey and promotes self-compassion.
            Avoid pressure, judgment, or urgency. Focus on possibility and gentle encouragement.
            Keep the core meaning but make it feel supportive and nurturing.
            """
        case .davidGoggins:
            return """
            You are helping rewrite UI text in an intense, no-excuses, warrior mindset style.
            Use direct, powerful language that challenges the user to take action NOW.
            Emphasize discipline, hard work, and mental toughness.
            Keep the core meaning but make it feel like a drill sergeant's motivation.
            """
        // ... etc.
        }
    }
}
```

**Acceptance Criteria:**
- [ ] Service successfully generates text for all themes
- [ ] Graceful degradation if Foundation Models unavailable
- [ ] Generated text maintains core meaning of original
- [ ] Average generation time < 2 seconds
- [ ] Service follows existing LLM patterns (GoalCoachService)

---

### Phase 4: ViewModel Integration (4-6 hours)

**Deliverables:**
- [ ] Extend `GoalsListViewModel` with theme support
- [ ] Extend `ActionsListViewModel` with theme support
- [ ] Extend `PersonalValuesListViewModel` with theme support
- [ ] Extend `TermsListViewModel` with theme support
- [ ] Unit tests for ViewModel theming logic

**Files to Modify:**
```
swift/Sources/App/ViewModels/
├── GoalsListViewModel.swift      (+theme support)
├── ActionsListViewModel.swift    (+theme support)
├── PersonalValuesListViewModel.swift (+theme support)
└── TermsListViewModel.swift      (+theme support)
```

**ViewModel Extension Pattern:**
```swift
@Observable
@MainActor
public final class GoalsListViewModel {
    // Observable properties (Views bind to these)
    var goals: [GoalWithDetails] = []
    var emptyStateTitle: String = "No Goals Yet"
    var emptyStateDescription: String = "Set your first goal to start tracking progress"
    var isLoading: Bool = false

    // Internal theme state
    private var currentTheme: DisplayTheme = .professional

    // Dependencies (not observable)
    @ObservationIgnored
    private lazy var displayTextCoordinator: DisplayTextCoordinator = {
        DisplayTextCoordinator(database: database)
    }()

    // Public API (called by Settings view when user changes theme)
    public func applyTheme(_ theme: DisplayTheme) async {
        currentTheme = theme
        await refreshThemedText()
    }

    // Internal refresh logic
    private func refreshThemedText() async {
        do {
            emptyStateTitle = try await displayTextCoordinator.getThemedText(
                entityType: "empty_state",
                entityId: "goals_list",
                theme: currentTheme,
                textType: .title,
                fallback: "No Goals Yet"
            )

            emptyStateDescription = try await displayTextCoordinator.getThemedText(
                entityType: "empty_state",
                entityId: "goals_list",
                theme: currentTheme,
                textType: .description,
                fallback: "Set your first goal to start tracking progress"
            )
        } catch {
            // Graceful degradation - keep fallback text
            print("Failed to load themed text: \(error)")
        }
    }
}
```

**Acceptance Criteria:**
- [ ] ViewModels expose themed text as observable properties
- [ ] ViewModels never expose theme selection UI logic
- [ ] Theme changes trigger automatic text refresh
- [ ] Fallback text always available if generation fails
- [ ] No breaking changes to existing View code

---

### Phase 5: View Updates (3-4 hours)

**Deliverables:**
- [ ] Update `GoalsListView` empty state
- [ ] Update `ActionsListView` empty state
- [ ] Update `PersonalValuesListView` empty state
- [ ] Update `TermsListView` empty state
- [ ] Optional: Update `DocumentableFields` placeholders
- [ ] Manual testing across all views

**Files to Modify:**
```
swift/Sources/App/Views/ListViews/
├── GoalsListView.swift           (+5 lines)
├── ActionsListView.swift         (+5 lines)
├── PersonalValuesListView.swift  (+5 lines)
└── TermsListView.swift           (+5 lines)

swift/Sources/App/Views/Templates/
└── DocumentableFields.swift      (+3 lines, optional)
```

**View Changes (Example):**
```swift
// BEFORE
if viewModel.goals.isEmpty {
    ContentUnavailableView {
        Label("No Goals Yet", systemImage: "target")
    } description: {
        Text("Set your first goal to start tracking progress")
    }
}

// AFTER (minimal change)
if viewModel.goals.isEmpty {
    ContentUnavailableView {
        Label(viewModel.emptyStateTitle, systemImage: "target")
    } description: {
        Text(viewModel.emptyStateDescription)
    }
}
```

**Acceptance Criteria:**
- [ ] All 4 list views use themed empty states
- [ ] Views remain pure (no theme logic, no service calls)
- [ ] Default text shown immediately, themed text loads asynchronously
- [ ] No layout shifts or flicker during text refresh
- [ ] Manual testing: switch themes, verify text updates

---

### Phase 6: User Experience (2-3 hours)

**Deliverables:**
- [ ] Theme picker UI (Settings or Profile view)
- [ ] Theme preference persistence (UserDefaults)
- [ ] Optional: "Regenerate" button for text user doesn't like
- [ ] Optional: 5-star rating system
- [ ] User testing with 2-3 beta users

**Files to Create:**
```
swift/Sources/App/Views/Settings/
├── ThemePickerView.swift
└── ThemePreferenceViewModel.swift
```

**Theme Picker UI:**
```swift
struct ThemePickerView: View {
    @State private var viewModel = ThemePreferenceViewModel()

    var body: some View {
        Form {
            Section("Display Theme") {
                Picker("Theme", selection: $viewModel.selectedTheme) {
                    ForEach(DisplayTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName)
                    }
                }
            }

            Section("Preview") {
                Text(viewModel.previewText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Theme Settings")
    }
}
```

**Acceptance Criteria:**
- [ ] User can select theme from Settings
- [ ] Theme preference persists across app launches
- [ ] All list views update when theme changes
- [ ] Preview text shows example of selected theme
- [ ] Theme change applies globally (not per-view)

---

### Phase 7: Polish & Refinement (2-3 hours)

**Deliverables:**
- [ ] Performance testing (cache hit rates > 90%)
- [ ] Analytics on theme usage (which themes are popular?)
- [ ] Error handling audit (all failure modes graceful)
- [ ] Documentation in CLAUDE.md
- [ ] User testing feedback incorporated

**Acceptance Criteria:**
- [ ] Cache hit rate > 90% after initial load
- [ ] No performance regression in list view load times
- [ ] All error scenarios tested and handled gracefully
- [ ] Foundation Models unavailable → professional theme only
- [ ] Documentation updated with usage examples

---

## Technical Specifications

### Database Schema

```sql
-- Generated Display Text Storage
CREATE TABLE generatedDisplayText (
    id TEXT PRIMARY KEY,

    -- Entity reference (what this text describes)
    entityType TEXT NOT NULL CHECK(entityType IN (
        'goal', 'action', 'value', 'term',
        'empty_state', 'instruction', 'help_text', 'confirmation'
    )),
    entityId TEXT,                  -- NULL for system-level text (empty states)

    -- Theme/Style information
    theme TEXT NOT NULL CHECK(theme IN (
        'professional', 'gentle_parenting', 'david_goggins',
        'ted_talk', 'lean_in', 'casual'
    )),
    textType TEXT NOT NULL CHECK(textType IN (
        'title', 'description', 'instruction',
        'confirmation', 'empty_state', 'help_text', 'placeholder'
    )),

    -- Generated content
    generatedText TEXT NOT NULL,    -- The actual display text
    originalText TEXT NOT NULL,     -- Source text for regeneration
    generationPrompt TEXT,          -- Prompt used to generate this

    -- Quality tracking (optional for v1)
    userRating INTEGER CHECK(userRating BETWEEN 1 AND 5),
    regenerationCount INTEGER DEFAULT 0,

    -- Metadata
    generatedAt TEXT NOT NULL,
    expiresAt TEXT,                 -- Optional: refresh after date
    modelVersion TEXT,              -- Which LLM version generated this
    logTime TEXT NOT NULL,

    -- Ensure one primary text per (entity, theme, textType)
    UNIQUE(entityId, entityType, theme, textType)
);

-- Indexes for fast lookups
CREATE INDEX idx_generated_display_text_lookup ON generatedDisplayText(
    entityType, entityId, theme, textType
);

CREATE INDEX idx_generated_display_text_theme ON generatedDisplayText(theme);

CREATE INDEX idx_generated_display_text_expiry ON generatedDisplayText(expiresAt)
WHERE expiresAt IS NOT NULL;
```

### Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Cache hit rate (after warmup) | > 90% | Monitor via logging |
| Text generation time | < 2 seconds | P95 latency |
| View load time impact | < 50ms overhead | Compare before/after |
| Database query time | < 10ms | Repository layer logs |
| Memory overhead | < 5MB | Instruments profiling |

### Text Scope (v0.9.8)

**In Scope:**
- ✅ Empty state titles and descriptions (4 list views)
- ✅ Loading messages ("Loading goals...")
- ✅ Thinking indicators ("Thinking...")
- ✅ Optional: Form placeholders ("Title", "Description")
- ✅ Optional: Help text and instructions

**Out of Scope (Future):**
- ❌ Action button labels ("Save", "Delete", "Cancel") - UX consistency
- ❌ Navigation/Tab labels - Apple HIG compliance
- ❌ Error messages - Clarity over personality
- ❌ Validation messages - Precision required
- ❌ Section headers - Low impact

### Theme Definitions (v1)

| Theme | Style Guide | Example |
|-------|-------------|---------|
| **Professional** (default) | Clear, direct, business-like | "Set your first goal to start tracking progress" |
| **Gentle Parenting** | Warm, encouraging, growth-mindset | "You're ready to explore what matters to you. Let's think about a goal that feels right." |
| **David Goggins** | Intense, no-excuses, warrior mindset | "STOP WAITING. Set your first goal NOW. Progress starts when you DO THE WORK." |
| **TED Talk** | Inspiring, big-picture, visionary | "Every journey begins with a single goal. What will yours be?" |
| **Lean In** | Empowering, confident, action-oriented | "Take charge of your growth. Set a goal that challenges you to step up." |
| **Casual** | Friendly, conversational, approachable | "No goals yet! Let's add one and see where it takes you." |

## Risk Mitigation

| Risk | Mitigation | Fallback |
|------|------------|----------|
| **LLM unavailable** | Check `ModelAvailability` on launch | Hide theme picker, use professional theme only |
| **Generation fails** | Always provide fallback text | Display original text |
| **Poor quality text** | User rating system + regenerate button | User can revert to professional theme |
| **Performance regression** | Aggressive caching + async loading | Cache never expires unless user regenerates |
| **View coupling** | Strict architecture review | All theming logic in ViewModel layer only |
| **Swift 6.2 migration conflicts** | Views remain pure (no logic added) | Theming isolated to ViewModel/Service layers |

## Success Criteria

### Functional
- [ ] User can select from 5-6 themes in Settings
- [ ] Theme preference persists across app launches
- [ ] All empty states use themed text
- [ ] Text updates automatically when theme changes
- [ ] Fallback text always available

### Technical
- [ ] Views have zero theming logic (ready for future audit)
- [ ] All coordinators/services are `Sendable` (Swift 6 compliant)
- [ ] Cache hit rate > 90% after warmup
- [ ] No performance regression in list views
- [ ] Graceful degradation if Foundation Models unavailable

### UX
- [ ] App feels more personable and authentic
- [ ] Theme reflects user's preferred communication style
- [ ] Text quality feels natural and contextual
- [ ] No jarring layout shifts during text loading
- [ ] User can regenerate text they don't like

## Testing Plan

### Unit Tests
- [ ] `DisplayTheme` enum serialization
- [ ] `DisplayTextRepository` CRUD operations
- [ ] `DisplayTextCoordinator` cache logic
- [ ] `DisplayTextService` generation (mocked LLM)
- [ ] ViewModel theme application

### Integration Tests
- [ ] End-to-end text generation flow
- [ ] Cache invalidation and refresh
- [ ] Theme persistence and retrieval
- [ ] Database migration (clean install + upgrade)

### Manual Testing
- [ ] Switch themes, verify all views update
- [ ] Test with Foundation Models unavailable
- [ ] Test with airplane mode (offline)
- [ ] Test cache hit/miss scenarios
- [ ] User acceptance testing (2-3 beta users)

## Documentation Updates

- [ ] Update `CLAUDE.md` with theming patterns
- [ ] Document ViewModel extension pattern
- [ ] Add theme selection to user guide
- [ ] Update architecture diagrams

## Future Enhancements (Post-v0.9.8)

- [ ] Custom user-defined themes (text prompt input)
- [ ] Context-aware text (time of day, user mood)
- [ ] Seasonal themes (holiday-specific)
- [ ] A/B testing on theme effectiveness
- [ ] Export/import theme preferences
- [ ] Theme analytics dashboard
- [ ] Multi-language support (localization + theming)

## References

- [Foundation Models Documentation](https://developer.apple.com/documentation/foundation-models)
- [Swift Observation Framework](https://developer.apple.com/documentation/observation)
- [SwiftUI State Management](https://developer.apple.com/documentation/swiftui/state-and-data-flow)
- Project: `CLAUDE.md` - Architecture patterns
- Project: `CONCURRENCY_MIGRATION_20251110.md` - Swift 6 patterns
