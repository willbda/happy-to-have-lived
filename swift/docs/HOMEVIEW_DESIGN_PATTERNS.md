# HomeView Design Patterns
*Modern SwiftUI + Liquid Glass Design Language*

Reference: Calm app, Apple Health, Apple Music dashboard patterns

## Pattern 1: Hero Image with Content Overlay (Calm-style)

```swift
ScrollView {
    VStack(spacing: 0) {
        // Hero section - rich, vibrant image
        ZStack(alignment: .bottom) {
            // Full-color hero image (no blur, no opacity reduction)
            Image("MountainLake")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 400)
                .clipped()

            // Content floats above using materials
            VStack(spacing: 20) {
                // Circular progress gauge (standard component)
                Gauge(value: 0.65) {
                    VStack(spacing: 4) {
                        Text("0")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Days")
                            .font(.caption)
                    }
                }
                .gaugeStyle(.accessoryCircular)
                .tint(.white)
                .frame(width: 120, height: 120)

                // Week indicators
                HStack(spacing: 12) {
                    ForEach(0..<7) { day in
                        Circle()
                            .fill(day == 3 ? .white : .white.opacity(0.3))
                            .frame(width: 36, height: 36)
                    }
                }

                Text("You haven't completed any sessions yet")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.bottom, 40)
        }

        // Scrollable content below hero
        VStack(spacing: 20) {
            // Promotional card
            HStack(spacing: 12) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(.purple)
                    .font(.title2)
                    .padding()
                    .background(.purple.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Black Friday Offer")
                        .font(.headline)
                    Text("Gift Calm to friends for 20% off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // Content sections
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Dailies")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<5) { _ in
                            // Video card
                            VStack(alignment: .leading) {
                                Image("DailyContent")
                                    .resizable()
                                    .aspectRatio(16/9, contentMode: .fill)
                                    .frame(width: 280, height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                Text("Daily Calm")
                                    .font(.headline)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 20)
    }
}
```

**Key Points**:
- ✅ Rich hero image (full color, no blur)
- ✅ Standard `Gauge` for circular progress
- ✅ `.regularMaterial` for floating cards
- ✅ No GeometryReader or parallax calculations
- ✅ Natural scroll behavior

---

## Pattern 2: Gradient Background with Card Layout (Health-style)

```swift
ZStack {
    // Soft gradient background
    LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.85, blue: 0.95),
            Color(red: 0.85, green: 0.75, blue: 0.85)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    .ignoresSafeArea()

    // Content with standard List
    List {
        Section("Pinned") {
            // Card 1: State of Mind
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.teal)
                    Text("State of Mind")
                        .font(.subheadline)
                        .foregroundStyle(.teal)
                    Spacer()
                    Text("Oct 7")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text("A Pleasant Moment")
                    .font(.headline)

                Text("Calm, Satisfied, Peaceful, Content • Health, Fitness and 4 more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Card 2: Heart Rate Variability
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("Heart Rate Variability")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Spacer()
                    Text("09:42")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("67")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    + Text(" ms")
                        .font(.caption)
                }
            }
            .padding()
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
}
```

**Key Points**:
- ✅ Gradient background (not an image)
- ✅ White cards with `.background(.white)`
- ✅ Standard List with `.listRowBackground(.clear)`
- ✅ Semantic colors (`.red`, `.teal`) with SF Symbols
- ✅ `.scrollContentBackground(.hidden)` to show gradient

---

## Pattern 3: Hero Image with List Content (Music-style)

```swift
NavigationStack {
    ZStack {
        // Background gradient
        LinearGradient(
            colors: [.gray.opacity(0.1), .white],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        // Content
        List {
            Section {
                // Hero image section
                VStack(spacing: 0) {
                    Image("AlbumArt")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 300)
                        .clipped()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("TODAY'S PICK")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("F-1 Trillion")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Post Malone")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(recordGroups) { group in
                    HStack(spacing: 12) {
                        Image(group.artwork)
                            .resizable()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.title)
                                .font(.headline)
                            Text(group.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Record Groups")
                    .font(.title3)
                    .fontWeight(.bold)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    .navigationTitle("Records")
    .navigationBarTitleDisplayMode(.large)
}
```

**Key Points**:
- ✅ Hero image as first List section
- ✅ `.listRowInsets(EdgeInsets())` for edge-to-edge hero
- ✅ Standard List rows with disclosure indicators
- ✅ Gradient background via `.scrollContentBackground(.hidden)`
- ✅ Large navigation title (standard iOS pattern)

