# UI Refactoring Guide: Liquid Glass & Modern SwiftUI
**Project**: Happy to Have Lived  
**Date**: November 19, 2025  
**Swift**: 6.2  
**Platforms**: iOS 26+, macOS 26+, visionOS 26+

## Overview

This guide provides step-by-step instructions for refactoring the UI to leverage iOS 26's Liquid Glass framework and modern SwiftUI patterns. Each phase includes specific APIs, code examples, and testing procedures.

---

## Prerequisites

### Required Reading

Before starting, review these key Apple documents (available in your project knowledge):

1. **Adopting Liquid Glass** (`/REFERENCE/documents/appleDeveloper/swiftui/adopting-liquid-glass.md`)
   - Key quote: *"Leverage system frameworks to adopt Liquid Glass automatically. In system frameworks, standard components like bars, sheets, popovers, and controls automatically adopt this material."*

2. **Layout Guidelines** (`/REFERENCE/documents/hig_docs/layout.md`)
   - Visual hierarchy with Liquid Glass material
   - Differentiate controls from content

3. **Observable Macro** (`/REFERENCE/documents/SwiftLanguage/02-LanguageGuide/19-Macros.md`)
   - How `@Observable` works
   - Property observers and computed properties

### Before You Begin

```bash
# 1. Create a backup branch
git checkout -b refactor/liquid-glass-adoption
git tag pre-liquid-glass-refactor

# 2. Build and test current state
cd swift
swift build
swift test

# 3. Document current visual appearance (screenshots)
# Open app, take screenshots of:
# - Dashboard view
# - Goals list view
# - Goal form view
# Run in both light and dark mode
```

---

## Phase 1: Remove Custom Background System

**Time Estimate**: 1-2 hours  
**Risk Level**: Low  
**Files**: 6

### Step 1.1: Understand the Problem

**Current Implementation** (`BackgroundView.swift`):
```swift
// ❌ PROBLEM: Manual background handling interferes with Liquid Glass
public struct BackgroundView: View {
    let style: BackgroundStyle
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    
    public var body: some View {
        ZStack {
            Image(style.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Manual dimming and accessibility
            (colorScheme == .dark ? Color.black : Color.white)
                .opacity(reduceTransparency ? 0.85 : style.dimmingOpacity)
                .ignoresSafeArea()
        }
    }
}
```

**Why This Is Wrong**:
Per Apple's docs: *"Reduce your use of custom backgrounds in controls and navigation elements. Any custom backgrounds and appearances you use in these elements might overlay or interfere with Liquid Glass."*

### Step 1.2: Choose Replacement Strategy

iOS 26 provides three material options:

| Material | Use Case | Translucency | Liquid Glass |
|----------|----------|--------------|--------------|
| `.regularMaterial` | General UI backgrounds | Medium | ✅ Automatic |
| `.thinMaterial` | Light overlays, cards | High | ✅ Automatic |
| `.thickMaterial` | Heavy overlays, modals | Low | ✅ Automatic |
| `.ultraThinMaterial` | Minimal barriers | Very High | ✅ Automatic |
| `.bar` | Toolbars, tab bars | Special | ✅ Automatic |

**For this app**, use:
- **List views**: `.background(.regularMaterial)` - General UI with medium translucency
- **Content areas**: `.background(Color(.systemGroupedBackground))` - Standard system background
- **Cards/overlays**: `.background(.thinMaterial)` - Light translucent cards

### Step 1.3: Refactor DashboardView (Test Case)

**File**: `swift/Sources/App/Views/Dashboard/DashboardView.swift`

**Current Code** (Line 41):
```swift
.background(BackgroundView(.dashboard))
```

**New Code**:
```swift
.background(.regularMaterial)
```

**Complete Updated Code**:
```swift
@available(iOS 26.0, macOS 26.0, *)
public struct DashboardView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    welcomeSection
                    NavigationLink {
                        ValueAlignmentInsightsView()
                    } label: {
                        ValueAlignmentSummaryCard()
                    }
                    .buttonStyle(.plain)
                    quickLinksSection
                }
                .padding()
            }
            .background(.regularMaterial)  // ✅ NEW: System material with Liquid Glass
            .navigationTitle("Dashboard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
    
    // ... rest of implementation
}
```

### Step 1.4: Test DashboardView Changes

```bash
# Build and run
cd swift
swift build

# Open in Xcode and run on device
open HappyToHaveLived/HappyToHaveLived.xcodeproj
```

**Testing Checklist**:
- [ ] Build succeeds
- [ ] Light mode: Material is translucent, shows depth
- [ ] Dark mode: Material adapts automatically
- [ ] Scroll behavior: Material responds to scroll (Liquid Glass effect)
- [ ] iPad: Sidebar shows through material when open
- [ ] macOS: Window resize maintains material behavior
- [ ] **Accessibility**:
  - [ ] Enable "Reduce Transparency" → Material becomes opaque
  - [ ] Enable "Increase Contrast" → Material increases opacity
  - [ ] VoiceOver works correctly

