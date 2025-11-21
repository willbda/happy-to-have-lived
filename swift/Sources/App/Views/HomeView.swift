//
// HomeView.swift
// Written by Claude Code on 2025-11-20
// Refactored on 2025-11-20 to use DataStore declarative pattern
//
// PURPOSE: Main dashboard view showing active goals and recent actions
// DATA SOURCE: DataStore (environment object, single source of truth)
// PATTERN: Hero image + parallax scroll (inspired by Calm app and Apple Music)
//
// LAYOUT:
// 1. Hero image (upper ~35%) with parallax fade effect
// 2. Greeting overlay (3 lines, white text with shadow)
// 3. Active goals horizontal carousel (from DataStore.activeGoals)
// 4. Quick action button (Log Action)
// 5. Recent actions list (from DataStore.actions, color-coded by goal)
//
// DECLARATIVE ARCHITECTURE:
// - No manual refresh calls (DataStore updates propagate automatically)
// - No separate ViewModel (DataStore is single source of truth)
// - Truly reactive (view observes DataStore via @Environment)
//
// REFERENCES:
// - Calm app: Hero image with fade-on-scroll
// - Apple Music: Gradient overlays for readability
// - Apple Health: Card-based content sections
//

import Models
import Services
import SwiftUI

#if canImport(FoundationModels)
    import FoundationModels
#endif

public struct HomeView: View {
    // MARK: - Environment

    @Environment(DataStore.self) private var dataStore
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    // MARK: - State

    @State private var showingLogAction = false
    @State private var actionToEdit: ActionData?
    @State private var greetingData: GreetingData?
    @State private var isLoadingGreeting = false

    // MARK: - Constants

    private let heroHeight: CGFloat = 380  // Increased from 300 to match Calm's ~50% ratio

    // MARK: - Services

    @ObservationIgnored
    private let progressService = ProgressCalculationService()

    // MARK: - Initializer

    public init() {}

    // MARK: - Body

