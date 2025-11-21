# Declarative Patterns Analysis & Refactoring Plan

**Created**: 2025-11-20
**Target**: iOS 26+, macOS 26+, visionOS 26+ (Swift 6.2)
**Status**: Analysis Complete, Implementation Ready

## Executive Summary

The codebase is **already quite modern and declarative** following the recent DataStore and @Observable migrations. This analysis identifies 8 specific opportunities to further improve declarative patterns, leveraging Apple's 2026 SDK capabilities.

### Key Findings

- ✅ **Strong Foundation**: DataStore pattern, @Observable ViewModels, Repository abstraction
- 🔄 **Refinement Opportunities**: State consolidation, binding patterns, environment-based state
- 📚 **Reference Implementations**: Several views already demonstrate best practices

---

## Priority 1: High-Impact Refactorings

### 1.1 MetricTargetRow State Consolidation

**File**: `swift/Sources/App/Views/Components/FormComponents/MetricTargetRow.swift`

**Current Issue**: 4 separate @State properties for measure creation:
```swift
@State private var showingCreateMeasure = false
@State private var newMeasureUnit = ""
@State private var newMeasureTitle = ""
@State private var newMeasureType = "distance"
@State private var isCreating = false
```

**Declarative Solution**:
```swift
// Define form data structure
struct CreateMeasureFormData {
    var unit: String = ""
    var title: String = ""
    var measureType: String = "distance"

    var isValid: Bool {
        !unit.isEmpty
    }
}

// Single state property
@State private var createMeasureForm = CreateMeasureFormData()
@State private var showingCreateMeasure = false
@State private var isCreating = false
@FocusState private var focusedField: CreateMeasureField?

// Computed property for validation
var canCreateMeasure: Bool {
    createMeasureForm.isValid && !isCreating
}
```

**Benefits**:
- Single source of truth for form state
- Validation logic in one place
- Easier to test form logic
- Better type safety

**Impact**: Medium effort, high maintainability gain

---

### 1.2 Error Alert Environment Pattern

**Files**: `ActionsListView.swift`, `GoalsListView.swift`, `PersonalValuesListView.swift`, `TermsListView.swift`

**Current Issue**: Repeated error alert pattern across 4+ views:
```swift
.alert("Error", isPresented: .constant(dataStore.errorMessage != nil)) {
    Button("OK") {
        // Can't mutate dataStore directly
    }
} message: {
    Text(dataStore.errorMessage ?? "Unknown error")
}
```

**Declarative Solution**:

Create an enhanced error presentation system:

```swift
// 1. Define error state environment key
private struct ErrorStateKey: EnvironmentKey {
    static let defaultValue: Binding<ErrorState?> = .constant(nil)
}

extension EnvironmentValues {
    var errorState: Binding<ErrorState?> {
        get { self[ErrorStateKey.self] }
        set { self[ErrorStateKey.self] = newValue }
    }
}

// 2. Create reusable modifier
struct ErrorAlertModifier: ViewModifier {
    @Binding var errorMessage: String?

    func body(content: Content) -> some View {
        content.alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }
}

extension View {
    func errorAlert(_ errorMessage: Binding<String?>) -> some View {
        modifier(ErrorAlertModifier(errorMessage: errorMessage))
    }
}

// 3. Usage in views
// Option A: Direct binding (if DataStore becomes @Observable properly)
.errorAlert($dataStore.errorMessage)

// Option B: Create local binding (current workaround)
@State private var localError: String?
.errorAlert($localError)
.onChange(of: dataStore.errorMessage) { _, newValue in
    localError = newValue
}
```

**Benefits**:
- DRY principle (4 views → 1 modifier)
- Consistent error UX across app
- Easy to enhance globally (add logging, analytics, etc.)

**Impact**: Low effort, high consistency gain

---

### 1.3 Binding Helpers Migration to Extensions

**File**: `swift/Sources/App/Views/FormViews/ActionFormView.swift`

**Current Issue**: Complex binding creation function in view:
```swift
private func bindingForMeasurement(_ id: UUID) -> (measureId: Binding<UUID?>, value: Binding<Double>) {
    guard let index = measurements.firstIndex(where: { $0.id == id }) else {
        return (.constant(nil), .constant(0))
    }

    return (
        measureId: Binding(
            get: { measurements[index].measureId },
            set: { measurements[index].measureId = $0 }
        ),
        value: Binding(...)
    )
}
```

**Declarative Solution**:

Use SwiftUI's built-in `$collection[index]` binding:

```swift
// In view - direct binding access
ForEach($measurements) { $measurement in
    MeasurementInputRow(
        measurement: $measurement,
        availableMeasures: availableMeasures,
        onRemove: { removeMeasurement(id: measurement.id) }
    )
}

// Or if you need keyed access, create extension
extension Binding where Value: RandomAccessCollection, Value.Element: Identifiable {
    subscript(id id: Value.Element.ID) -> Binding<Value.Element>? {
        guard let index = wrappedValue.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return self[index]
    }
}

// Usage
if let binding = $measurements[id: measurementId] {
    MeasurementInputRow(measurement: binding, ...)
}
```

**Benefits**:
- More idiomatic SwiftUI
- Less indirection
- Better type inference
- Compiler-checked binding safety

**Impact**: Medium effort, moderate clarity gain

---

## Priority 2: Medium-Impact Refactorings

### 2.1 GoalCoachView Scroll Handling

**File**: `swift/Sources/App/Views/LLM/GoalCoachView.swift`

**Current Issue**: Imperative onChange for scrolling:
```swift
.onChange(of: viewModel.messages.last?.id) { _, _ in
    if let lastMessage = viewModel.messages.last {
        withAnimation {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}
```

**Declarative Solution**:

Create computed property for scroll target:

```swift
var scrollTarget: UUID? {
    viewModel.messages.last?.id
}

// In body
ScrollViewReader { proxy in
    ScrollView {
        // content
    }
    .onChange(of: scrollTarget) { _, newTarget in
        guard let target = newTarget else { return }
        withAnimation {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }
}
```

Or use iOS 26+ declarative scroll position:

```swift
@State private var scrollPosition: ScrollPosition = .bottom

ScrollView {
    // content
}
.scrollPosition($scrollPosition)
.onChange(of: viewModel.messages.count) { _, _ in
    scrollPosition = .bottom  // Declaratively set target
}
```

**Benefits**:
- Clearer intent (scroll target is computed state)
- Less nested optional handling
- Platform-appropriate scroll behavior

**Impact**: Low effort, moderate clarity gain

---

### 2.2 HomeView Placeholder Structure

**File**: `swift/Sources/App/Views/HomeView.swift`

**Current Issue**: Index-based placeholder generation:
```swift
ForEach(0..<5) { index in
    goalCardPlaceholder(index: index)
}

private func goalCardPlaceholder(index: Int) -> some View {
    let icons = ["target", "book.fill", "figure.run", "leaf.fill", "star.fill"]
    let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
    // Array index lookups...
}
```

**Declarative Solution**:

Define structured placeholder data:

```swift
struct GoalPlaceholder: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let progress: Double
    let subtitle: String
}

private let goalPlaceholders: [GoalPlaceholder] = [
    GoalPlaceholder(
        icon: "target",
        color: .blue,
        title: "Marathon Training",
        progress: 0.65,
        subtitle: "120 km / 185 km"
    ),
    GoalPlaceholder(
        icon: "book.fill",
        color: .green,
        title: "Read 12 Books",
        progress: 0.42,
        subtitle: "5 / 12 books"
    ),
    // ... rest of data
]

// In view
ForEach(goalPlaceholders) { placeholder in
    goalCardView(for: placeholder)
}

private func goalCardView(for placeholder: GoalPlaceholder) -> some View {
    // Use placeholder properties directly
}
```

**Benefits**:
- No magic indices
- Easy to add/remove/reorder
- Self-documenting data structure
- Testable placeholder data

**Impact**: Low effort, moderate maintainability gain

---

### 2.3 GoalCoachViewModel Logging Abstraction

**File**: `swift/Sources/App/ViewModels/LLMViewModels/GoalCoachViewModel.swift`

**Current Issue**: Imperative string construction for logging:
```swift
let totalMessageLength = messages.map { $0.content.count }.reduce(0, +)
let estimatedTokens = totalMessageLength / 4
print("📊 Context estimate: \(messages.count) messages, ~\(estimatedTokens) tokens")

print("\n" + String(repeating: "=", count: 80))
print("📨 USER MESSAGE #\(messages.count + 1)")
print(String(repeating: "=", count: 80))
```

**Declarative Solution**:

Create computed properties and structured logging:

```swift
// Computed context metrics
var estimatedTokenCount: Int {
    messages.reduce(0) { $0 + $1.content.count } / 4
}

var contextSummary: String {
    "\(messages.count) messages, ~\(estimatedTokenCount) tokens"
}

// Structured logging service
private func log(_ event: LogEvent) {
    switch event {
    case .contextEstimate:
        logger.debug("📊 Context: \(contextSummary)")
    case .userMessage(let number):
        logger.debug("📨 USER MESSAGE #\(number)")
    case .assistantResponse:
        logger.debug("🤖 ASSISTANT RESPONSE")
    }
}

// Usage
log(.contextEstimate)
log(.userMessage(messages.count + 1))
```

**Benefits**:
- Separates concerns (business logic vs logging)
- Reusable across multiple ViewModels
- Easier to test without logging noise
- Can add analytics/telemetry later

**Impact**: Low effort, low-medium maintainability gain

---

## Priority 3: Incremental Improvements

### 3.1 GoalFormView Value Toggle Binding

**File**: `swift/Sources/App/Views/FormViews/GoalFormView.swift`

**Current Pattern**:
```swift
Toggle(isOn: Binding(
    get: { model.selectedValueIds.contains(value.id) },
    set: { _ in model.toggleValue(value.id) }
)) {
    Text(value.title ?? "Untitled Value")
}
```

**Declarative Solution**:

Move binding creation to model:

```swift
// In GoalFormModel
func binding(for valueId: UUID) -> Binding<Bool> {
    Binding(
        get: { selectedValueIds.contains(valueId) },
        set: { isSelected in
            if isSelected {
                selectedValueIds.insert(valueId)
            } else {
                selectedValueIds.remove(valueId)
            }
        }
    )
}

// In view (cleaner)
Toggle(isOn: model.binding(for: value.id)) {
    Text(value.title ?? "Untitled Value")
}
```

**Benefits**:
- View is simpler
- Model owns all state logic
- Easier to test toggle behavior

**Impact**: Low effort, low-medium clarity gain

---

### 3.2 PersonalValuesListView Grouping

**File**: `swift/Sources/App/Views/ListViews/PersonalValuesListView.swift`

**Current Pattern**:
```swift
ForEach(ValueLevel.allCases, id: \.self) { level in
    let levelValues = dataStore.values.filter { $0.valueLevel == level.rawValue }
    if !levelValues.isEmpty {
        Section(level.displayName) {
            ForEach(levelValues) { valueData in
                // ...
            }
        }
    }
}
```

**Declarative Solution**:

Create computed grouping:

```swift
// Extension on Array
extension Array where Element == PersonalValueData {
    var groupedByLevel: [(ValueLevel, [PersonalValueData])] {
        let grouped = Dictionary(grouping: self) { value in
            ValueLevel(rawValue: value.valueLevel) ?? .general
        }
        return ValueLevel.allCases
            .compactMap { level in
                guard let values = grouped[level], !values.isEmpty else { return nil }
                return (level, values)
            }
    }
}

// In view
ForEach(dataStore.values.groupedByLevel, id: \.0) { level, levelValues in
    Section(level.displayName) {
        ForEach(levelValues) { valueData in
            // ...
        }
    }
}
```

**Benefits**:
- Reusable grouping logic
- Single pass through data
- Easier to test grouping
- Can be used in other views

**Impact**: Low effort, low maintainability gain

---

## Files Demonstrating Best Practices

These files already follow excellent declarative patterns and should be used as reference implementations:

### ✅ GoalsListView.swift
- Clean @ViewBuilder usage
- Excellent empty state handling
- Proper DataStore integration
- Declarative list structure

### ✅ MultiSelectSection.swift
- Generic, reusable component
- Proper binding patterns
- Clean separation of concerns

### ✅ RepeatingSection.swift
- Composable form section
- Declarative add/remove logic
- Good error state handling

### ✅ GoalFormModel.swift
- Single source of truth
- @Observable integration
- Clean computed properties
- Proper validation separation

### ✅ ActionFormView.swift
- Well-structured initialization
- Multiple mode support
- Clean form state management

---

## Cross-Cutting Patterns

### Pattern A: State Consolidation

**Principle**: Multiple related @State properties should be consolidated into a single struct.

**When to Use**:
- Form fields that validate together
- Related UI state (e.g., loading + error + data)
- Temporary editing state

**Example**:
```swift
// Before
@State private var field1 = ""
@State private var field2 = ""
@State private var isValid = false

// After
@State private var formData = FormData()

struct FormData {
    var field1: String = ""
    var field2: String = ""

    var isValid: Bool {
        !field1.isEmpty && !field2.isEmpty
    }
}
```

---

### Pattern B: Computed Properties over Functions