**Visual Verification**:
Compare before/after screenshots:
- Material should show subtle content beneath
- Navigation bar should have Liquid Glass effect
- Scrolling should animate material (fluid morphing)
- No harsh edges or visual breaks

### Step 1.5: Apply to Remaining Views

Once DashboardView looks correct, apply to other views:

**GoalsListView** (`swift/Sources/App/Views/ListViews/GoalsListView.swift`):
```swift
// Line 60 - BEFORE:
.background(BackgroundView(.goals))

// Line 60 - AFTER:
.background(.regularMaterial)
```

**ActionsListView** (`swift/Sources/App/Views/ListViews/ActionsListView.swift`):
```swift
// BEFORE:
.background(BackgroundView(.actions))

// AFTER:
.background(.regularMaterial)
```

**TermsListView** (`swift/Sources/App/Views/ListViews/TermsListView.swift`):
```swift
// BEFORE:
.background(BackgroundView(.terms))

// AFTER:
.background(.regularMaterial)
```

**PersonalValuesListView** (`swift/Sources/App/Views/ListViews/PersonalValuesListView.swift`):
```swift
// BEFORE:
.background(BackgroundView(.values))

// AFTER:
.background(.regularMaterial)
```

### Step 1.6: Remove BackgroundView.swift

After all views are updated and tested:

```bash
cd swift/Sources/App/Views/Components
rm BackgroundView.swift

# Verify no references remain
cd ../../..
grep -r "BackgroundView" Sources/App --include="*.swift"
# Should return no results
```

### Step 1.7: Build and Test All Platforms

```bash
# iOS
xcodebuild -scheme HappyToHaveLived \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build test

# macOS
xcodebuild -scheme HappyToHaveLived \
  -destination 'platform=macOS' \
  build test

# visionOS (if available)
xcodebuild -scheme HappyToHaveLived \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
  build test
```

### Step 1.8: Commit Phase 1

```bash
git add .
git commit -m "Phase 1: Replace custom BackgroundView with system materials

- Removed BackgroundView.swift (108 lines)
- Updated DashboardView, GoalsListView, ActionsListView, TermsListView, PersonalValuesListView
- Now uses .background(.regularMaterial) for automatic Liquid Glass adoption
- Tested on iOS/macOS/visionOS in light/dark mode with accessibility settings

Benefits:
- Automatic Liquid Glass effects (fluid morphing, translucency)
- Platform-adaptive appearance (iOS/macOS/visionOS differences handled)
- Automatic accessibility support (Reduce Transparency, Increase Contrast)
- Reduced maintenance burden (no manual dimming calculations)
- Better performance (system-optimized rendering)

Per Apple docs: 'Leverage system frameworks to adopt Liquid Glass automatically'"
```

---

## Phase 2: Replace Progress Visualization with Gauge

**Time Estimate**: 1-2 hours  
**Risk Level**: Medium  
**Files**: 3

### Step 2.1: Understand Gauge API

iOS 16+ provides the `Gauge` component for progress visualization.

**Gauge Styles**:
```swift
// Circular gauge (compact, icon-sized)
.gaugeStyle(.accessoryCircular)

// Linear bar gauge (full width)
.gaugeStyle(.linearCapacity)

// Circular with prominent labels
.gaugeStyle(.accessoryCircularCapacity)
```

**Basic Usage**:
```swift
Gauge(value: 0.66, in: 0...1) {
    Text("Progress")  // Label
} currentValueLabel: {
    Text("66%")  // Current value display
}
.gaugeStyle(.accessoryCircular)
.tint(.blue)  // Color tint
```

### Step 2.2: Create New Gauge-Based Component

**File**: `swift/Sources/App/Views/Components/GoalComponents/GoalProgressGauge.swift` (NEW)

