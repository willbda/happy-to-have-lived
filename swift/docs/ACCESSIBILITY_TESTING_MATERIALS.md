# Accessibility Testing Guide - Materials & Vibrancy
## Ten Week Goal App - HIG Compliance Checklist

**Last Updated**: 2025-11-21
**Related**: LIQUID_GLASS_VISUAL_SYSTEM.md
**Purpose**: Verify semantic materials work correctly across all accessibility settings

---

## Quick Test Checklist

Use this checklist after implementing semantic materials in any view:

- [ ] **Reduced Transparency**: Materials fallback to solid backgrounds
- [ ] **Increased Contrast**: Text/icons remain legible
- [ ] **Reduced Motion**: No animation issues with materials
- [ ] **Dynamic Type**: All text scales correctly
- [ ] **VoiceOver**: All interactive elements have labels
- [ ] **Dark Mode**: Materials adapt automatically
- [ ] **Light Mode**: Materials adapt automatically

---

## Testing Procedures

### 1. Reduced Transparency Mode

**Purpose**: Verify materials fallback gracefully when user disables transparency.

**How to Test**:

**On Simulator**:
1. Open Settings app in Simulator
2. Navigate to: **Accessibility → Display & Text Size**
3. Enable **Reduce Transparency**
4. Launch your app
5. Navigate to HomeView

**On Device**:
1. Settings → Accessibility → Display & Text Size
2. Enable **Reduce Transparency**
3. Test your app

**Expected Behavior**:
- `.regularMaterial` → Opaque background (no blur)
- `.thinMaterial` → Opaque background (lighter than regular)
- Text remains legible (automatic contrast adjustment)
- Hero images still visible behind opaque materials

**Verification Points for HomeView**:
```
✓ Goal cards: Opaque background, text readable
✓ Action rows: Opaque background, icons visible
✓ Hero image: Still visible behind content sections
✓ Progress rings: .tint color remains vibrant
✓ No visual artifacts or broken layouts
```

**Common Issues**:
- ❌ Hardcoded `.white` text becomes invisible on light backgrounds
- ✅ Semantic `.primary` text adapts automatically

---

### 2. Increased Contrast Mode

**Purpose**: Verify text/icons have sufficient contrast for low vision users.

**How to Test**:

**On Simulator**:
1. Settings → Accessibility → Display & Text Size
2. Enable **Increase Contrast**
3. Launch your app

**Expected Behavior**:
- Semantic colors (`.primary`, `.secondary`, `.tertiary`) increase contrast
- `.quaternary` fills become more prominent
- Progress rings and icons more visible
- All text passes WCAG AA (4.5:1 for body text, 3:1 for large text)

**Verification Points for HomeView**:
```
✓ Goal titles: High contrast against material background
✓ Action titles: Clearly readable
✓ Icons: Stand out from backgrounds
✓ Progress percentages: Legible in rings
✓ Goal badges: Readable text on .quaternary fills
```

**Testing Tip**: Use **Accessibility Inspector** (Xcode → Developer Tool) to measure contrast ratios.

---

### 3. Reduced Motion Mode

**Purpose**: Verify animations don't cause issues when motion is reduced.

**How to Test**:

**On Simulator**:
1. Settings → Accessibility → Motion
2. Enable **Reduce Motion**
3. Launch your app

**Expected Behavior**:
- Parallax hero image effect should be subtle or disabled
- Scrolling still smooth
- No jarring transitions
- Materials still apply (no animation-dependent rendering)

**Verification Points for HomeView**:
```
✓ Hero image parallax disabled or minimal
✓ Scroll content sections smoothly
✓ Goal card carousel scrolls without bounce
✓ Sheet presentations use fade instead of slide
✓ No dizzying animations
```

