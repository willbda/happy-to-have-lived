//
// WorkoutsTestView.swift
// Written by Claude Code on 2025-11-03
//
// PURPOSE:
// Simple test view to validate HealthKit data flow on iOS.
// Displays workouts for a selected date with authorization handling.
//
// USAGE:
// NavigationStack {
//     WorkoutsTestView()
// }

#if os(iOS)
import SwiftUI
import HealthKit
import Models
import Services

/// Test view for viewing Apple Health workouts
///
/// This is a minimal implementation to validate:
/// - HealthKit authorization flow
/// - Workout data fetching
/// - Data display in SwiftUI
///
/// Future: Expand to full-featured workout viewer with details, charts, etc.
public struct WorkoutsTestView: View {
    // Don't use @State for singleton - just observe it directly
    // HealthKitManager is @Observable, so SwiftUI will track changes automatically

    @Environment(\.openURL) private var openURL
    private let healthManager = HealthKitManager.shared

    @State private var selectedDate: Date = Date()
    @State private var workouts: [HealthWorkout] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Selection mode for saving workouts
    @State private var isSelecting = false
    @State private var selectedWorkouts: Set<UUID> = []
    @State private var importService = HealthKitImportService()
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    @State private var savedCount = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Date Picker at top
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.automatic)
            .padding()
            .background(.background.secondary)
            .onChange(of: selectedDate) { _, newDate in
                Task {
                    await loadWorkouts(for: newDate)
                }
            }

            // Content fills remaining space
            contentView
        }
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !workouts.isEmpty {
                    if isSelecting {
                        Button("Cancel") {
                            isSelecting = false
                            selectedWorkouts.removeAll()
                        }
                    } else {
                        Button("Select") {
                            isSelecting = true
                        }
                    }
                }
            }

            // Note: Changed from .bottomBar to avoid conflicts with TabView's floating tab bar in iOS 26
            // Using navigationBarLeading keeps the save button accessible without layout conflicts
            // Removed .borderedProminent to avoid layout conflicts during iOS 26 nav bar animations
            ToolbarItem(placement: .navigationBarLeading) {
                if isSelecting && !selectedWorkouts.isEmpty {
                    Button {
                        Task {
                            await saveSelectedWorkouts()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("Save \(selectedWorkouts.count)", systemImage: "square.and.arrow.down")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .alert("Saved Successfully", isPresented: $showingSaveSuccess) {
            Button("OK") {
                showingSaveSuccess = false
                isSelecting = false
                selectedWorkouts.removeAll()
            }
        } message: {
            Text("\(savedCount) workout\(savedCount == 1 ? "" : "s") saved to your Actions")
        }
        // FIX: Add bottom safe area inset for iOS 26 floating tab bar
        // The "Liquid Glass" tab bar floats above content, so we need to ensure
        // scrollable content doesn't get occluded by it
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .task {
            // Check authorization status first
            let hasAuth = healthManager.checkAuthorizationStatus()

            // Only try to load workouts if we think we might have permission
            // If auth is .notDetermined, we'll show the prompt instead
            if hasAuth {
                await loadWorkouts(for: selectedDate)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        // Prioritize actual data over authorization status
        // If we have workouts or are loading, show that state
        if isLoading {
            loadingView
        } else if !workouts.isEmpty {
            // We have workouts - show them!
            workoutsList
        } else if let error = errorMessage {
            // Query failed with error
            // Check if it's an authorization error
            if error.contains("Authorization not determined") || error.contains("not authorized") {
                // Show authorization prompt instead of error
                authorizationNeededView
            } else if healthManager.authorizationStatus == .unavailable {
                unavailableView
            } else {
                errorView(error)
            }
        } else {
            // No workouts, no errors - check authorization
            switch healthManager.authorizationStatus {
            case .notDetermined:
                authorizationNeededView
            case .denied:
                deniedView
            case .unavailable:
                unavailableView
            case .authorized:
                // Authorized but no workouts for this date
                emptyView
            }
        }
    }

    // MARK: - Authorization States

    private var authorizationNeededView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                Text("HealthKit Authorization Required")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Grant access to view your workout history")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    print("🔘 Grant Access button tapped")
                    Task {
                        print("📱 Starting authorization task...")

                        // Clear any previous error messages
                        errorMessage = nil

                        do {
                            print("📱 Calling requestAuthorization...")
                            try await healthManager.requestAuthorization()
                            print("📱 Authorization request completed, status: \(healthManager.authorizationStatus)")

                            // Try loading workouts regardless of status
                            // If permission was granted, it will work
                            // If denied, we'll get a proper error
                            await loadWorkouts(for: selectedDate)
                        } catch {
                            print("❌ Authorization failed: \(error)")
                            errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Grant Access", systemImage: "lock.open")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)

                Text("If you previously denied access, go to Settings > Health > Data Access & Devices")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding()
        }
    }

    private var deniedView: some View {
        ScrollView {
            VStack(spacing: 20) {

                Text("Access Denied")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Enable HealthKit access in Settings to view workouts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    // Open Settings
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Open Settings", systemImage: "gearshape")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
            }
            .padding()
        }
    }

    private var unavailableView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "heart.slash")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray)

                Text("HealthKit Unavailable")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("HealthKit is not available on this device")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    // MARK: - Content States

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Loading workouts...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func errorView(_ message: String) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                Text("Error Loading Workouts")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task {
                        await loadWorkouts(for: selectedDate)
                    }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "figure.run.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray)

                Text("No Workouts")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("No workouts found for \(formattedDate)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Try selecting a different date or add workouts in the Health app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    private var workoutsList: some View {
        List {
            Section {
                ForEach(workouts) { workout in
                    if isSelecting {
                        // Selection mode: show checkbox
                        Button {
                            toggleSelection(workout)
                        } label: {
                            HStack {
                                Image(systemName: selectedWorkouts.contains(workout.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedWorkouts.contains(workout.id) ? .blue : .gray)
                                    .imageScale(.large)

                                WorkoutRowView(workout: workout)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Normal mode: navigation link
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            WorkoutRowView(workout: workout)
                        }
                    }
                }
            } header: {
                Text("\(workouts.count) workout\(workouts.count == 1 ? "" : "s") on \(formattedDate)")
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, isSelecting ? .constant(.active) : .constant(.inactive))
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: selectedDate)
    }

    private func loadWorkouts(for date: Date) async {
        // Don't check authorization status - just try to query
        // HealthKit will return an error if permission was actually denied
        // This is the recommended approach for read-only HealthKit access

        isLoading = true
        errorMessage = nil

        do {
            let hkWorkouts = try await healthManager.fetchWorkouts(for: date)
            workouts = hkWorkouts.map { HealthWorkout(from: $0) }
            // HealthKitManager automatically updates authorizationStatus when query succeeds
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func toggleSelection(_ workout: HealthWorkout) {
        if selectedWorkouts.contains(workout.id) {
            selectedWorkouts.remove(workout.id)
        } else {
            selectedWorkouts.insert(workout.id)
        }
    }

    private func saveSelectedWorkouts() async {
        isSaving = true
        defer { isSaving = false }

        // Get selected workout objects
        let workoutsToSave = workouts.filter { selectedWorkouts.contains($0.id) }

        do {
            let savedActions = try await importService.importWorkouts(workoutsToSave)
            savedCount = savedActions.count
            showingSaveSuccess = true
            print("✅ Saved \(savedCount) workouts as Actions")
        } catch {
            errorMessage = "Failed to save workouts: \(error.localizedDescription)"
            print("❌ Failed to save workouts: \(error)")
        }
    }
}

// MARK: - Workout Row

/// Row view for displaying a single workout
private struct WorkoutRowView: View {
    let workout: HealthWorkout

    var body: some View {
        HStack(spacing: 12) {
            // Activity Icon
            Image(systemName: workout.iconName)
                .font(.title2)
                .foregroundStyle(.red)
                .frame(width: 40, height: 40)
                .background(Color.red.opacity(0.1))
                .clipShape(Circle())

            // Workout Info
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.activityName)
                    .font(.headline)

                Text(workout.summaryLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: workout.startDate)
        let end = formatter.string(from: workout.endDate)
        return "\(start) - \(end)"
    }
}

// MARK: - Preview

#Preview("With Workouts") {
    NavigationStack {
        WorkoutsTestView()
    }
}

#Preview("Empty State") {
    NavigationStack {
        WorkoutsTestView()
    }
}

#else
// MARK: - macOS Stub

import SwiftUI

public struct WorkoutsTestView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("HealthKit Not Available")
                .font(.title)
                .fontWeight(.bold)

            Text("HealthKit is only available on iOS")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Workouts")
    }
}

#Preview {
    NavigationStack {
        WorkoutsTestView()
    }
}

#endif
