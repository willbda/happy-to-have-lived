# Liquid Glass Visual System Design
## Ten Week Goal App - iOS 26+ Design Language

**Last Updated**: November 8, 2025
**Target Platforms**: iOS 26+, macOS 26+, visionOS 26+
**Design Language**: Liquid Glass

---

## Executive Summary

This document defines the complete visual system for the Ten Week Goal App using Apple's Liquid Glass design language introduced in iOS 26. It represents a **fundamental paradigm shift** from traditional approaches:

**Old Paradigm**: Blur backgrounds, make them subtle, UI sits on top
**New Paradigm**: Showcase rich backgrounds, glass navigation floats above and refracts them

**Key Insight**: Liquid Glass adoption is **automatic** for standard system components. You need to do **less, not more** - simply recompile with iOS 26 SDK and navigation bars, tab bars, and toolbars automatically adopt Liquid Glass. For custom controls, use SwiftUI's `.glassEffect()` modifier.

---

## Table of Contents

1. [Liquid Glass Principles](#liquid-glass-principles)
2. [Three-Layer Architecture](#three-layer-architecture)
3. [Implementation Patterns](#implementation-patterns)
4. [Goal App Specific Designs](#goal-app-specific-designs)
5. [Critical Design Rules](#critical-design-rules)
6. [Migration Strategy](#migration-strategy)
7. [Code Reference](#code-reference)

---

## Liquid Glass Principles

### What is Liquid Glass?

From Apple's design team:

> "Liquid Glass is a new digital meta-material that dynamically bends and shapes light. Rather than simply recreating a material from the physical world, it behaves and moves organically in a manner that feels more like a lightweight liquid, responding to both the fluidity of touch and the dynamism of modern apps."

### Core Properties

1. **Lensing** - Bends and concentrates light (not just scattering)
2. **Adaptive** - Continuously changes based on content behind it
   - Switches light/dark automatically
   - Adjusts tint and shadows for legibility
   - Modulates transparency based on context
3. **Fluid Motion** - Gel-like flexibility that morphs and shape-shifts
4. **Responsive** - Instantly flexes and energizes with light on interaction
5. **Layered System** - Multiple layers working together:
   - Highlights layer (responds to light sources and device motion)
   - Shadow layer (adapts opacity based on content)
   - Internal glow (illuminates from within on touch)

### Visual Hierarchy Revolution

**Key Insight**: Liquid Glass forms a **distinct functional layer** for navigation and controls that floats **above** content, establishing clear hierarchy.

```
┌─────────────────────────────────────┐
│  Overlay Layer                      │  ← Vibrancy, fills (ON the glass)
│  - Icons with vibrancy              │
│  - Text labels                      │
│  - Emphasis fills                   │
└─────────────────────────────────────┘
            ↓ sits on ↓
┌─────────────────────────────────────┐
│  Glass Layer (FLOATING)             │  ← Liquid Glass (navigation/controls)
│  - Tab bars                         │
│  - Navigation bars                  │
│  - Toolbars                         │
│  - Floating action buttons          │
└─────────────────────────────────────┘
        ↓ refracts light from ↓
┌─────────────────────────────────────┐
│  Content Layer (RICH & VIBRANT)     │  ← Your content (goals, backgrounds)
│  - Backgrounds (full vibrancy!)     │
│  - Goal cards (.regularMaterial)    │
│  - Data visualizations              │
│  - Action lists                     │
└─────────────────────────────────────┘
```

---

## Three-Layer Architecture

### Layer 1: Content Layer (Bottom)

**Purpose**: Showcase your content and backgrounds in full vibrancy.

**What Goes Here**:
- Rich nature backgrounds (mountains, forests, horizons) - **NO blur, NO opacity**
- Goal cards with standard materials (`.regularMaterial`, `.thinMaterial`)
- Data visualizations and charts
- Action lists
- Metrics and progress indicators

**Implementation**:
```swift
struct DashboardView: View {
    var body: some View {
        ZStack {
            // Rich background - full vibrancy
            Image("mountain_sunrise")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            // NO .blur() - let glass refract it!
            // NO .opacity() - full color!

            // Content cards with standard materials
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(goals) { goal in
                        GoalCard(goal: goal)
                            .background(.regularMaterial) // NOT glass
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }
}
```

**Background Strategy for Goal App**:

| Time of Day | Image | Psychological Impact |
|-------------|-------|---------------------|
| Dawn (5-9am) | `dawn_mountains` | Hope, new beginnings, fresh start |
| Morning (9am-12pm) | `vibrant_forest` | Energy, growth, vitality |
| Afternoon (12-5pm) | `flowing_river` | Progress, sustained effort |
| Evening (5-8pm) | `sunset_horizon` | Reflection, completion, review |
| Night (8pm-5am) | `night_stars` | Rest, perspective, long-term view |

| Goal State | Image | Why |
|------------|-------|-----|
| Not Started | `distant_peak` | Journey ahead, aspiration |
| In Progress | `climbing_path` | Active effort, making progress |
| Near Complete | `approaching_summit` | Almost there, final push |
| Completed | `flower_bloom` | Achievement, fruition |
| Overdue | `storm_clearing` | Resilience, perseverance |

### Layer 2: Glass Layer (Floating Above)

**Purpose**: Navigation and controls that float above content, refracting light.

**What Goes Here**:
- Tab bars (automatic glass in iOS 26)
- Navigation bars (automatic glass)
- Toolbars (automatic glass)
- Custom floating controls (`.glassEffect()`)
- Sheet headers
- Menu containers

**Two Variants**:

**Regular** (Use 95% of time):
- Auto-adapts between light and dark
- Provides legibility in all contexts
- Works over any content
- Any size element
- Automatically gets scroll edge effects

**Clear** (Rare - only for immersive media):
- More transparent, lets richness through
- Best practices for clear variant:
  1. Use over visually rich backgrounds (photos, videos)
  2. Consider adding a dimming layer for contrast
  3. Use bold, bright content on top
- Doesn't auto-adapt light/dark
- For immersive, media-focused experiences

**Implementation**:
```swift
// System components get glass AUTOMATICALLY (no code needed)
TabView {
    GoalsView()
        .tabItem { Label("Goals", systemImage: "target") }
}
// Tab bar gets liquid glass automatically when compiled with iOS 26 SDK!

NavigationStack {
    ContentView()
}
// Navigation bar gets liquid glass automatically - no .glassEffect() needed!

// Custom floating control with glass
HStack {
    Button("Add Goal") { }
    Button("Filter") { }
}
.padding()
.glassEffect(.regular, in: Capsule()) // Regular variant

// Clear variant for immersive view
VStack {
    Text("Focus on Your Goal")
        .font(.largeTitle.bold())
        .foregroundStyle(.white) // Bold and bright
}
.padding(40)
.glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24))
// Only with dimming layer!
```

### Layer 3: Overlay Layer (On the Glass)

**Purpose**: Content that sits ON TOP of glass uses vibrancy and fills, NOT more glass.

**What Goes Here**:
- Icons (auto-vibrant on glass)
- Text labels (auto-vibrant)
- Emphasis fills (semi-transparent colors)
- Status indicators

**Anti-Pattern** - Never stack glass on glass:
```swift
// ❌ BAD - Glass on glass
VStack {
    Text("Title")
        .glassEffect() // DON'T!
}
.glassEffect() // Never stack!

// ✅ GOOD - Vibrancy on glass
VStack {
    Label("Add Goal", systemImage: "plus")
        .foregroundStyle(.primary) // Auto-vibrant
}
.glassEffect(.regular)

// ✅ GOOD - Fill for emphasis
RoundedRectangle(cornerRadius: 8)
    .fill(.blue.opacity(0.3)) // Fill, not glass
    .overlay {
        Text("Primary Action")
            .foregroundStyle(.white)
    }
```

---

## Implementation Patterns

### Pattern 1: Dashboard with Rich Background

```swift
struct DashboardView: View {
    @FetchAll(Goal.order(by: \.targetDate)) var goals
    @AppStorage("backgroundStyle") var bgStyle = BackgroundStyle.timeOfDay

    var body: some View {
        ZStack {
            // LAYER 1: Rich contextual background
            BackgroundView(style: bgStyle)
                .ignoresSafeArea()

            // Content with standard materials
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Summary cards
                    SummaryCard()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Goal cards
                    ForEach(goals) { goal in
                        GoalCard(goal: goal)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
        }
        // LAYER 2: Glass navigation (automatic)
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Options") {
                    Button("Filter", action: {})
                    Button("Sort", action: {})
                }
            }
        }
    }
}

struct BackgroundView: View {
    let style: BackgroundStyle

    var contextualImage: String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch style {
        case .timeOfDay:
            switch hour {
            case 5..<9:   return "dawn_mountains"
            case 9..<12:  return "vibrant_forest"
            case 12..<17: return "flowing_river"
            case 17..<20: return "sunset_horizon"
            default:      return "night_stars"
            }
        case .seasonal:
            let month = Calendar.current.component(.month, from: Date())
            switch month {
            case 3...5:   return "spring_blossoms"
            case 6...8:   return "summer_meadow"
            case 9...11:  return "autumn_forest"
            default:      return "winter_serenity"
            }
        case .goalState:
            // Determine from goal progress
            return "mountain_journey"
        case .minimal:
            return "" // No background
        }
    }

    var body: some View {
        if !contextualImage.isEmpty {
            Image(contextualImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                // Full vibrancy - glass will refract it!
        }
    }
}

enum BackgroundStyle: String, CaseIterable {
    case timeOfDay = "Time of Day"
    case seasonal = "Seasonal"
    case goalState = "Goal Progress"
    case minimal = "Minimal"
}
```

### Pattern 2: Immersive Goal Focus (Clear Variant)

```swift
struct GoalFocusView: View {
    let goal: GoalWithDetails
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // LAYER 1: Rich inspirational background
            Image(goal.inspirationalImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            // Dimming layer (recommended for better contrast with clear variant)
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // LAYER 2: Floating focus card with CLEAR glass
            VStack(spacing: 40) {
                Text(goal.title)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white) // Bold and bright

                ProgressRing(progress: goal.progress)
                    .frame(width: 200, height: 200)

                Text(goal.nextActionPrompt)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(60)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 32))
            // Clear variant best practices:
            // ✓ Media-rich background
            // ✓ Dimming layer for contrast
            // ✓ Bold, bright content

            // LAYER 3: Dismiss button with regular glass
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    .glassEffect(.regular, in: Circle())
                }
                Spacer()
            }
            .padding()
        }
    }
}

extension GoalWithDetails {
    var inspirationalImageName: String {
        // Map goal to appropriate background
        if expectation.expectationImportance > 8 {
            return "mountain_peak" // High importance
        } else if progress > 0.7 {
            return "approaching_summit" // Near completion
        } else {
            return "climbing_path" // In progress
        }
    }

    var nextActionPrompt: String {
        // Generate from goal data
        "Next: \(expectation.actionPlan ?? "Take the first step")"
    }
}
```

### Pattern 3: Floating Action Button

```swift
struct GoalsListView: View {
    @FetchAll(Goal.order(by: \.targetDate)) var goals
    @State private var showingAddGoal = false

    var body: some View {
        ZStack {
            // Background + content
            // ...

            // Floating add button with glass
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showingAddGoal = true
                    } label: {
                        Label("Add Goal", systemImage: "plus")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .padding()
                    }
                    .glassEffect(.regular, in: Capsule())
                    .tint(.blue) // Liquid Glass adaptive tinting
                    .padding()
                }
            }
        }
    }
}
```

### Pattern 4: Glass Morphing with GlassEffectContainer

```swift
struct MorphingToolbar: View {
    @State private var isExpanded = false

    var body: some View {
        GlassEffectContainer {
            if isExpanded {
                // Expanded state
                HStack(spacing: 20) {
                    Button("Filter") { }
                        .glassEffectID("filter")
                    Button("Sort") { }
                        .glassEffectID("sort")
                    Button("Export") { }
                        .glassEffectID("export")
                }
                .padding()
                .glassEffect(.regular, in: Capsule())
            } else {
                // Collapsed state
                Button("Options") {
                    withAnimation(.smooth) {
                        isExpanded.toggle()
                    }
                }
                .glassEffectID("options")
                .padding()
                .glassEffect(.regular, in: Circle())
            }
        }
        // Glass morphs smoothly between states!
    }
}
```

---

## Goal App Specific Designs

### HIG Semantic Materials Pattern (Implemented in HomeView 2025-11-21)

**Core Principle**: Use materials semantically, let automatic vibrancy handle appearance.

```swift
// ✅ CORRECT: Goal cards with semantic materials
private func goalCard(for goalData: GoalData) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        // Progress ring with automatic vibrancy
        ZStack {
            Circle()
                .stroke(.tertiary, lineWidth: 4)  // Semantic color, not hardcoded

            Circle()
                .trim(from: 0, to: progress)
                .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.primary)  // Automatic vibrancy
        }
        .frame(width: 60, height: 60)

        // Goal info with automatic vibrancy
        VStack(alignment: .leading, spacing: 4) {
            Text(goalData.title ?? "Untitled Goal")
                .font(.headline)
                .foregroundStyle(.primary)  // NOT .white - adapts to material
                .lineLimit(2)

            Text(targetDateText)
                .font(.caption)
                .foregroundStyle(.secondary)  // System-managed hierarchy
        }
    }
    .frame(width: 160)
    .padding()
    .background(.regularMaterial)  // Semantic material choice
    .clipShape(RoundedRectangle(cornerRadius: 16))
}

// ✅ CORRECT: Action rows with semantic fills
private func actionRow(for actionData: ActionData) -> some View {
    HStack(spacing: 12) {
        // Icon with quaternary fill (semantic)
        Image(systemName: icon)
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(width: 40, height: 40)
            .background(.quaternary)  // System-managed fill
            .clipShape(Circle())

        // Content with automatic vibrancy
        VStack(alignment: .leading, spacing: 4) {
            Text(actionData.title ?? "Untitled Action")
                .font(.body)
                .foregroundStyle(.primary)

            // Goal badge with semantic styling
            if let goalTitle = goalTitle {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption2)
                    Text(goalTitle)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)  // Consistent semantic fill
                .clipShape(Capsule())
            }
        }

        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)  // Hierarchy through semantic colors
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(.regularMaterial)  // Primary content material
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

**Key Changes from Previous Pattern**:

| Old Pattern (Color-Based) | New Pattern (Semantic) | Why |
|---------------------------|------------------------|-----|
| `.foregroundStyle(.white)` | `.foregroundStyle(.primary)` | Adapts to Reduced Transparency |
| `.background(borderColor.opacity(0.1))` | `.background(.quaternary)` | System-managed fill hierarchy |
| `.stroke(Color.white, lineWidth: 4)` | `.stroke(.tint, lineWidth: 4)` | Uses accent color system |
| `.goalCardStyle(color: color)` | `.background(.regularMaterial)` | Semantic material, not decorative color |

**Benefits**:
- ✅ Automatic adaptation to Reduced Transparency mode
- ✅ System-managed dark mode transitions
- ✅ Consistent with system apps (Messages, Reminders, Health)
- ✅ Better accessibility (WCAG contrast maintained automatically)
- ✅ Rich hero images remain focal point (not competing with colored cards)

### Goals List View

```swift
struct GoalsListView: View {
    @FetchAll(Goal.order(by: \.targetDate)) var goals
    @State private var selectedGoal: GoalWithDetails?

    var body: some View {
        ZStack {
            // Rich background based on collective progress
            BackgroundView(style: .goalState)
                .ignoresSafeArea()

            // Goals with standard materials
            List {
                ForEach(groupedGoals) { section in
                    Section(section.title) {
                        ForEach(section.goals) { goal in
                            GoalRowView(goal: goal)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    selectedGoal = goal
                                }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden) // Show our background
        }
        .navigationTitle("Goals")
        .sheet(item: $selectedGoal) { goal in
            GoalFocusView(goal: goal)
        }
    }
}
```

### Actions List View

```swift
struct ActionsListView: View {
    @Fetch(ActionsWithMeasuresAndGoals()) var actions

    var body: some View {
        ZStack {
            // Morning energy or evening reflection
            BackgroundView(style: .timeOfDay)
                .ignoresSafeArea()

            // Actions timeline
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(actionsByDate, id: \.date) { dateGroup in
                        // Date header with thin material
                        Text(dateGroup.date, style: .date)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Actions
                        ForEach(dateGroup.actions) { action in
                            ActionRowView(action: action)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Actions")
    }
}
```

### Personal Values View

```swift
struct PersonalValuesView: View {
    @FetchAll(PersonalValue.order(by: \.priority)) var values

    var body: some View {
        ZStack {
            // Gentle, grounding background
            Image("oak_tree_strong")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(values) { value in
                        ValueCard(value: value)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .onTapGesture {
                                // Navigate to value detail with custom background
                            }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Values")
    }
}

struct ValueDetailView: View {
    let value: PersonalValue
    @FetchAll var alignedGoals: [Goal] // Filter by value

    var body: some View {
        ZStack {
            // Value-specific background
            Image(value.backgroundImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    // Value header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(value.title)
                            .font(.largeTitle.bold())
                        Text(value.detailedDescription ?? "")
                            .font(.body)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Aligned goals
                    Text("\(alignedGoals.count) Aligned Goals")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(alignedGoals) { goal in
                        GoalCard(goal: goal)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
        }
        .navigationTitle(value.title)
    }
}

extension PersonalValue {
    var backgroundImageName: String {
        switch lifeDomain {
        case .health:       return "forest_trail"
        case .relationships: return "sunset_together"
        case .creativity:   return "aurora_colors"
        case .learning:     return "library_light"
        case .finance:      return "oak_strong"
        case .spirituality: return "mountain_temple"
        case .adventure:    return "canyon_vast"
        default:            return "gentle_meadow"
        }
    }
}
```

---

## Critical Design Rules

### Never Stack Glass on Glass

```swift
// ❌ WRONG - Creates visual confusion
VStack {
    Text("Title")
        .glassEffect()
}
.glassEffect()

// ✅ RIGHT - Use vibrancy on glass
VStack {
    Text("Title")
        .foregroundStyle(.primary) // Auto-vibrant
}
.glassEffect(.regular)
```

### Reserve Glass for Navigation Layer Only

```swift
// ❌ WRONG - Glass in content layer
LazyVStack {
    ForEach(goals) { goal in
        GoalCard(goal: goal)
            .glassEffect() // Competes with navigation
    }
}

// ✅ RIGHT - Standard materials for content
LazyVStack {
    ForEach(goals) { goal in
        GoalCard(goal: goal)
            .background(.regularMaterial) // Clear hierarchy
    }
}
```

### Use Regular Variant 95% of Time

```swift
// ✅ GOOD - Regular for most cases
Button("Action") { }
    .glassEffect(.regular)

// ⚠️ RARE - Clear for immersive media experiences
ZStack {
    richMediaBackground
    Color.black.opacity(0.3) // Dimming layer for contrast

    Text("Bold Text")
        .font(.largeTitle.bold())
        .foregroundStyle(.white)
        .glassEffect(.clear) // Only for immersive contexts
}
```

### Don't Blur Backgrounds Anymore

```swift
// ❌ OLD WAY (Pre-iOS 26)
Image("background")
    .blur(radius: 20)
    .opacity(0.3)

// ✅ NEW WAY (Liquid Glass)
Image("background")
    .resizable()
    .aspectRatio(contentMode: .fill)
// Full vibrancy - let glass refract it!
```

### Semantic Color System (HIG Vibrancy)

SwiftUI provides semantic colors that automatically adapt with vibrancy on materials:

| Semantic Color | Use Case | Vibrancy Level |
|----------------|----------|----------------|
| `.primary` | Primary text, main content | High vibrancy |
| `.secondary` | Supporting text, icons | Medium vibrancy |
| `.tertiary` | Tertiary text, placeholders | Lower vibrancy |
| `.quaternary` | Background fills, subtle accents | Minimal vibrancy |
| `.tint` | Accent color (progress, active states) | System accent |

**Example Hierarchy**:
```swift
VStack {
    Text("Main Title")
        .foregroundStyle(.primary)      // Highest contrast

    Text("Subtitle")
        .foregroundStyle(.secondary)    // Medium contrast

    Text("Metadata")
        .foregroundStyle(.tertiary)     // Lower contrast
}
.padding()
.background(.quaternary)                // Subtle background fill
.clipShape(RoundedRectangle(cornerRadius: 12))
.background(.regularMaterial)           // Material provides vibrancy
```

**Why Semantic Colors**:
- Automatic vibrancy on materials
- Adapts to Reduced Transparency
- Respects Increased Contrast settings
- System-managed dark mode transitions
- No manual color calculations needed

### Complete Checklist

- [x] Recompile with iOS 26 SDK - standard components get Liquid Glass **automatically**
- [x] Never stack glass on glass
- [x] Always use `.regular` variant by default
- [x] Only use `.clear` for immersive media experiences with rich backgrounds
- [x] Reserve `.glassEffect()` for **custom** controls only - system bars are automatic
- [x] Use standard materials (`.regularMaterial`, `.thinMaterial`) for content layer
- [x] Use semantic colors (`.primary`, `.secondary`, `.tertiary`, `.quaternary`) for vibrancy
- [x] Use `.quaternary` fills for subtle backgrounds (not custom opacity colors)
- [x] Ensure backgrounds are RICH and VIBRANT (not blurred/faded)
- [ ] Test with Reduced Transparency accessibility setting
- [ ] Test with Increased Contrast accessibility setting
- [ ] Test with Reduced Motion accessibility setting
- [ ] Maintain sufficient contrast (WCAG AA: 4.5:1)
- [ ] Provide VoiceOver labels
- [ ] Support Dynamic Type

---

## Migration Strategy

### Phase 1: Foundation (Week 1)

**Goal**: Remove old blur patterns, establish rich backgrounds, verify automatic adoption

**Tasks**:
1. Recompile app with iOS 26 SDK - navigation/tab bars get Liquid Glass **automatically**
2. Audit all uses of `.blur()` on backgrounds - remove them
3. Audit all uses of `.opacity()` on backgrounds - remove them
4. Replace `.ultraThinMaterial` on content cards with `.regularMaterial`
5. Verify standard system components automatically adopt glass (no code changes needed)
6. Curate 15-20 high-resolution nature images

**Before**:
```swift
ZStack {
    Image("background")
        .blur(radius: 20)
        .opacity(0.3)

    VStack {
        // content
    }
    .background(.ultraThinMaterial)
}
```

**After**:
```swift
ZStack {
    Image("background")
        .resizable()
        .aspectRatio(contentMode: .fill)
    // Full vibrancy!

    VStack {
        // content
    }
    .background(.regularMaterial)
}
```

### Phase 2: Contextual Backgrounds (Week 2)

**Goal**: Implement smart background selection

**Tasks**:
1. Create `BackgroundView` component with style enum
2. Implement time-of-day selection logic
3. Implement goal-state mapping
4. Add seasonal rotation
5. Create user preference controls

**Implementation**:
- See `BackgroundView` in [Pattern 1](#pattern-1-dashboard-with-rich-background)

### Phase 3: Custom Glass Components (Week 3)

**Goal**: Apply glass to **custom** controls only (system components already have glass)

**Tasks**:
1. Identify **custom** controls that should use glass (NOT system bars - those are automatic)
2. Apply `.glassEffect(.regular)` with appropriate shapes to custom controls
3. Test morphing with `GlassEffectContainer`
4. Ensure no glass-on-glass stacking
5. Test accessibility modifiers

**Custom Components That Need Manual Glass Application**:
- Floating action buttons (custom)
- Custom floating toolbars (NOT system toolbars)
- Custom menu containers
- Custom sheet headers (NOT standard sheets)

### Phase 4: Immersive Experiences (Week 4)

**Goal**: Create immersive focus modes with clear variant

**Tasks**:
1. Implement `GoalFocusView` with `.clear` variant
2. Add contextual dimming layers
3. Test against various rich backgrounds
4. Ensure bold, bright content on glass
5. Add smooth transitions

---

## Code Reference

### SwiftUI APIs (Custom Views)

```swift
// Apply glass effect to CUSTOM views only
.glassEffect() // Regular variant, Capsule shape (default)
.glassEffect(.regular) // Explicit regular
.glassEffect(.clear) // Clear variant (rare - for immersive media)
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

// Glass variants
Glass.regular  // Auto-adapts light/dark, use 95% of time
Glass.clear    // More transparent, for media-rich backgrounds
Glass.identity // No effect (identity/passthrough)

// Glass morphing between states
GlassEffectContainer {
    // Views with .glassEffectID() morph smoothly
}

.glassEffectID("uniqueID") // For morphing animations

// Standard materials (for content layer, NOT navigation)
.background(.regularMaterial)
.background(.thinMaterial)
.background(.ultraThinMaterial)
.background(.thickMaterial)

// Tinting (adaptive system)
.tint(.blue) // Adapts based on content underneath

// Interactive modifier (for custom controls)
.glassEffect(.regular.interactive(), in: Capsule())
```

### UIKit/AppKit - Automatic Adoption

**Important**: Liquid Glass in UIKit and AppKit is **automatic** for standard system components. There are **no custom APIs** for applying Liquid Glass to custom UIKit/AppKit views.

**What Gets Liquid Glass Automatically** (when recompiled with iOS 26 SDK):
- `UINavigationBar` / `NSToolbar` - Navigation bars
- `UITabBar` / Tab view controls - Tab bars
- `UIToolbar` / Toolbar controls - Toolbars
- `UINavigationController` bars - Navigation controllers
- Standard sheets, popovers, and menus

**For Custom Views**: Use SwiftUI's `.glassEffect()` or wrap custom views in SwiftUI to apply Liquid Glass. There are no `UIBlurEffect.Style` or `NSVisualEffectView.Material` variants for Liquid Glass.

**Migration Path**:
```swift
// ❌ No UIKit/AppKit custom glass APIs exist
// Use SwiftUI instead for custom glass effects

// ✅ Wrap UIKit view in SwiftUI to apply glass
struct CustomControlWithGlass: View {
    var body: some View {
        CustomUIKitViewRepresentable()
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

---

## User Preferences

```swift
struct VisualPreferences {
    // Background preferences
    @AppStorage("enableRichBackgrounds") var richBackgrounds = true
    @AppStorage("backgroundStyle") var style = BackgroundStyle.contextual
    @AppStorage("backgroundIntensity") var intensity = 1.0 // For future dimming option
}

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case contextual = "Match Goal State"
    case timeOfDay = "Time of Day"
    case seasonal = "Seasonal"
    case minimal = "Minimal"

    var id: String { rawValue }
}
```

### Preferences UI

```swift
struct VisualPreferencesView: View {
    @AppStorage("enableRichBackgrounds") private var richBackgrounds = true
    @AppStorage("backgroundStyle") private var style = BackgroundStyle.contextual

    var body: some View {
        Form {
            Section("Background Style") {
                Toggle("Rich Backgrounds", isOn: $richBackgrounds)

                if richBackgrounds {
                    Picker("Background Type", selection: $style) {
                        ForEach(BackgroundStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                }
            }

            Section("Accessibility") {
                // System settings
                Text("Use system settings for:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("• Reduced Transparency")
                    .font(.caption)
                Text("• Increased Contrast")
                    .font(.caption)
                Text("• Reduced Motion")
                    .font(.caption)
            }
        }
        .navigationTitle("Visual Style")
    }
}
```

---

## Expected Outcomes

After full implementation, the app will feature:

✅ **Rich, Vibrant Backgrounds**
- Mountain peaks, forests, horizons in full glory
- No blur, no opacity reduction
- Contextual selection based on time/state/season

✅ **Automatic Glass Navigation**
- Tab bars, navigation bars get Liquid Glass automatically (recompile with iOS 26 SDK)
- Custom controls use `.glassEffect(.regular)` when needed
- Morphing transitions between states with `GlassEffectContainer`

✅ **Clear Visual Hierarchy**
- Content layer: Rich backgrounds + standard materials
- Glass layer: Navigation + controls
- Overlay layer: Vibrancy + fills

✅ **Immersive Experiences**
- Goal focus mode with `.clear` variant
- Rich photography with optional dimming for contrast
- Bold, inspirational messaging

✅ **Accessibility**
- Automatic support for Reduced Transparency
- Automatic support for Increased Contrast
- Automatic support for Reduced Motion
- VoiceOver labels on all interactive elements
- Dynamic Type support

✅ **User Control**
- Enable/disable rich backgrounds
- Choose background style (time-based, contextual, seasonal, minimal)
- Respects system accessibility settings

---

## References

### Official Apple Documentation
- [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials) - Design guidance for Liquid Glass
- [SwiftUI: glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)) - API reference for `.glassEffect()` modifier
- [SwiftUI: Glass](https://developer.apple.com/documentation/swiftui/glass) - Glass struct with variants (.regular, .clear, .identity)
- [SwiftUI: GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer) - Container for morphing glass effects
- [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass) - Overview of automatic adoption
- [Applying Liquid Glass to Custom Views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views) - Tutorial for custom implementations

### Key Verified Facts
- **Automatic Adoption**: Standard system components (navigation bars, tab bars, toolbars) get Liquid Glass automatically when recompiled with iOS 26 SDK
- **SwiftUI Only for Custom Views**: `.glassEffect()` modifier is SwiftUI-only; no UIKit/AppKit custom glass APIs exist
- **Two Variants**: `.regular` (use 95% of time) and `.clear` (for immersive media experiences)
- **Platform Support**: iOS 26+, iPadOS 26+, macOS 26+, tvOS 26+, watchOS 26+, visionOS 26+
- **Source**: Verified against iOS 26.1 SDK installed at `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk`

---

**Last Updated**: November 8, 2025
**Verification Date**: November 8, 2025 (verified against iOS 26.1 SDK)
**Next Review**: After Phase 1 implementation
**Maintainer**: Development Team