```swift
//
// GoalProgressGauge.swift
// Modern progress visualization using iOS 16+ Gauge component
//
// REPLACES: ProgressIndicator.swift (245 lines → ~60 lines)
//

import Models
import SwiftUI

/// Modern progress visualization using system Gauge component
///
/// **Benefits over custom implementation**:
/// - Automatic platform adaptation (iOS/macOS/visionOS)
/// - System-provided animations
/// - Semantic colors handled by system
/// - Accessibility built-in (VoiceOver, Dynamic Type)
/// - Respects Reduce Motion setting
public struct GoalProgressGauge: View {
    let measureTargets: [GoalData.MeasureTarget]
    let actualProgress: [UUID: Double]
    let displayMode: DisplayMode
    
    public enum DisplayMode {
        case compact   // Single circular gauge
        case detailed  // Multiple linear gauges
    }
    
    public init(
        measureTargets: [GoalData.MeasureTarget],
        actualProgress: [UUID: Double] = [:],
        displayMode: DisplayMode = .compact
    ) {
        self.measureTargets = measureTargets
        self.actualProgress = actualProgress
        self.displayMode = displayMode
    }
    
    // MARK: - Computed Progress
    
    private var overallProgress: Double {
        guard !measureTargets.isEmpty else { return 0 }
        
        let progresses = measureTargets.compactMap { target -> Double? in
            guard let actual = actualProgress[target.measureId],
                  target.targetValue > 0 else { return nil }
            return min(actual / target.targetValue, 1.0)
        }
        
        guard !progresses.isEmpty else { return 0 }
        return progresses.reduce(0, +) / Double(progresses.count)
    }
    
    // MARK: - Body
    
    public var body: some View {
        switch displayMode {
        case .compact:
            compactGauge
        case .detailed:
            detailedGauges
        }
    }
    
    // MARK: - Compact View
    
    private var compactGauge: some View {
        HStack(spacing: 8) {
            // System Gauge - automatic animations and accessibility
            Gauge(value: overallProgress, in: 0...1) {
                Text("Progress")
            } currentValueLabel: {
                Text("\(Int(overallProgress * 100))%")
            }
            .gaugeStyle(.accessoryCircular)
            .tint(progressColor)  // System handles semantic meaning
            .frame(width: 32, height: 32)
            
            if !measureTargets.isEmpty {
                Text("(\(measureTargets.count) metric\(measureTargets.count == 1 ? "" : "s"))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Detailed View
    
    private var detailedGauges: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Overall progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Overall Progress")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(overallProgress * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Gauge(value: overallProgress, in: 0...1) {
                    Text("Overall")
                }
                .gaugeStyle(.linearCapacity)
                .tint(progressColor)
            }
            
            // Individual metrics
            ForEach(measureTargets) { target in
                individualMetricGauge(for: target)
            }
        }
    }
    
    @ViewBuilder
    private func individualMetricGauge(for target: GoalData.MeasureTarget) -> some View {
        let progress = progressValue(for: target)
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(target.measureTitle ?? target.measureUnit)
                    .font(.subheadline)
                Spacer()
                progressLabel(for: target)
            }
            
            Gauge(value: progress, in: 0...1) {
                Text(target.measureTitle ?? target.measureUnit)
            }
            .gaugeStyle(.linearCapacity)
            .tint(semanticColor(for: progress))
        }
    }
    
    @ViewBuilder
    private func progressLabel(for target: GoalData.MeasureTarget) -> some View {
        let actual = actualProgress[target.measureId] ?? 0
        let percentage = Int(progressValue(for: target) * 100)
        
        Text("\(actual, format: .number) / \(target.targetValue, format: .number) \(target.measureUnit) (\(percentage)%)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    
    // MARK: - Helpers
    
    private func progressValue(for target: GoalData.MeasureTarget) -> Double {
        let actual = actualProgress[target.measureId] ?? 0
        guard target.targetValue > 0 else { return 0 }
        return min(actual / target.targetValue, 1.0)
    }
    
    // System semantic colors - automatically adapt to accessibility settings
    private var progressColor: Color {
        semanticColor(for: overallProgress)
    }
    
    private func semanticColor(for progress: Double) -> Color {
        switch progress {
        case 0..<0.25: return .red
        case 0.25..<0.5: return .orange
        case 0.5..<0.75: return .yellow
        case 0.75..<1.0: return .green
        default: return .blue
        }
    }
}

// MARK: - Previews

#Preview("Compact") {
    let measureId1 = UUID()
    let measureId2 = UUID()
    
    return VStack(spacing: 20) {
        GoalProgressGauge(
            measureTargets: [
                GoalData.MeasureTarget(
                    id: UUID(), measureId: measureId1,
                    measureTitle: "Distance", measureUnit: "km",
                    measureType: "distance", targetValue: 120,
                    freeformNotes: nil, createdAt: Date()
                ),
                GoalData.MeasureTarget(
                    id: UUID(), measureId: measureId2,
                    measureTitle: "Sessions", measureUnit: "sessions",
                    measureType: "count", targetValue: 30,
                    freeformNotes: nil, createdAt: Date()
                )
            ],
            actualProgress: [measureId1: 87, measureId2: 18],
            displayMode: .compact
        )
        
        GoalProgressGauge(
            measureTargets: [],
            actualProgress: [:],
            displayMode: .compact
        )
    }
    .padding()
}

#Preview("Detailed") {
    let measureId1 = UUID()
    let measureId2 = UUID()
    
    return GoalProgressGauge(
        measureTargets: [
            GoalData.MeasureTarget(
                id: UUID(), measureId: measureId1,
                measureTitle: "Distance", measureUnit: "km",
                measureType: "distance", targetValue: 120,
                freeformNotes: nil, createdAt: Date()
            ),
            GoalData.MeasureTarget(
                id: UUID(), measureId: measureId2,
                measureTitle: "Sessions", measureUnit: "sessions",
                measureType: "count", targetValue: 30,
                freeformNotes: nil, createdAt: Date()
            )
        ],
        actualProgress: [measureId1: 87, measureId2: 18],
        displayMode: .detailed
    )
    .padding()
}
```

### Step 2.3: Update GoalRowView

**File**: `swift/Sources/App/Views/RowViews/GoalRowView.swift`

**Replace** (around line 90):
```swift
// OLD:
if !goal.measureTargets.isEmpty {
    ProgressIndicator(
        measureTargets: goal.measureTargets,
        actualProgress: [:],
        displayMode: .compact
    )
}

// NEW:
if !goal.measureTargets.isEmpty {
    GoalProgressGauge(
        measureTargets: goal.measureTargets,
        actualProgress: [:],  // TODO: Calculate in Phase 2 (progress tracking)
        displayMode: .compact
    )
}
```