**Code Pattern**:
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Conditional parallax
let imageHeight: CGFloat = {
    if reduceMotion {
        return heroHeight  // Static height
    } else {
        return max(0, heroHeight + (minY > 0 ? minY : 0))  // Parallax
    }
}()
```

---

### 4. Dynamic Type

**Purpose**: Verify text scales correctly for users who need larger text.

**How to Test**:

**On Simulator**:
1. Settings → Accessibility → Display & Text Size
2. Drag **Larger Text** slider to maximum
3. Launch your app

**Expected Behavior**:
- All text scales proportionally
- Cards expand to accommodate larger text
- No text truncation (except intentional `.lineLimit()`)
- Layouts remain balanced

**Verification Points for HomeView**:
```
✓ Goal card titles: Scale up, still readable
✓ Action row titles: Expand vertically
✓ Progress percentages: Remain centered in rings
✓ Hero greeting: Scales appropriately
✓ Goal badges: Text doesn't overflow capsule
```

**Common Issues**:
- ❌ Fixed frame widths prevent text expansion
- ✅ Use flexible layouts with `.frame(maxWidth: .infinity)`

---

### 5. VoiceOver

**Purpose**: Verify screen reader users can navigate effectively.

**How to Test**:

**On Simulator**:
1. Enable VoiceOver: Accessibility → VoiceOver (toggle ON)
2. Navigate using **VoiceOver Practice** gestures:
   - Swipe right: Next element
   - Swipe left: Previous element
   - Double tap: Activate element

**Expected Behavior**:
- All interactive elements have descriptive labels
- Decorative images are hidden from VoiceOver
- Navigation is logical (top to bottom, left to right)
- Buttons announce action ("Add Goal button")

**Verification Points for HomeView**:
```
✓ Hero image: Hidden from VoiceOver (.accessibilityHidden(true))
✓ Greeting text: Read as continuous phrase
✓ Goal cards: "Goal title, Target: date, Double tap to view details"
✓ Action rows: "Action title, measurement, contributes to Goal X"
✓ Quick Action button: "Log an Action button"
✓ Toolbar menu: "More options button"
```

**Code Pattern**:
```swift
// Good VoiceOver label
goalCard(for: goalData)
    .accessibilityLabel("\(goalData.title ?? "Untitled Goal"), Target: \(targetDateText)")
    .accessibilityHint("Double tap to view goal details")
    .accessibilityAddTraits(.isButton)

// Hide decorative images
Image(selectedHeroImage)
    .resizable()
    .accessibilityHidden(true)  // Decorative only
```

---

### 6. Dark Mode

**Purpose**: Verify materials adapt to dark appearance.

**How to Test**:

**On Simulator**:
1. Settings → Developer → Dark Appearance (toggle ON)
2. OR use Xcode environment override: Editor → Canvas → Color Scheme → Dark

**Expected Behavior**:
- `.regularMaterial` darkens automatically
- Semantic colors (`.primary`, `.secondary`) invert appropriately
- `.quaternary` fills remain subtle in dark mode
- Hero images remain vibrant (no auto-darkening)
- Progress rings use `.tint` color (respects user's accent color)

**Verification Points for HomeView**:
```
✓ Goal cards: Dark material, light text
✓ Action rows: Dark material, readable content
✓ Hero image: Full vibrancy preserved
✓ Progress rings: Accent color visible against dark material
✓ Goal badges: .quaternary fill subtle but visible
```

---

### 7. Light Mode

**Purpose**: Verify materials adapt to light appearance (default).

**How to Test**:

**On Simulator**:
1. Settings → Developer → Light Appearance
2. OR Xcode: Editor → Canvas → Color Scheme → Light

**Expected Behavior**:
- `.regularMaterial` lightens automatically
- Semantic colors use dark text
- `.quaternary` fills subtle but visible
- Hero images vibrant (baseline design)

**Verification Points for HomeView**:
```
✓ Goal cards: Light material, dark text
✓ Action rows: Light material, readable content
✓ Hero image: Rich and vibrant (baseline)
✓ Progress rings: Tint color contrasts with light material
✓ Goal badges: .quaternary visible against light material
```

---

## Automated Testing (Future)

**Goal**: Automate accessibility testing with XCTest.

```swift
import XCTest
@testable import App

