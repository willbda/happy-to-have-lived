# HomeView DataStore Refactor Plan

**Written by Claude Code on 2025-11-20**
**Context**: Adapting HomeView to use the new declarative DataStore pattern

---

## Summary

The codebase has been refactored from **imperative ViewModels** to **declarative DataStore pattern**. HomeView needs the same treatment to maintain consistency.

---

## Current State vs. Target State

### **Current** (Placeholders)
```swift
// HomeView.swift uses placeholder data
ForEach(0..<5) { index in
    goalCardPlaceholder(index: index)
}
```

### **Target** (DataStore)
```swift
// HomeView.swift observes DataStore
@Environment(DataStore.self) private var dataStore

ForEach(dataStore.activeGoals.prefix(5)) { goalData in
    goalCard(for: goalData)
}
```

---

## Required Changes

### **1. Replace Placeholder Functions**

**Delete these placeholder functions**:
- `goalCardPlaceholder(index: Int)`
- `actionRowPlaceholder(index: Int)`

**Replace with real data functions**:

```swift
// MARK: - Real Data Components

private func goalCard(for goalData: GoalData) -> some View {
    let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
    let colorIndex = abs(goalData.id.hashValue) % colors.count
    let color = colors[colorIndex]

    // TODO: Get real progress from ProgressCalculationService
    let progress = 0.5  // Placeholder until we wire up progress tracking

    return VStack(alignment: .leading, spacing: 8) {
        Spacer()

        // Progress ring
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .frame(width: 50, height: 50)

        Spacer()

        // Goal info
        VStack(alignment: .leading, spacing: 4) {
            Text(goalData.title ?? "Untitled Goal")
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)

            if let targetDate = goalData.targetDate {
                Text("Target: \(targetDate, style: .date)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
    .padding()
    .frame(width: 160, height: 200)
    .background(
        LinearGradient(
            colors: [color.opacity(0.8), color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    .onTapGesture {
        // TODO: Navigate to goal detail or quick-add action
    }
}

private func actionRow(for actionData: ActionData) -> some View {
    // Determine icon based on measurements or default
    let icon: String = {
        if let firstMeasurement = actionData.measurements.first {
            // Map measure types to SF Symbols
            switch firstMeasurement.measureUnit {
            case "km", "miles": return "figure.run"
            case "kg", "lbs": return "dumbbell.fill"
            case "pages": return "book.fill"
            case "min", "hours": return "clock.fill"
            default: return "checkmark.circle.fill"
            }
        }
        return "checkmark.circle.fill"
    }()

    // Determine color based on linked goal (first contribution)
    let borderColor: Color = {
        if let firstContribution = actionData.contributions.first {
            // Find the goal in dataStore to get consistent color
            if let goal = dataStore.goals.first(where: { $0.id == firstContribution.goalId }) {
                let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
                let colorIndex = abs(goal.id.hashValue) % colors.count
                return colors[colorIndex]
            }
        }
        return .gray
    }()

    return HStack(spacing: 12) {
        // Icon
        Image(systemName: icon)
            .font(.title3)
            .foregroundStyle(borderColor)
            .frame(width: 40, height: 40)
            .background(borderColor.opacity(0.1))
            .clipShape(Circle())

        // Content
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(actionData.title ?? "Untitled Action")
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                // Show first measurement if available
                if let firstMeasurement = actionData.measurements.first {
                    Text("\(Int(firstMeasurement.value)) \(firstMeasurement.measureUnit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Goal badge (first contribution)
            if let firstContribution = actionData.contributions.first,
               let goal = dataStore.goals.first(where: { $0.id == firstContribution.goalId }) {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption2)
                    Text(goal.title ?? "Untitled Goal")
                        .font(.caption)
                }
                .foregroundStyle(borderColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(borderColor.opacity(0.1))
                .clipShape(Capsule())
            }
        }

        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(borderColor.opacity(0.05))
    .overlay(
        Rectangle()
            .fill(borderColor)
            .frame(width: 3),
        alignment: .leading
    )
    .onTapGesture {
        actionToEdit = actionData
    }
}
```

---

### **2. Update Recent Actions Section**

Replace the placeholder loop with real data:

```swift
private var recentActionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Text("Recent Actions")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Button(action: {}) {
                Text("View All")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)

        // Action list (real data from DataStore)
        if dataStore.actions.isEmpty {
            Text("No actions logged yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(dataStore.actions.prefix(7).enumerated()), id: \.element.id) { index, actionData in
                    actionRow(for: actionData)

                    if index < min(6, dataStore.actions.count - 1) {
                        Divider()
                            .padding(.leading, 20)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
        }
    }
    .padding(.bottom, 20)
}
```

---

### **3. Add Edit Sheet for Actions**

Already added, but ensure it's wired correctly:

```swift
.sheet(item: $actionToEdit) { actionData in
    NavigationStack {
        ActionFormView(actionToEdit: actionData)
    }
}
// NO onDismiss needed - DataStore updates automatically!
```

---

### **4. Computed Properties in DataStore**

The `activeGoals` computed property exists but is currently returning all goals:

```swift
// In DataStore.swift
public var activeGoals: [GoalData] {
    // TODO: Filter by status/date when we add those fields
    goals
}
```

**Enhancement needed** (future PR):
```swift
public var activeGoals: [GoalData] {
    goals.filter { goalData in
        // Use ActiveStatusService for consistent logic
        let service = ActiveStatusService()
        return service.isGoalActive(
            goalId: goalData.id,
            startDate: goalData.startDate,
            targetDate: goalData.targetDate,
            termStatus: goalData.termAssignment?.status,
            currentDate: Date()
        )
    }
}
```

**Also add**:
```swift
public var recentActions: [ActionData] {
    // Sort by logTime descending (most recent first)
    actions.sorted { $0.logTime > $1.logTime }
}
```

Then update HomeView to use `dataStore.recentActions.prefix(7)`.

---

## Preview Updates

Update the previews to inject a DataStore with sample data:

```swift
#Preview("Home - With Data") {
    let dataStore = DataStore()

    // Manually populate for preview
    // (In real app, DataStore observes database via ValueObservation)
    dataStore.goals = [
        // Sample GoalData instances
    ]
    dataStore.actions = [
        // Sample ActionData instances
    ]

    return HomeView()
        .environment(dataStore)
}

#Preview("Home - Empty State") {
    let dataStore = DataStore()
    // Don't populate - show empty state

    return HomeView()
        .environment(dataStore)
}

#Preview("Home - With Tab Bar") {
    let dataStore = DataStore()

    // Sample data
    dataStore.goals = [/* ... */]
    dataStore.actions = [/* ... */]

    return TabView {
        HomeView()
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

        Text("Plans")
            .tabItem {
                Label("Plans", systemImage: "list.bullet.clipboard")
            }

        Text("Search")
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
    }
    .environment(dataStore)
}
```

---

## Benefits of This Refactor

### **1. Consistency**
- HomeView uses same pattern as GoalsListView, ActionsListView, etc.
- Single source of truth (DataStore) across entire app

### **2. Declarative**
- No manual refresh calls
- UI automatically updates when data changes
- Truly reactive SwiftUI

### **3. Maintainability**
- Less code (no separate ViewModel)
- Easier to test (mock DataStore, not multiple ViewModels)
- Clear data flow (DataStore → View)

### **4. Performance**
- ValueObservation handles database changes efficiently
- No N+1 queries (GRDB tracks dependencies)
- Only re-renders when observed data changes

---

## Implementation Steps

1. ✅ Add `@Environment(DataStore.self)` to HomeView
2. ✅ Add state for sheets (`showingLogAction`, `actionToEdit`)
3. ✅ Update `activeGoalsSection` to use `dataStore.activeGoals`
4. ✅ Update `quickActionButton` to open `ActionFormView`
5. ⏳ **Update `recentActionsSection` to use `dataStore.actions`**
6. ⏳ **Replace `goalCardPlaceholder` with `goalCard(for:)`**
7. ⏳ **Replace `actionRowPlaceholder` with `actionRow(for:)`**
8. ⏳ **Add edit sheet for actions**
9. ⏳ **Update previews with sample data**
10. ⏳ **Test in Xcode preview**

---

## Next Steps

After HomeView refactor is complete:

1. **Add progress tracking**: Wire up `ProgressCalculationService` to show real progress percentages
2. **Enhance activeGoals filter**: Use `ActiveStatusService` for proper filtering
3. **Add Foundation Model greeting**: Generate personalized greeting based on goals + actions
4. **Create PlansView**: Use same DataStore pattern with horizontal carousels

---

## Files to Modify

- `swift/Sources/App/Views/HomeView.swift` (complete refactor)
- `swift/Sources/App/DataStore.swift` (add `recentActions` computed property)

---

## Testing Checklist

- [ ] Preview shows empty state when no data
- [ ] Preview shows goal cards when goals exist
- [ ] Preview shows action rows when actions exist
- [ ] Tap goal card (placeholder action for now)
- [ ] Tap "Log an Action" opens ActionFormView
- [ ] Tap action row opens ActionFormView in edit mode
- [ ] Colors are consistent (goals and actions use same color mapping)
- [ ] Hero image fades on scroll
- [ ] Greeting text is readable over image
- [ ] All sections have proper spacing

---

**Status**: Partially complete - needs placeholder replacement
**Priority**: High (foundational for new nav architecture)
**Blocked by**: None (DataStore already implemented)