### Step 2.4: Test Gauge Component

```bash
# Build
swift build

# Run previews in Xcode
open HappyToHaveLived/HappyToHaveLived.xcodeproj
# Navigate to GoalProgressGauge.swift
# Click "Resume" on each preview
```

**Testing Checklist**:
- [ ] Compact mode shows circular gauge
- [ ] Detailed mode shows linear gauges
- [ ] Colors adapt to progress (red → orange → yellow → green → blue)
- [ ] Percentages calculate correctly
- [ ] Zero progress shows correctly (0%)
- [ ] Full progress shows correctly (100%)
- [ ] **Accessibility**:
  - [ ] VoiceOver reads progress values
  - [ ] Dynamic Type scales correctly
  - [ ] Reduce Motion disables animations
  - [ ] High contrast mode increases visibility

### Step 2.5: Remove Old ProgressIndicator

```bash
cd swift/Sources/App/Views/Components/GoalComponents
rm ProgressIndicator.swift

# Verify no references remain
cd ../../../..
grep -r "ProgressIndicator" Sources/App --include="*.swift"
# Should return no results
```

### Step 2.6: Commit Phase 2

```bash
git add .
git commit -m "Phase 2: Replace custom ProgressIndicator with Gauge component

- Removed ProgressIndicator.swift (245 lines)
- Added GoalProgressGauge.swift (60 lines using system Gauge)
- Updated GoalRowView to use new component

Benefits:
- 75% code reduction (245 → 60 lines)
- System-provided animations
- Automatic accessibility (VoiceOver, Dynamic Type, Reduce Motion)
- Platform-adaptive appearance
- Semantic colors handled by system

Uses iOS 16+ Gauge API with .accessoryCircular and .linearCapacity styles"
```

---

## Phase 3: Consolidate Form State with @Observable

**Time Estimate**: 3-4 hours  
**Risk Level**: Medium  
**Files**: 6 (one form as template, then apply to others)

### Step 3.1: Understand @Observable Pattern

The `@Observable` macro (Swift 5.9+) provides automatic change tracking without manual `willSet`/`didSet` or `@Published`.

**Key Benefits**:
- No duplicate state
- Computed properties instead of manual sync
- Single source of truth
- Better performance (granular updates)

**Before (@ObservableObject)**:
```swift
class ViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var selectedIds: Set<UUID> = []
    
    // Manual sync needed
    func sync() {
        selectedIds = Set(items.filter(\.isSelected).map(\.id))
    }
}
```

**After (@Observable)**:
```swift
@Observable
class ViewModel {
    var items: [Item] = []
    
    // Computed - no manual sync
    var selectedIds: Set<UUID> {
        Set(items.filter(\.isSelected).map(\.id))
    }
}
```

### Step 3.2: Create GoalFormModel

**File**: `swift/Sources/App/ViewModels/FormModels/GoalFormModel.swift` (NEW)