**Principle**: If a function just transforms state, make it a computed property.

**When to Use**:
- Derived state from @State/@Observable properties
- Validation flags
- View visibility conditions
- Formatted strings

**Example**:
```swift
// Before
func isFormValid() -> Bool {
    !title.isEmpty && targetValue > 0
}

// After
var isFormValid: Bool {
    !title.isEmpty && targetValue > 0
}
```

---

### Pattern C: Environment-Based State

**Principle**: Shared state across view hierarchy should use @Environment.

**When to Use**:
- Error presentation
- Theme/appearance settings
- User preferences
- Global app state

**Example**:
```swift
// Define key
private struct ErrorStateKey: EnvironmentKey {
    static let defaultValue: Binding<String?> = .constant(nil)
}

// Extend EnvironmentValues
extension EnvironmentValues {
    var errorState: Binding<String?> {
        get { self[ErrorStateKey.self] }
        set { self[ErrorStateKey.self] = newValue }
    }
}

// Use in views
@Environment(\.errorState) private var errorState
```

---

### Pattern D: ViewBuilder Composition

**Principle**: Complex view logic should be extracted into @ViewBuilder functions or separate views.

**When to Use**:
- Repeated UI patterns
- Conditional rendering with multiple branches
- List row/card templates

**Example**:
```swift
// Before
var body: some View {
    List {
        if condition1 {
            // 20 lines
        } else if condition2 {
            // 20 lines
        } else {
            // 20 lines
        }
    }
}

// After
var body: some View {
    List {
        contentView
    }
}

@ViewBuilder
private var contentView: some View {
    if condition1 {
        view1
    } else if condition2 {
        view2
    } else {
        view3
    }
}
```

---

## Implementation Plan

### Phase 1: High-Impact (Week 1)
1. ✅ Create this analysis document
2. ⏳ Refactor MetricTargetRow state consolidation
3. ⏳ Extract error alert modifier
4. ⏳ Migrate binding helpers to extensions

**Estimated effort**: 4-6 hours
**Expected benefit**: Significant maintainability improvement

### Phase 2: Medium-Impact (Week 2)
5. ⏳ Refactor GoalCoachView scroll handling
6. ⏳ Extract HomeView placeholder data
7. ⏳ Abstract GoalCoachViewModel logging

**Estimated effort**: 3-4 hours
**Expected benefit**: Moderate clarity improvement

### Phase 3: Incremental (Ongoing)
8. ⏳ Refactor GoalFormView value bindings
9. ⏳ Extract PersonalValuesListView grouping
10. Apply patterns to new code as written

**Estimated effort**: 2-3 hours
**Expected benefit**: Consistency across codebase

---

## Testing Strategy

For each refactoring:

1. **Before**: Note current behavior in tests
2. **During**: Maintain existing functionality
3. **After**: Verify no regressions
4. **Enhance**: Add tests for new patterns

Example test cases:
- MetricTargetRow: Test form validation logic
- Error alerts: Test dismissal behavior
- Bindings: Test state synchronization
- Scroll handling: Test auto-scroll to latest message

---

## Validation Criteria

Each refactoring should achieve:

- ✅ **Declarative**: Express "what" not "how"
- ✅ **Single Source of Truth**: No duplicated state
- ✅ **Composable**: Reusable across contexts
- ✅ **Testable**: Logic separate from view rendering
- ✅ **Type-Safe**: Leverage Swift type system
- ✅ **Platform-Appropriate**: Use iOS 26+ APIs where available

---

## References

- [Swift Language Guide - Concurrency](file:///Users/davidwilliams/Coding/REFERENCE/documents/SwiftLanguage/02-LanguageGuide/18-Concurrency.md)
- [Apple HIG - Foundations](file:///Users/davidwilliams/Coding/REFERENCE/documents/hig_docs/foundations.md)
- [SwiftUI - Adopting Liquid Glass](file:///Users/davidwilliams/Coding/REFERENCE/documents/appleDeveloper/swiftui/adopting-liquid-glass.md)
- [Project - Concurrency Migration](file:///Users/davidwilliams/Coding/01_ACTIVE_PROJECTS/ten_week_goal_app/swift/docs/CONCURRENCY_MIGRATION_20251110.md)
- [Project - CLAUDE.md](file:///Users/davidwilliams/Coding/01_ACTIVE_PROJECTS/ten_week_goal_app/CLAUDE.md)

---

**Last Updated**: 2025-11-20
**Next Review**: After Phase 1 completion