---

## Common Liquid Glass Patterns Across All Three

### 1. **Rich Backgrounds (No Heavy Blur)**
```swift
// ✅ DO: Full-color images
Image("Mountains")
    .resizable()
    .aspectRatio(contentMode: .fill)

// ✅ DO: Soft gradients
LinearGradient(
    colors: [.pink.opacity(0.3), .purple.opacity(0.3)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// ❌ DON'T: Heavy blur or opacity reduction
Image("Mountains")
    .blur(radius: 10)  // Avoid
    .opacity(0.5)      // Avoid
```

### 2. **Content Materials (Semantic)**
```swift
// ✅ DO: Semantic materials
.background(.regularMaterial)    // For main cards
.background(.thinMaterial)       // For secondary content
.background(.white)              // For Health-style cards

// ❌ DON'T: Custom opacity/blur stacking
.background(Color.white.opacity(0.8))
.background(.ultraThinMaterial)
```

### 3. **Standard Components**
```swift
// ✅ DO: Use Apple's components
Gauge(value: progress)
    .gaugeStyle(.accessoryCircular)

ProgressView(value: progress)
    .progressViewStyle(.circular)

// ❌ DON'T: Custom manual drawing
Circle()
    .trim(from: 0, to: progress)
    .stroke(...)
```

### 4. **List Integration**
```swift
// ✅ DO: Use List with custom backgrounds
List {
    // Content
}
.listStyle(.plain)
.scrollContentBackground(.hidden)
.background(yourBackground)

// ❌ DON'T: LazyVStack with manual everything
ScrollView {
    LazyVStack {
        // Manual dividers, spacing, backgrounds
    }
}
```

### 5. **Hero Image Sizing**
```swift
// ✅ DO: Fixed height, natural scroll
Image("Hero")
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(height: 300)  // Or 400 for larger
    .clipped()

// ❌ DON'T: GeometryReader calculations
GeometryReader { geo in
    let minY = geo.frame(in: .global).minY
    // Complex parallax math
}
```

---

## Recommended Pattern for Your HomeView

Based on these examples, here's the ideal structure:

```swift
ScrollView {
    VStack(spacing: 0) {
        // 1. Hero Section (Calm-style)
        ZStack(alignment: .bottomLeading) {
            Image("Mountains4")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 350)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(timeBasedGreeting)
                    .font(.title3)
                    .fontWeight(.medium)
                Text("Here's what's happening")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .shadow(radius: 4)
            .padding()
        }

        // 2. Content Sections (Health/Music-style cards)
        VStack(spacing: 24) {
            // Active Goals Carousel
            VStack(alignment: .leading, spacing: 12) {
                Text("Active Goals")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(goals) { goal in
                            GoalCard(goal: goal)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Recent Actions List (inside main VStack, not separate List)
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Actions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                // Standard List with fixed height
                List {
                    ForEach(recentActions) { action in
                        ActionRow(action: action)
                            .swipeActions { /* ... */ }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: 350)  // Show ~5 rows
            }
        }
        .padding(.top, 20)
    }
}
```

**Why This Works**:
1. Simple hero (no parallax)
2. Natural scroll (VStack, not complex ZStack overlays)
3. Standard components (Gauge, List)
4. Semantic materials (`.regularMaterial`)
5. Follows HIG patterns from real Apple apps

---

## Migration Checklist

To align your current HomeView with these patterns:

- [x] Remove GeometryReader parallax calculations
- [x] Remove LLM greeting complexity
- [x] Replace custom progress ring with Gauge
- [x] Use List with `.scrollContentBackground(.hidden)`
- [ ] Consider removing fixed List height (let it be natural scrolling)
- [ ] Consider gradient background instead of hero image (Health-style alternative)
- [ ] Add more semantic spacing (current: good, could use 24pt instead of 32pt)
- [ ] Consider NavigationStack with large title (Music-style alternative)

---

## Key Takeaway

**All three apps share the same philosophy**:
- Rich, vibrant backgrounds (no heavy processing)
- Content floats above using semantic materials
- Standard Apple components (Gauge, List, Cards)
- Natural scrolling (no complex parallax)
- Semantic colors and spacing (`.primary`, `.secondary`, 16-20pt padding)

This is **Liquid Glass in action** - the glass (materials) refracts the rich background, creating depth without custom complexity.