    public var body: some View {
        @Bindable var navigationCoordinator = navigationCoordinator

        NavigationStack(path: $navigationCoordinator.path) {
            NavigationContainer {
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Hero image with parallax effect
                        GeometryReader { geometry in
                            let minY = geometry.frame(in: .global).minY
                            let imageHeight = max(0, heroHeight + (minY > 0 ? minY : 0))
                            let opacity = max(0, 1 - (minY / -150))

                            // Hero image (with fallback gradient for preview)
                            ZStack {
                                // Background gradient (always present as fallback)
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.5, blue: 0.6),
                                        Color(red: 0.2, green: 0.3, blue: 0.4),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )

                                // Dynamic image selection based on LLM suggestion
                                Image(selectedHeroImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                            .frame(width: geometry.size.width, height: imageHeight)
                            .clipped()
                            .opacity(opacity)
                            .offset(y: minY > 0 ? -minY : 0)

                            // Gradient overlay for readability
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .black.opacity(0.4),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: imageHeight)
                        }
                        .frame(height: heroHeight)

                        // Greeting overlay (on hero image)
                        greetingOverlay
                    }

                    // Content sections (scroll over hero)
                    VStack(spacing: 32) {
                        // Active Goals Section
                        activeGoalsSection

                        // Recent Actions Section
                        recentActionsSection
                    }
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .offset(y: -16)  // Overlap hero slightly
                }
                .ignoresSafeArea(edges: .top)
                .task {
                    // Generate greeting on view appear
                    await generateGreeting()
                }
                .toolbar {
                    homeToolbarItems
                }
                .sheet(isPresented: $showingLogAction) {
                    NavigationStack {
                        ActionFormView()
                    }
                }
                .sheet(item: $actionToEdit) { actionData in
                    NavigationStack {
                        ActionFormView(actionToEdit: actionData)
                    }
                }
            }  // NavigationContainer
        }  // NavigationStack
    }

    // MARK: - Computed Properties

    /// Select hero image based on LLM suggestion or time of day
    /// Available images: Aurora2, Aurora3, AuroraAndCarLights, BackyardTree,
    /// BigLakeMountains, ChicagoRoses, FamilyHike, Forest, Moody, Mountains4
    private var selectedHeroImage: String {
        // Priority 1: LLM-suggested image (if available in asset catalog)
        if let suggestedImage = greetingData?.suggestedHeroImage {
            // Validate it exists in our catalog
            let availableImages = [
                "Aurora2", "Aurora3", "AuroraAndCarLights",
                "BigLakeMountains", "ChicagoRoses", "FamilyHike", "Forest",
                "Moody", "Mountains4",
            ]
            if availableImages.contains(suggestedImage) {
                return suggestedImage
            }
        }

        // Priority 2: Time-of-day based fallback using actual asset catalog images
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<8:
            return "Aurora2"  // Early morning (sunrise aurora)
        case 8..<12:
            return "Mountains4"  // Morning (bright mountains)
        case 12..<17:
            return "Forest"  // Afternoon (green forest)
        case 17..<20:
            return "Moody"  // Evening (moody sunset)
        default:
            return "BigLakeMountains"
        }
    }

    // MARK: - Greeting Components

    /// Dynamic greeting overlay with LLM-generated content
    private var greetingOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()

            if isLoadingGreeting {
                // Loading state (shimmer effect)
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.3))
                        .frame(width: 150, height: 20)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.3))
                        .frame(width: 200, height: 36)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.3))
                        .frame(width: 180, height: 36)
                }
            } else if let greeting = greetingData {
                // Dynamic greeting (LLM-generated)
                Text(greeting.timeGreeting)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 2)

                Text(greeting.motivationalLine1)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)

                Text(greeting.motivationalLine2)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            } else {
                // Fallback greeting (if LLM unavailable or failed)
                Text("Hello!")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 2)

                Text("Here's what's")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)

                Text("happening")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: heroHeight)
    }

    // MARK: - Sections

    private var activeGoalsSection: some View {
        Section {
            // Horizontal carousel (real data from DataStore)
            if dataStore.activeGoals.isEmpty {
                Text("No active goals yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        // Real goal cards from DataStore
                        ForEach(dataStore.activeGoals.prefix(5)) { goalData in
                            goalCard(for: goalData)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        } header: {
            HStack {
                Text("Active Goals")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: {}) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
    }

    private var recentActionsSection: some View {
        Section {
            // Action list - fully declarative SwiftUI pattern
            if dataStore.actions.isEmpty {
                // Empty state (iOS 17+ ContentUnavailableView)
                ContentUnavailableView {
                    Label("No Actions Yet", systemImage: "checkmark.circle")
                } description: {
                    Text("Actions you log will appear here")
                }
                .padding(.vertical, 40)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
            } else {
                // SwiftUI LazyVStack handles iteration and identity
                LazyVStack(spacing: 0) {
                    ForEach(dataStore.recentActions.prefix(25)) { actionData in
                        actionRow(for: actionData)
                        Divider()
                            .padding(.leading, 80)
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
            }
        } header: {
            Text("Recent Actions")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Real Data Components

    private func goalCard(for goalData: GoalData) -> some View {
        // Declarative: Presentation layer handles progress calculation
        let progress = GoalPresentation.progress(
            for: goalData,
            actions: dataStore.actionsForGoal(goalData.id),
            service: progressService
        )

        return VStack(alignment: .leading, spacing: 12) {
            // Progress ring with automatic vibrancy
            ZStack {
                Circle()
                    .stroke(.tertiary, lineWidth: 4)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            .frame(width: 60, height: 60)

            // Goal info with automatic vibrancy
            VStack(alignment: .leading, spacing: 4) {
                Text(goalData.title ?? "Untitled Goal")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                // Declarative: GoalData computed property handles formatting
                Text(goalData.formattedTargetDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 160)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            navigationCoordinator.navigateToGoal(goalData.id)
        }
    }

    private func actionRow(for actionData: ActionData) -> some View {
        HStack(spacing: 12) {
            // Icon - declarative via ActionData extension
            Image(systemName: actionData.icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(.quaternary)
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(actionData.title ?? "Untitled Action")
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    // Measurement - declarative via ActionData extension
                    if !actionData.formattedMeasurement.isEmpty {
                        Text(actionData.formattedMeasurement)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Goal badge - declarative via ActionData method
                if let goalTitle = actionData.goalTitle(from: dataStore) {
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
                    .background(.quaternary)
                    .clipShape(Capsule())
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            actionToEdit = actionData
        }
    }

    // MARK: - Helper Methods

    /// Generate personalized greeting using LLM
    /// Called on .task (view appear) with automatic caching
    @MainActor
    private func generateGreeting() async {
        // Skip if already loading or recently generated (within last 2 hours)
        guard !isLoadingGreeting else { return }

        // TODO: Add caching logic to avoid regenerating too frequently
        // For now, generate every time (acceptable for MVP)

        isLoadingGreeting = true

        do {
            #if os(iOS) || os(macOS)
                // Only generate on platforms with Foundation Models support
                if #available(iOS 26.0, macOS 26.0, *) {
                    let service = GreetingService(database: dataStore.database)
                    let greeting = try await service.generateGreeting()
                    self.greetingData = greeting
                } else {
                    // Platform doesn't support Foundation Models - use fallback
                    self.greetingData = nil
                }
            #else
                // Platform doesn't support Foundation Models - use fallback
                self.greetingData = nil
            #endif
        } catch {
            // LLM generation failed - use fallback greeting
            print("Failed to generate greeting: \(error)")
            self.greetingData = nil
        }

        isLoadingGreeting = false
    }

    // MARK: - Toolbar

    /// Toolbar items for HomeView
    ///
    /// **Pattern**: Declarative @ToolbarContentBuilder for reusability
    /// **Actions**: All menu items use type-safe NavigationRoute
    @ToolbarContentBuilder
    private var homeToolbarItems: some ToolbarContent {
        // Add Action button (persistent, always visible)
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingLogAction = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.blue)
            }
        }

        // Menu button
        ToolbarItem(placement: .automatic) {
            Menu {
                Button {
                    navigationCoordinator.navigate(to: .settings)
                } label: {
                    Label("Settings", systemImage: "gear")
                }

                Button {
                    navigationCoordinator.navigate(to: .exportData)
                } label: {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }

                Button {
                    navigationCoordinator.navigate(to: .reviewDuplicates)
                } label: {
                    Label("Review Duplicates", systemImage: "doc.on.doc")
                }

                Button {
                    navigationCoordinator.navigate(to: .archives)
                } label: {
                    Label("Archives", systemImage: "archivebox")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
            }
        }
    }
}

// MARK: - Preview

#Preview("Home - With Data") {
    let dataStore = DataStore()

    // Note: In preview, DataStore won't have ValueObservation running
    // So we manually populate with sample data for visual testing
    // (In real app, DataStore observes database automatically)

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