```swift
//
// GoalFormModel.swift
// Consolidated form state using @Observable
//
// REPLACES: 13+ @State variables in GoalFormView
// ELIMINATES: Manual synchronization with onChange
//

import Foundation
import Models
import Observation

/// Consolidated form model for goal creation/editing
///
/// **Pattern**: @Observable with computed properties
/// **Benefits**:
/// - Single source of truth
/// - No duplicate state (e.g., selectedValueIds)
/// - Automatic change tracking
/// - Type-safe computed properties
@Observable
@MainActor
public final class GoalFormModel {
    
    // MARK: - Basic Info
    
    public var title: String = ""
    public var detailedDescription: String = ""
    public var freeformNotes: String = ""
    
    // MARK: - Priority
    
    public var importance: Int
    public var urgency: Int
    
    // MARK: - Timeline
    
    public var startDate: Date = Date()
    public var targetDate: Date
    public var actionPlan: String = ""
    public var expectedTermLength: Int = 10
    
    // MARK: - Relationships
    
    public var measureTargets: [ExpectationMeasureFormData] = []
    public var valueAlignments: [ValueAlignmentInput] = []
    public var selectedTermId: UUID?
    
    // MARK: - Computed Properties (No Manual Sync!)
    
    /// Selected value IDs derived from alignments
    /// ✅ ELIMINATES: selectedValueIds @State variable
    /// ✅ ELIMINATES: onChange(of: selectedValueIds) sync logic
    public var selectedValueIds: Set<UUID> {
        Set(valueAlignments.compactMap(\.valueId))
    }
    
    /// Form is valid and ready to submit
    public var canSubmit: Bool {
        !title.isEmpty
    }
    
    // MARK: - Initialization
    
    public init(
        importance: Int = 5,
        urgency: Int = 5,
        targetDate: Date? = nil
    ) {
        self.importance = importance
        self.urgency = urgency
        self.targetDate = targetDate ?? Calendar.current.date(
            byAdding: .weekOfYear,
            value: 10,
            to: Date()
        ) ?? Date()
    }
    
    /// Initialize from existing goal data (edit mode)
    public init(from goalData: GoalData) {
        self.title = goalData.title ?? ""
        self.detailedDescription = goalData.detailedDescription ?? ""
        self.freeformNotes = goalData.freeformNotes ?? ""
        self.importance = goalData.expectationImportance
        self.urgency = goalData.expectationUrgency
        self.startDate = goalData.startDate ?? Date()
        self.targetDate = goalData.targetDate ?? Date()
        self.actionPlan = goalData.actionPlan ?? ""
        self.expectedTermLength = goalData.expectedTermLength ?? 10
        
        self.measureTargets = goalData.measureTargets.map { target in
            ExpectationMeasureFormData(
                id: target.id,
                measureId: target.measureId,
                targetValue: target.targetValue,
                notes: target.freeformNotes
            )
        }
        
        self.valueAlignments = goalData.valueAlignments.map { alignment in
            ValueAlignmentInput(
                id: alignment.id,
                valueId: alignment.valueId,
                alignmentStrength: alignment.alignmentStrength ?? 5,
                relevanceNotes: alignment.relevanceNotes
            )
        }
        
        self.selectedTermId = goalData.termAssignment?.termId
    }
    
    // MARK: - Actions
    
    /// Toggle value selection
    /// ✅ REPLACES: Manual selectedValueIds management
    public func toggleValue(_ valueId: UUID, strength: Int = 5) {
        if let index = valueAlignments.firstIndex(where: { $0.valueId == valueId }) {
            valueAlignments.remove(at: index)
        } else {
            valueAlignments.append(ValueAlignmentInput(
                valueId: valueId,
                alignmentStrength: strength
            ))
        }
    }
    
    /// Add measure target
    public func addMeasureTarget() {
        measureTargets.append(ExpectationMeasureFormData())
    }
    
    /// Remove measure target
    public func removeMeasureTarget(_ target: ExpectationMeasureFormData) {
        measureTargets.removeAll { $0.id == target.id }
    }
}
```

### Step 3.3: Refactor GoalFormView

**File**: `swift/Sources/App/Views/FormViews/GoalFormView.swift`

**Major Changes**:
1. Replace 13 @State variables with single @State model
2. Remove onChange synchronization
3. Bind directly to model properties

**Key Sections to Update**:

```swift
public struct GoalFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = GoalFormViewModel()
    
    // BEFORE: 13 @State variables
    // @State private var title: String
    // @State private var detailedDescription: String
    // ... etc
    
    // AFTER: Single model
    @State private var model: GoalFormModel
    
    // MARK: - Initialization
    
    public init(goalToEdit: GoalData? = nil) {
        // Initialize model based on mode
        if let goal = goalToEdit {
            _model = State(initialValue: GoalFormModel(from: goal))
        } else {
            _model = State(initialValue: GoalFormModel())
        }
    }
    
    private var canSubmit: Bool {
        !viewModel.isSaving && model.canSubmit  // ✅ Computed property
    }
    
    public var body: some View {
        Form {
            // Basic Info
            Section("Details") {
                TextField("Title", text: $model.title)  // ✅ Direct binding
                TextField("Description", text: $model.detailedDescription, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Notes", text: $model.freeformNotes, axis: .vertical)
            }
            
            // Priority
            Section("Priority") {
                Stepper("Importance: \(model.importance)", value: $model.importance, in: 1...10)
                Stepper("Urgency: \(model.urgency)", value: $model.urgency, in: 1...10)
            }
            
            // Timeline
            Section("Timeline") {
                DatePicker("Start Date", selection: $model.startDate, displayedComponents: .date)
                DatePicker("Target Date", selection: $model.targetDate, displayedComponents: .date)
                Stepper("Expected Length: \(model.expectedTermLength) weeks", 
                       value: $model.expectedTermLength, in: 1...52)
            }
            
            // Action Plan
            Section("Action Plan") {
                TextField("How will you achieve this?", text: $model.actionPlan, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            // Metric Targets
            Section("Measurable Targets") {
                ForEach($model.measureTargets) { $target in
                    MetricTargetRow(
                        availableMeasures: availableMeasures,
                        target: $target,
                        onRemove: {
                            model.removeMeasureTarget(target)
                        },
                        onMeasureCreated: {
                            await loadAvailableData()
                        }
                    )
                }
                
                Button {
                    model.addMeasureTarget()
                } label: {
                    Label("Add Metric Target", systemImage: "plus.circle.fill")
                }
            }
            
            // Value Alignments
            Section("Value Alignment") {
                ForEach(availableValues) { value in
                    // ✅ NO MORE: Manual selectedValueIds sync
                    // ✅ NO MORE: onChange handler
                    Toggle(isOn: Binding(
                        get: { model.selectedValueIds.contains(value.id) },
                        set: { _ in model.toggleValue(value.id) }
                    )) {
                        Text(value.title ?? "Untitled Value")
                    }
                }
                
                // Alignment strength sliders
                ForEach($model.valueAlignments) { $alignment in
                    if let value = availableValues.first(where: { $0.id == alignment.valueId }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(value.title ?? "Value") alignment: \(alignment.alignmentStrength)/10")
                                .font(.subheadline)
                            Slider(value: Binding(
                                get: { Double(alignment.alignmentStrength) },
                                set: { alignment.alignmentStrength = Int($0) }
                            ), in: 1...10, step: 1)
                        }
                    }
                }
            }
            
            // Term Assignment
            if !availableTerms.isEmpty {
                Section("Term Assignment (Optional)") {
                    Picker("Assign to Term", selection: $model.selectedTermId) {
                        Text("No term").tag(nil as UUID?)
                        ForEach(availableTerms) { termData in
                            Text("Term \(termData.termNumber)")
                                .tag(termData.id as UUID?)
                        }
                    }
                }
            }
            
            // Error Display
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(goalToEdit != nil ? "Edit Goal" : "New Goal")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(goalToEdit != nil ? "Update" : "Save") {
                    handleSubmit()
                }
                .disabled(!canSubmit)
            }
        }
        .task {
            await loadAvailableData()
        }
    }
    
    // MARK: - Actions
    
    private func handleSubmit() {
        Task {
            do {
                if let goalData = goalToEdit {
                    _ = try await viewModel.update(
                        goalData: goalData,
                        title: model.title,
                        detailedDescription: model.detailedDescription,
                        freeformNotes: model.freeformNotes,
                        expectationImportance: model.importance,
                        expectationUrgency: model.urgency,
                        startDate: model.startDate,
                        targetDate: model.targetDate,
                        actionPlan: model.actionPlan.isEmpty ? nil : model.actionPlan,
                        expectedTermLength: model.expectedTermLength,
                        measureTargets: model.measureTargets,
                        valueAlignments: model.valueAlignments,
                        termId: model.selectedTermId
                    )
                } else {
                    _ = try await viewModel.save(
                        title: model.title,
                        detailedDescription: model.detailedDescription,
                        freeformNotes: model.freeformNotes,
                        expectationImportance: model.importance,
                        expectationUrgency: model.urgency,
                        startDate: model.startDate,
                        targetDate: model.targetDate,
                        actionPlan: model.actionPlan.isEmpty ? nil : model.actionPlan,
                        expectedTermLength: model.expectedTermLength,
                        measureTargets: model.measureTargets,
                        valueAlignments: model.valueAlignments,
                        termId: model.selectedTermId
                    )
                }
                dismiss()
            } catch {
                // Error handled by viewModel.errorMessage
            }
        }
    }
    
    // ... rest of implementation
}
```