final class AccessibilityTests: XCTestCase {
    func testReducedTransparencyMode() async throws {
        // Launch app with reduced transparency
        let app = XCUIApplication()
        app.launchArguments = ["-UIAccessibilityReduceTransparency", "1"]
        app.launch()

        // Verify goal cards render without crashes
        XCTAssertTrue(app.otherElements["goalCard"].exists)

        // Verify text remains readable
        // (Use Accessibility Inspector API to check contrast)
    }

    func testDynamicType() async throws {
        // Test with largest accessibility text size
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        // Verify layouts don't break
        XCTAssertTrue(app.staticTexts.firstMatch.exists)
    }

    func testVoiceOverLabels() async throws {
        // Verify all interactive elements have labels
        let app = XCUIApplication()
        app.launch()

        let goalCard = app.buttons.matching(identifier: "goalCard").firstMatch
        XCTAssertNotNil(goalCard.label)
        XCTAssertTrue(goalCard.label.count > 0)
    }
}
```

---

## Manual Test Matrix

Use this table to track testing progress:

| View | Reduced Transparency | Increased Contrast | Reduced Motion | Dynamic Type | VoiceOver | Dark Mode | Light Mode |
|------|---------------------|-------------------|----------------|--------------|-----------|-----------|------------|
| HomeView | ✅ 2025-11-21 | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending |
| GoalsListView | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending |
| ActionsListView | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending |
| GoalFormView | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending |
| ActionFormView | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending | ⏳ Pending |

**Legend**:
- ✅ Tested and passing
- ⚠️ Tested with minor issues
- ❌ Tested and failing
- ⏳ Pending testing

---

## Common Patterns & Fixes

### Pattern 1: Hardcoded Colors Breaking in Dark Mode

**Problem**:
```swift
// ❌ BAD: Hardcoded white breaks in dark mode
Text("Title")
    .foregroundStyle(.white)
    .background(.black)
```

**Fix**:
```swift
// ✅ GOOD: Semantic colors adapt automatically
Text("Title")
    .foregroundStyle(.primary)
    .background(.regularMaterial)
```

---

### Pattern 2: Custom Opacity Fills Not Adapting

**Problem**:
```swift
// ❌ BAD: Custom opacity doesn't adapt to Reduced Transparency
.background(Color.blue.opacity(0.1))
```

**Fix**:
```swift
// ✅ GOOD: Semantic fill adapts automatically
.background(.quaternary)

// OR for accent color fills:
.background(.tint.opacity(0.1))  // Uses system accent
```

---

### Pattern 3: Fixed Frames Breaking Dynamic Type

**Problem**:
```swift
// ❌ BAD: Fixed height truncates large text
Text("Goal Title That Might Be Long")
    .frame(height: 40)
```

**Fix**:
```swift
// ✅ GOOD: Flexible height accommodates scaling
Text("Goal Title That Might Be Long")
    .lineLimit(2)
    .fixedSize(horizontal: false, vertical: true)
```

---

## Resources

### Apple Documentation
- [HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Testing Accessibility](https://developer.apple.com/documentation/accessibility/testing_accessibility)
- [Accessibility Inspector](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/OSXAXTestingApps.html)

### WCAG Contrast Guidelines
- **WCAG AA** (minimum): 4.5:1 for normal text, 3:1 for large text
- **WCAG AAA** (enhanced): 7:1 for normal text, 4.5:1 for large text
- Semantic colors automatically meet AA standards

### Testing Tools
- **Xcode Accessibility Inspector**: Xcode → Open Developer Tool → Accessibility Inspector
- **Simulator Accessibility Settings**: Settings → Accessibility
- **Environment Overrides**: Xcode → Debug → Environment Overrides (live testing)

---

**Next Steps**:
1. Test HomeView with all accessibility settings
2. Document any issues or adjustments needed
3. Repeat for other views (GoalsListView, ActionsListView, etc.)
4. Consider automating common tests with XCTest
5. Add accessibility labels where missing

**Maintainer**: Development Team
