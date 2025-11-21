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

    private let heroHeight: CGFloat = 300

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
                VStack(spacing: 24) {
                    // Active Goals Section
                    activeGoalsSection

                    // Quick Action Button
                    quickActionButton

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
                "Aurora2", "Aurora3", "AuroraAndCarLights", "BackyardTree",
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
            return "BackyardTree"  // Night (night lights)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Goals")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: {}) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

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
        }
    }

    private var quickActionButton: some View {
        Button {
            showingLogAction = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .imageScale(.large)
                Text("Log an Action")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingLogAction) {
            NavigationStack {
                ActionFormView()
            }
        }
        // NO onDismiss needed - DataStore updates automatically!
        .sheet(item: $actionToEdit) { actionData in
            NavigationStack {
                ActionFormView(actionToEdit: actionData)
            }
        }
        // NO onDismiss needed - DataStore updates automatically!
    }

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
                    // Show last 7 recent actions (sorted by DataStore)
                    ForEach(
                        Array(
                            dataStore.recentActions
                                .prefix(7)
                                .enumerated()), id: \.element.id
                    ) { index, actionData in
                        actionRow(for: actionData)

                        if index < min(6, dataStore.recentActions.count - 1) {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Real Data Components

    private func goalCard(for goalData: GoalData) -> some View {
        // Get presentation color from GoalPresentation layer
        let color = goalData.presentationColor

        // Calculate real combined progress (time + action)
        let progress: Double = {
            // Time-based progress (30% weight)
            let timeResult = progressService.calculateTimeProgress(
                startDate: goalData.startDate,
                targetDate: goalData.targetDate
            )

            // Action-based progress (70% weight)
            let goalActions = dataStore.actionsForGoal(goalData.id)

            // Convert to ProgressCalculationService format
            let actionMeasurements: [ActionWithMeasurements] = goalActions.map { action in
                ActionWithMeasurements(
                    id: action.id,
                    logTime: action.logTime,
                    measurements: action.measurements.map { measurement in
                        ActionMeasurement(
                            measureId: measurement.measureId,
                            value: measurement.value
                        )
                    }
                )
            }

            // Convert targets to ProgressCalculationService format
            let targets: [MeasureTarget] = goalData.measureTargets.map { target in
                MeasureTarget(
                    measureId: target.measureId ?? UUID(),
                    measureTitle: target.measureTitle ?? "",
                    measureUnit: target.measureUnit ?? "",
                    targetValue: target.targetValue
                )
            }

            let actionResult = progressService.calculateActionProgress(
                targets: targets,
                actions: actionMeasurements
            )

            // Combined: 30% time + 70% action
            return progressService.calculateCombinedProgress(
                timeProgress: timeResult.progress,
                actionProgress: actionResult.progress
            )
        }()

        // Format target date
        let targetDateText: String = {
            if let targetDate = goalData.targetDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Target: \(formatter.string(from: targetDate))"
            } else {
                return "No target date"
            }
        }()

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

                Text(targetDateText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .goalCardStyle(color: color)  // ViewModifier from CardStyles
        .onTapGesture {
            navigationCoordinator.navigateToGoal(goalData.id)
        }
    }

    private func actionRow(for actionData: ActionData) -> some View {
        // Get icon from MeasurePresentation catalog
        let icon =
            actionData.measurements.first.map { measurement in
                MeasurePresentation.icon(for: measurement.measureUnit)
            } ?? "checkmark.circle.fill"

        // Get color from linked goal's presentation color
        let borderColor: Color = {
            if let firstContribution = actionData.contributions.first,
                let goal = dataStore.goals.first(where: { $0.id == firstContribution.goalId })
            {
                return goal.presentationColor  // Uses GoalPresentation
            }
            return .gray
        }()

        // Format measurement display
        let measurementText: String = {
            if let firstMeasurement = actionData.measurements.first {
                let value = Int(firstMeasurement.value)
                return "\(value) \(firstMeasurement.measureUnit)"
            }
            if let duration = actionData.durationMinutes {
                let hours = Int(duration) / 60
                let minutes = Int(duration) % 60
                if hours > 0 {
                    return "\(hours)h \(minutes)m"
                } else {
                    return "\(minutes)m"
                }
            }
            return ""
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

                    if !measurementText.isEmpty {
                        Text(measurementText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Goal badge (first contribution)
                if let firstContribution = actionData.contributions.first,
                    let goal = dataStore.goals.first(where: { $0.id == firstContribution.goalId })
                {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.caption2)
                        Text(goal.title ?? "Untitled Goal")
                            .font(.caption)
                            .lineLimit(1)
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