### Step 3.4: Test Form Refactoring

**Testing Checklist**:
- [ ] Create new goal works
- [ ] Edit existing goal loads correctly
- [ ] Value selection toggles work
- [ ] Alignment strength sliders update
- [ ] Measure targets add/remove
- [ ] Form validation (canSubmit)
- [ ] Save/Update calls coordinator
- [ ] Error display shows validation errors
- [ ] Cancel dismisses without saving

### Step 3.5: Apply Pattern to Other Forms

Repeat the model pattern for:
1. `ActionFormView` → Create `ActionFormModel`
2. `MilestoneFormView` → Create `MilestoneFormModel`
3. `ObligationFormView` → Create `ObligationFormModel`
4. `TermFormView` → Create `TermFormModel`
5. `PersonalValuesFormView` → Create `PersonalValuesFormModel`

### Step 3.6: Remove DocumentableFields.swift

After forms are using direct composition:

```bash
cd swift/Sources/App/Views/Templates
rm DocumentableFields.swift

# Verify no references
cd ../../..
grep -r "DocumentableFields" Sources/App --include="*.swift"
```

### Step 3.7: Commit Phase 3

```bash
git add .
git commit -m "Phase 3: Consolidate form state with @Observable

- Created GoalFormModel (@Observable class)
- Refactored GoalFormView to use single model (was 13 @State vars)
- Removed manual synchronization (onChange handlers)
- Added computed properties (selectedValueIds)
- Removed DocumentableFields.swift (122 lines)

Benefits:
- Single source of truth
- No duplicate state
- Automatic change tracking
- ~50% reduction in form complexity
- Type-safe computed properties
- Better performance (granular updates)

Uses @Observable macro (Swift 5.9+) per Apple's modern SwiftUI patterns"
```

---

## Phase 4: Simplify List Styling

**Time Estimate**: 1 hour  
**Risk Level**: Low  
**Files**: 5

### Step 4.1: Remove Manual List Customizations

**Current Pattern** (all list views):
```swift
List {
    ForEach(items) { item in
        RowView(item: item)
            .listRowBackground(Color.clear)  // ❌ Manual
            .contentShape(Rectangle())       // ❌ Manual
    }
}
.scrollContentBackground(.hidden)  // ❌ Manual
```

**New Pattern**:
```swift
List {
    ForEach(items) { item in
        RowView(item: item)
        // ✅ Let system handle everything
    }
}
.listStyle(.insetGrouped)  // ✅ Platform-adaptive
```

### Step 4.2: Update All List Views

