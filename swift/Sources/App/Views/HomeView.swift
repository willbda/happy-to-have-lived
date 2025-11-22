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
    @State private var showingCreateGoal = false
    @State private var actionToEdit: ActionData?
    @State private var actionToDelete: ActionData?
    @State private var goalToDelete: GoalData?

    /// Track which goal sections are expanded (goalId: isExpanded)
    @State private var expandedGoalSections: Set<UUID> = []

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
                // Three separate sections - cleaner separation
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero Section - image extends into safe area, text respects it
                        ZStack(alignment: .bottomLeading) {
                            Image("Mountains4")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 300)
                                .clipped()
                                .ignoresSafeArea(edges: .top)  // Only image ignores top

                            // Simple greeting overlay - respects all safe areas
                            VStack(alignment: .leading, spacing: 4) {
                                Text(timeBasedGreeting)
                                    .font(.title3)

                                Text("Here's what's happening")
                                    .font(.largeTitle)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                            .padding()
                        }
                        .frame(maxWidth: .infinity)  // Full width

                        // Active Goals Section (separate List)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active Goals")
                                .font(.title2)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)

                            if dataStore.activeGoals.isEmpty {
                                VStack(spacing: 16) {
                                    Text("No active goals yet")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Button {
                                        showingCreateGoal = true
                                    } label: {
                                        Label("Create Your First Goal", systemImage: "target")
                                            .font(.headline)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(dataStore.activeGoals.prefix(5)) { goalData in
                                            goalCard(for: goalData)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        // Actions by Goal Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Actions by Goal")
                                .font(.title2)
                                .padding(.horizontal, 20)
                                .padding(.top, 32)

                            if dataStore.actions.isEmpty {
                                ContentUnavailableView {
                                    Label("No Actions Yet", systemImage: "checkmark.circle")
                                } description: {
                                    Text("Actions you log will appear here")
                                }
                                .padding(.vertical, 40)
                            } else {
                                // Goals with actions (collapsible sections)
                                ForEach(goalsWithActions) { goalData in
                                    goalActionsSection(for: goalData)
                                }

                                // Unlinked actions section (if any exist)
                                if !unlinkedActions.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "minus.circle")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .frame(width: 20)

                                            Text("No Goal")
                                                .font(.headline)
                                                .foregroundStyle(.secondary)

                                            Text("(\(unlinkedActions.count))")
                                                .font(.subheadline)
                                                .foregroundStyle(.tertiary)

                                            Spacer()
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.top, 8)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 12) {
                                                ForEach(unlinkedActions.prefix(10)) { actionData in
                                                    actionCard(for: actionData)
                                                }
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .toolbar {
                    homeToolbarItems
                }
            }  // NavigationContainer
            .sheet(isPresented: $showingLogAction) {
                NavigationStack {
                    ActionFormView()
                }
            }
            .sheet(isPresented: $showingCreateGoal) {
                NavigationStack {
                    GoalFormView()
                }
            }
            .sheet(item: $actionToEdit) { actionData in
                NavigationStack {
                    ActionFormView(actionToEdit: actionData)
                }
            }
            .alert(
                "Delete Goal", isPresented: .constant(goalToDelete != nil), presenting: goalToDelete
            ) { goalData in
                Button("Cancel", role: .cancel) {
                    goalToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    deleteGoal(goalData)
                }
            } message: { goalData in
                Text("Are you sure you want to delete '\(goalData.title ?? "this goal")'?")
            }
            .alert(
                "Delete Action", isPresented: .constant(actionToDelete != nil),
                presenting: actionToDelete
            ) { actionData in
                Button("Cancel", role: .cancel) {
                    actionToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    deleteAction(actionData)
                }
            } message: { actionData in
                Text("Are you sure you want to delete '\(actionData.title ?? "this action")'?")
            }
        }  // NavigationStack
    }

    // MARK: - Computed Properties

    /// Simple time-based greeting - no LLM complexity
    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Hello"
        }
    }

    /// Goals that have at least one associated action
    private var goalsWithActions: [GoalData] {
        dataStore.activeGoals.filter { goal in
            !dataStore.actionsForGoal(goal.id).isEmpty
        }
    }

    /// Actions that don't contribute to any goal
    private var unlinkedActions: [ActionData] {
        dataStore.recentActions.filter { action in
            action.contributions.isEmpty
        }
    }

    // MARK: - Components

    private func goalCard(for goalData: GoalData) -> some View {
        // Declarative: Presentation layer handles progress calculation
        let progress = GoalPresentation.progress(
            for: goalData,
            actions: dataStore.actionsForGoal(goalData.id),
            service: progressService
        )

        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                // Apple's standard ProgressView - circular gauge
                Gauge(value: progress) {
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(.blue)
                .frame(width: 60, height: 60)

                // Goal info
                VStack(alignment: .leading, spacing: 4) {
                    Text(goalData.title ?? "Untitled Goal")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

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
        .contextMenu {
            Button {
                navigationCoordinator.navigateToGoal(goalData.id)
            } label: {
                Label("View Details", systemImage: "eye")
            }

            Divider()

            Button(role: .destructive) {
                goalToDelete = goalData
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func actionRow(for actionData: ActionData) -> some View {
        // Standard List row - minimal custom styling
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
        .contentShape(Rectangle())  // Make entire row tappable
        .onTapGesture {
            actionToEdit = actionData
        }
        .contextMenu {
            Button {
                actionToEdit = actionData
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                actionToDelete = actionData
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// Collapsible section showing actions grouped by goal
    private func goalActionsSection(for goalData: GoalData) -> some View {
        let actions = dataStore.actionsForGoal(goalData.id)
        let isExpanded = expandedGoalSections.contains(goalData.id)

        return VStack(alignment: .leading, spacing: 12) {
            // Section header (tappable to expand/collapse)
            Button {
                withAnimation {
                    if isExpanded {
                        expandedGoalSections.remove(goalData.id)
                    } else {
                        expandedGoalSections.insert(goalData.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    Text(goalData.title ?? "Untitled Goal")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("(\(actions.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            // Action carousel (only shown when expanded)
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(actions.prefix(10).sorted(by: { $0.logTime > $1.logTime })) { actionData in
                            actionCard(for: actionData)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    /// Compact action card for horizontal carousel
    private func actionCard(for actionData: ActionData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon
            Image(systemName: actionData.icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(.blue.opacity(0.1))
                .clipShape(Circle())

            // Title
            Text(actionData.title ?? "Untitled")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Measurement (if available)
            if !actionData.formattedMeasurement.isEmpty {
                Text(actionData.formattedMeasurement)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Date (relative formatting)
            Text(actionData.logTime, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 140, height: 160)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            actionToEdit = actionData
        }
        .contextMenu {
            Button {
                actionToEdit = actionData
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                actionToDelete = actionData
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helper Methods

    /// Delete goal with confirmation
    private func deleteGoal(_ goalData: GoalData) {
        Task {
            try? await dataStore.deleteGoal(goalData)
            goalToDelete = nil
        }
    }

    /// Delete action with confirmation
    private func deleteAction(_ actionData: ActionData) {
        Task {
            try? await dataStore.deleteAction(actionData)
            actionToDelete = nil
        }
    }

    // MARK: - Toolbar

    /// Toolbar items for HomeView
    ///
    /// **Pattern**: Declarative @ToolbarContentBuilder for reusability
    /// **Actions**: All menu items use type-safe NavigationRoute
    /// **Organization**: Grouped by function (Data, Sync, Maintenance, System)
    @ToolbarContentBuilder
    private var homeToolbarItems: some ToolbarContent {
        // Create Menu (Goal or Action)
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showingCreateGoal = true
                } label: {
                    Label("Create Goal", systemImage: "target")
                }

                Button {
                    showingLogAction = true
                } label: {
                    Label("Log Action", systemImage: "checkmark.circle")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.blue)
            }
            .help("Create Goal or Log Action")
        }

        // Menu button (organized by feature category)
        ToolbarItem(placement: .automatic) {
            Menu {
                // Data Management Section
                Section("Data") {
                    Button {
                        navigationCoordinator.navigate(to: .exportData)
                    } label: {
                        Label("Import/Export CSV", systemImage: "square.and.arrow.up")
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
                }

                // Sync Section
                Section("Sync") {
                    Button {
                        navigationCoordinator.navigate(to: .cloudKitSync)
                    } label: {
                        Label("CloudKit Sync", systemImage: "icloud")
                    }

                    #if os(iOS)
                        Button {
                            navigationCoordinator.navigate(to: .healthSync)
                        } label: {
                            Label("Import from Health", systemImage: "heart.text.square")
                        }
                    #endif
                }

                // System Section
                Section("System") {
                    Button {
                        navigationCoordinator.navigate(to: .settings)
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
            }
            .help("More Options")
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
