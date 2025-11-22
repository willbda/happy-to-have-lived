# HomeView Design Patterns

**Written**: 2025-11-22
**Purpose**: Document the goal-centric action grouping pattern in HomeView

---

## Architecture Overview

HomeView uses **Approach 4: Goal Carousel + Grouped Action Sections** pattern for displaying user progress.

### Visual Layout

```
┌─────────────────────────────────────────┐
│  Hero Image (Mountains4)                │
│  "Good morning"                         │
│  "Here's what's happening"              │
└─────────────────────────────────────────┘

Active Goals (horizontal scroll)
┌──────┐ ┌──────┐ ┌──────┐
│Goal 1│ │Goal 2│ │Goal 3│ ←scroll→
└──────┘ └──────┘ └──────┘

Recent Actions by Goal
▼ Run Marathon (3 actions)
  ┌──────┐ ┌──────┐ ┌──────┐
  │ 5km  │ │ 10km │ │ 8km  │ ←scroll→
  └──────┘ └──────┘ └──────┘

▼ Learn Swift (2 actions)
  ┌──────┐ ┌──────┐
  │Study │ │Build │ ←scroll→
  └──────┘ └──────┘

▼ No Goal (1 action)
  ┌──────┐
  │Misc  │
  └──────┘
```

---

## Key Components

### 1. State Management

```swift
/// Track which goal sections are expanded
@State private var expandedGoalSections: Set<UUID> = []
```

**Pattern**: Set-based expansion state
- Add UUID when section expands
- Remove UUID when section collapses
- withAnimation for smooth transitions

### 2. Data Organization

```swift
/// Goals that have at least one associated action
private var goalsWithActions: [GoalData] {
    dataStore.activeGoals.filter { goal in
        !dataStore.actionsForGoal(goal.id).isEmpty
    }
}

/// Actions not linked to any goal
private var unlinkedActions: [ActionData] {
    dataStore.recentActions.filter { action in
        action.contributions.isEmpty
    }
}
```

### 3. Collapsible Sections

- Tappable header shows/hides action carousel
- Chevron indicates expand/collapse state
- Action count displayed in header
- Horizontal ScrollView for actions

### 4. Action Cards

- 140×160 fixed size (compact, scannable)
- Material background (Liquid Glass system)
- Shows icon, title, measurement, relative date
- Tap to edit, context menu to delete

---

## Design Rationale

### Why Goal-Grouped Actions?

**Benefits over chronological timeline**:
- ✅ Clear causality (which actions drive which goals)
- ✅ Progress visibility (activity per goal)
- ✅ Progressive disclosure (collapse irrelevant sections)
- ✅ Supports goal-focused mental model

**Trade-offs**:
- ❌ Less pure chronological view
- ❌ More complex layout (carousels + sections)

### Why Horizontal Carousels?

1. Visual scanning efficiency
2. Higher information density
3. Apple design pattern (Music, Fitness, App Store)
4. Compact secondary display (actions support goals)

### Why "No Goal" Section?

1. Shows ALL actions (no orphaned data)
2. Reminds users to link actions
3. Supports general activity logging

---

## Code References

**Main Components**:
- Collapsible section: `HomeView.swift:383-431`
- Action card: `HomeView.swift:434-487`
- Layout: `HomeView.swift:131-185`

**Data Helpers**:
- `actionsForGoal(_:)`: `DataStore.swift:121-125`
- `goalsWithActions`: `HomeView.swift:239-243`
- `unlinkedActions`: `HomeView.swift:246-250`

---

## Future Enhancements

1. **Action count badges** on goal cards
2. **Date range filtering** (this week / all time)
3. **Sort options** (priority, activity, alphabetical)
4. **Remember expansion state** (UserDefaults persistence)
5. **Quick stats** (streaks, last action date)