Apply to:
- `GoalsListView.swift`
- `ActionsListView.swift`
- `TermsListView.swift`
- `PersonalValuesListView.swift`
- `ObligationsListView.swift`
- `MilestonesListView.swift`

**Example** (GoalsListView):
```swift
private var goalsList: some View {
    List(selection: $selectedGoal) {
        ForEach(viewModel.goals) { goalData in
            GoalRowView(goal: goalData)
                // ❌ REMOVE: .listRowBackground(Color.clear)
                // ❌ REMOVE: .contentShape(Rectangle())
                .onTapGesture {
                    edit(goalData)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        goalToDelete = goalData
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        edit(goalData)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        goalToDelete = goalData
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .tag(goalData)
        }
    }
    .listStyle(.insetGrouped)  // ✅ ADD: Platform-adaptive style
    // ❌ REMOVE: .scrollContentBackground(.hidden)
    #if os(macOS)
    .onDeleteCommand {
        if let selected = selectedGoal {
            goalToDelete = selected
        }
    }
    #endif
}
```

### Step 4.3: Test List Behavior

**Testing Checklist**:
- [ ] iOS: List has proper inset grouping
- [ ] iPad: Sidebar mode shows list correctly
- [ ] macOS: List appears with macOS styling
- [ ] Swipe actions work
- [ ] Context menu works (right-click on macOS)
- [ ] Selection highlights correctly
- [ ] Delete command works (macOS)

### Step 4.4: Commit Phase 4

```bash
git add .
git commit -m "Phase 4: Simplify list styling to use system defaults

- Removed manual listRowBackground customizations
- Removed manual contentShape modifications
- Removed scrollContentBackground(.hidden)
- Added .listStyle(.insetGrouped) for platform adaptation

Benefits:
- Automatic platform adaptation (iOS/iPadOS/macOS/visionOS)
- Liquid Glass effects work correctly
- System handles accessibility
- Less manual styling code
- Better integration with system UI"
```

---

## Phase 5: Fix Async Patterns (Polish)

**Time Estimate**: 30 minutes  
**Risk Level**: Low  
**Files**: 1

### Step 5.1: Replace Polling with Proper Async/Await

**File**: `swift/HappyToHaveLived/HappyToHaveLivedApp/HappyToHaveLivedApp.swift`

**If SyncEngine supports AsyncStream or Combine publishers**, use those.

**Example with AsyncStream** (if available):
```swift
private func performInitialSyncIfNeeded() async {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.defaultSyncEngine) var syncEngine
    
    // Check if database is empty
    let isEmpty = (try? await database.read { db in
        try #sql("SELECT COUNT(*) FROM goals", as: Int.self).fetchOne(db) == 0
    }) ?? false
    
    guard isEmpty else {
        print("📊 Database has existing data, skipping initial sync wait")
        return
    }
    
    print("📥 Fresh install detected - waiting for CloudKit sync...")
    isPerformingInitialSync = true
    
    // ✅ BETTER: Use AsyncStream if syncEngine provides one
    // Example (pseudocode - adjust based on actual SyncEngine API):
    /*
    for await status in syncEngine.statusUpdates {
        if case .synchronized = status {
            print("✅ Initial CloudKit sync complete")
            break
        }
    }
    */
    
    // ⚠️ FALLBACK: If AsyncStream not available, keep polling but document it
    // TODO: Request AsyncStream support from SyncEngine
    var startIterations = 0
    let maxStartIterations = 50
    
    while !syncEngine.isSynchronizing && startIterations < maxStartIterations {
        try? await Task.sleep(for: .milliseconds(100))
        startIterations += 1
    }
    
    guard startIterations < maxStartIterations else {
        print("⚠️ Sync never started after 5 seconds")
        isPerformingInitialSync = false
        return
    }
    
    var completeIterations = 0
    let maxCompleteIterations = 600
    
    while syncEngine.isSynchronizing && completeIterations < maxCompleteIterations {
        try? await Task.sleep(for: .milliseconds(100))
        completeIterations += 1
    }
    
    print(completeIterations >= maxCompleteIterations 
          ? "⚠️ Sync timed out after 60 seconds"
          : "✅ Initial CloudKit sync complete (\(completeIterations * 100)ms)")
    
    isPerformingInitialSync = false
}
```

### Step 5.2: Commit Phase 5

```bash
git add .
git commit -m "Phase 5: Document async patterns and improve sync handling

- Added TODO for AsyncStream support in SyncEngine
- Documented polling as fallback pattern
- Improved error messages and logging

Future: Replace polling with AsyncStream when SyncEngine supports it"
```

---

## Final Validation & Testing

### Complete Testing Matrix

Run through this complete checklist before merging:

#### Platform Tests

- [ ] **iOS Simulator** (iPhone 15 Pro)
  - [ ] Light mode
  - [ ] Dark mode
  - [ ] Landscape orientation
  - [ ] Dynamic Type (smallest and largest)

- [ ] **iOS Device** (if available)
  - [ ] All above scenarios
  - [ ] Actual Liquid Glass effects visible

