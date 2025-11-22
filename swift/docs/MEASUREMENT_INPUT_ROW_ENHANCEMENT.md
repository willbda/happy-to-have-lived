# MeasurementInputRow Enhancement: Inline Measure Creation

**Date**: 2025-11-21
**Author**: Claude Code
**Issue**: Scenario 3 - Users couldn't create measures when logging actions without existing measures

## Problem Statement

**Before**: When logging an action with a measurement type that doesn't exist in the catalog (e.g., "pages read", "minutes practiced"), users had to:

1. Create a dummy goal with that measure type
2. Delete the goal (measure remains in catalog)
3. Return to action form to select the measure

**Root Cause**: `MeasurementInputRow` (used in actions) lacked inline measure creation, while `MetricTargetRow` (used in goals) had this feature.

## Solution Implemented

Added inline measure creation to `MeasurementInputRow` by mirroring the pattern from `MetricTargetRow`.

### Changes Made

#### 1. Updated Component API

**File**: `swift/Sources/App/Views/Components/FormComponents/MeasurementInputRow.swift`

**Added dependencies**:
```swift
import Dependencies
import Services
import SQLiteData
```

**Added state management**:
```swift
@State private var showingCreateMeasure = false
@State private var newMeasureUnit = ""
@State private var newMeasureTitle = ""
@State private var newMeasureType = "distance"
@State private var isCreating = false
```

**Added callback parameter**:
```swift
let onMeasureCreated: (() async -> Void)?
```

#### 2. Added "Create New Measure" Button

**Trigger Condition**: Shows when `availableMeasures.isEmpty` OR `measureId == nil`

```swift
if availableMeasures.isEmpty || measureId == nil {
    Button {
        showingCreateMeasure = true
    } label: {
        Label("Create New Measure", systemImage: "plus.circle")
            .foregroundStyle(.blue)
    }
    .buttonStyle(.borderless)
}
```

#### 3. Added Inline Form Sheet

**Pattern**: Reused from `MetricTargetRow.swift:129-187`

**Form Fields**:
- Unit (e.g., "km", "hours", "sessions") - autocorrection disabled, lowercase
- Title (optional, defaults to capitalized unit)
- Type picker (distance, time, count, energy, other)
- Examples section for guidance

**Implementation**:
```swift
.sheet(isPresented: $showingCreateMeasure) {
    NavigationStack {
        createMeasureForm
    }
}
```

#### 4. Implemented createMeasure() Function

**Architecture**: UI → MeasureCoordinator → Repository → Database

**Key Features**:
- Uses `MeasureCoordinator.getOrCreate()` for idempotent creation
- Auto-selects newly created measure (`measureId = measure.id`)
- Calls `onMeasureCreated()` callback to notify parent
- Resets form state after creation
- Error handling with console logging

```swift
private func createMeasure() async {
    let coordinator = MeasureCoordinator(database: database)
    let measure = try await coordinator.getOrCreate(
        unit: unit,
        measureType: type,
        title: title
    )

    measureId = measure.id  // Auto-select
    await onMeasureCreated?()  // Notify parent
    showingCreateMeasure = false  // Dismiss
}
```

#### 5. Updated Call Sites

**File**: `swift/Sources/App/Views/FormViews/ActionFormView.swift`

```swift
MeasurementInputRow(
    measureId: bindingForMeasurement(measurement.id).measureId,
    value: bindingForMeasurement(measurement.id).value,
    availableMeasures: dataStore.measures,
    onRemove: { removeMeasurement(id: measurement.id) },
    onMeasureCreated: {
        // DataStore.measures automatically updates via ValueObservation
        print("✅ Measure created - DataStore will auto-update")
    }
)
```

**Note**: `onMeasureCreated` callback is optional but provided for explicit notification. DataStore's ValueObservation automatically refreshes `measures` array when database changes.

## User Workflow (After Fix)

**Scenario**: User wants to log "Read for 45 minutes" but "minutes" measure doesn't exist.

1. User opens ActionFormView
2. User taps "Add Measurement"
3. User sees empty picker with "Create New Measure" button
4. User taps "Create New Measure"
5. **Sheet appears** with inline form
6. User enters:
   - Unit: "minutes"
   - Title: "Duration in minutes" (optional)
   - Type: "time"
7. User taps "Save"
8. **Measure created** via `MeasureCoordinator.getOrCreate()`
9. **Picker auto-selects** "minutes"
10. User enters value: 45
11. User saves action successfully

**No workaround needed!**

## Architecture Benefits

### 1. Feature Parity
- **Before**: Goals = full feature, Actions = limited
- **After**: Both have inline measure creation

### 2. Single Source of Truth
- All measure creation flows through `MeasureCoordinator.getOrCreate()`
- Duplicate prevention consistent across UI entry points
- Repository-level validation enforced everywhere

### 3. Declarative State Management
- DataStore observes measures table via ValueObservation
- UI automatically updates when measures change
- No manual refresh calls needed

### 4. Idempotent Pattern
- `getOrCreate()` returns existing measure if duplicate found
- Users can't accidentally create "minutes" twice
- Case-insensitive matching prevents "Minutes" vs "minutes"

## Code Reuse

This implementation **directly reused** the pattern from `MetricTargetRow.swift`:

| Component | Source | Pattern |
|-----------|--------|---------|
| State management | MetricTargetRow:34-38 | Same @State properties |
| Button conditional | MetricTargetRow:111-119 | Same visibility logic |
| Sheet presentation | MetricTargetRow:129-133 | Same navigation pattern |
| Form UI | MetricTargetRow:138-168 | Identical form structure |
| createMeasure() | MetricTargetRow:198-230 | Same coordinator pattern |

**Result**: Consistent UX across goals and actions forms.

## Testing Checklist

- [x] Component compiles without errors
- [x] Updated preview to include new parameter
- [x] Updated ActionFormView call site
- [ ] Manual test: Create measure when no measures exist
- [ ] Manual test: Create measure when measures exist but none selected
- [ ] Manual test: Verify duplicate prevention (try creating "km" twice)
- [ ] Manual test: Verify auto-selection after creation
- [ ] Manual test: Verify DataStore auto-refresh
- [ ] Manual test: Verify form reset after creation
- [ ] Manual test: Verify cancel button works

## Future Enhancements

1. **Error Alert UI**: Show user-friendly error alerts instead of console logging
2. **Loading Indicator**: Show progress during async measure creation
3. **Recent Measures**: Show recently created measures at top of picker
4. **Smart Defaults**: Pre-fill unit/type based on action context (e.g., "workout" → suggest "km", "time")

## Related Files

- `swift/Sources/App/Views/Components/FormComponents/MeasurementInputRow.swift` - Updated component
- `swift/Sources/App/Views/Components/FormComponents/MetricTargetRow.swift` - Reference implementation
- `swift/Sources/App/Views/FormViews/ActionFormView.swift` - Updated call site
- `swift/Sources/Services/Coordinators/MeasureCoordinator.swift` - Business logic
- `swift/Sources/App/DataStore.swift` - State management

## Conclusion

This enhancement removes a significant friction point in the action logging workflow while maintaining architectural consistency. Users can now create measures on-demand from both goals and actions, with all creation flows properly validated and deduplicated through the coordinator layer.