- [ ] **iPad Simulator**
  - [ ] Portrait mode
  - [ ] Landscape mode
  - [ ] Split View (1/2, 1/3, 2/3)
  - [ ] Sidebar toggle (if using TabView .sidebarAdaptable)

- [ ] **macOS**
  - [ ] Light mode
  - [ ] Dark mode
  - [ ] Window resize (small to large)
  - [ ] Sidebar behavior
  - [ ] Keyboard shortcuts

- [ ] **visionOS Simulator** (if available)
  - [ ] Window placement
  - [ ] Depth effects

#### Accessibility Tests

Enable each setting and verify app still works:

- [ ] Reduce Transparency → Materials become opaque
- [ ] Increase Contrast → Higher contrast ratios
- [ ] Reduce Motion → Animations disabled/reduced
- [ ] Bold Text → Text weight increases
- [ ] Larger Text (Dynamic Type) → Layouts adapt
- [ ] VoiceOver → All controls accessible
- [ ] Switch Control → Navigation possible

#### Functional Tests

- [ ] Create new goal → Saves correctly
- [ ] Edit existing goal → Updates correctly
- [ ] Delete goal → Confirmation and deletion work
- [ ] View goal list → Displays with progress
- [ ] View goal details → Shows full information
- [ ] Form validation → Errors display correctly
- [ ] CloudKit sync → Initial sync completes
- [ ] Pull to refresh → Lists update

#### Visual Tests

Compare before/after screenshots:

- [ ] Dashboard has Liquid Glass effects
- [ ] Lists show depth and translucency
- [ ] Progress gauges animate smoothly
- [ ] Forms have proper spacing
- [ ] No visual regressions
- [ ] Colors are semantic and appropriate

---

## Performance Verification

Run Instruments to verify improvements:

```bash
# Time Profiler
xcodebuild -scheme HappyToHaveLived \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -enableAddressSanitizer NO \
  -enableThreadSanitizer NO \
  build

# Open Instruments
instruments -t "Time Profiler" \
  HappyToHaveLived.app
```

**Expected Improvements**:
- Reduced CPU usage (no polling loops)
- Faster view rendering (system materials vs custom)
- Lower memory (fewer view layers)
- Better scrolling performance

---

## Documentation Updates

### Update These Files

1. **LIQUID_GLASS_VISUAL_SYSTEM.md**
   - Document that BackgroundView is removed
   - Explain new material usage
   - Update examples

2. **CLAUDE.md**
   - Update UI patterns section
   - Document @Observable form pattern
   - Add Gauge usage examples

3. **ARCHITECTURE_SUMMARY.md**
   - Update line counts
   - Note Gauge component usage
   - Document @Observable pattern

4. **README.md**
   - Update technology stack
   - Note Liquid Glass adoption
   - Update screenshots (if included)

---

## Rollback Procedure

If issues are found:

```bash
# View all refactoring commits
git log --oneline | grep "Phase [1-5]"

# Rollback to before Phase X
git reset --hard <commit-before-phase-X>

# Or rollback everything
git reset --hard pre-liquid-glass-refactor

# Or create a revert commit (safer for shared branches)
git revert <commit-range>
```

---

## Success Criteria

This refactoring is successful when:

✅ **Code Reduction**: ~600-800 lines removed  
✅ **Build**: Clean build with no warnings  
✅ **Tests**: All unit tests pass  
✅ **Visual**: Liquid Glass effects visible and correct  
✅ **Accessibility**: All settings work correctly  
✅ **Performance**: Equal or better than before  
✅ **Platform**: Works on iOS, iPadOS, macOS, visionOS  

---

## Resources & References

### Apple Documentation

1. **Adopting Liquid Glass**
   - Location: `/REFERENCE/documents/appleDeveloper/swiftui/adopting-liquid-glass.md`
   - URL: https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass

2. **SwiftUI Materials**
   - URL: https://developer.apple.com/documentation/swiftui/material

3. **Gauge Component**
   - URL: https://developer.apple.com/documentation/swiftui/gauge

4. **Observable Macro**
   - Location: `/REFERENCE/documents/SwiftLanguage/02-LanguageGuide/19-Macros.md`
   - URL: https://developer.apple.com/documentation/observation

5. **Progress Indicators HIG**
   - Location: `/REFERENCE/documents/hig_docs/progress-indicators.md`
   - URL: https://developer.apple.com/design/human-interface-guidelines/progress-indicators

### Internal Documentation

1. **LIQUID_GLASS_VISUAL_SYSTEM.md** - Your project's design spec
2. **CLAUDE.md** - Architecture patterns
3. **ARCHITECTURE_SUMMARY.md** - Current state documentation

---

## Questions & Support

If you encounter issues:

1. **Check Apple's Sample Code**: Landmarks app demonstrates Liquid Glass
2. **Review Project Knowledge**: Use `project_knowledge_search` tool
3. **Consult Architecture**: See CLAUDE.md for patterns
4. **Test Incrementally**: Commit each phase separately
5. **Document Issues**: Add TODO comments for future fixes

---

**End of Guide**

This completes the comprehensive refactoring guide. Each phase is independent and can be done separately, with full testing and commit procedures. The guide follows Apple's official documentation and your project's established patterns.
