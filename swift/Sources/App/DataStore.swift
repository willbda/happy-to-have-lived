//
// DataStore.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Central @Observable store for all app data
// ARCHITECTURE: Single source of truth, delegates to repositories/coordinators
// PATTERN: Apple's declarative SwiftUI pattern (see AddRichGraphicsToYourSwiftUIApp)
//
// RESPONSIBILITIES:
// - Hold all app data (goals, actions, values, terms)
// - Provide methods for CRUD operations
// - Automatically update state after database operations
// - Eliminate need for manual refresh calls in views
//
// DATA FLOW:
// App creates DataStore → Injects via environment → Views observe/mutate
//
// BENEFITS vs ViewModels:
// - Single source of truth (not separate list/form ViewModels)
// - Automatic state propagation (no manual refresh)
// - Truly declarative (SwiftUI reacts to changes)
// - Simpler testing (one store vs 8 ViewModels)
//

import Foundation
import Observation
import Dependencies
import Services
import Models
import SQLiteData
import Combine
import GRDB

/// Central data store for all app data
///
/// **PATTERN**: Apple's @Observable store pattern
/// - Single source of truth for all entities
/// - Views receive environment object or bindings
/// - Changes propagate automatically via @Observable
///
/// **USAGE**:
/// ```swift
/// // In App:
/// @State private var dataStore = DataStore()
///
/// ContentView()
///     .environment(dataStore)
///
/// // In View:
/// @Environment(DataStore.self) var dataStore
///
/// List {
///     ForEach(dataStore.goals) { goal in
///         GoalRow(goal: goal)
///     }
/// }
/// ```
@Observable
@MainActor
public final class DataStore {

    // MARK: - Observable State

    /// All goals in the app
    public var goals: [GoalData] = []

    /// All actions in the app
    public var actions: [ActionData] = []

    /// All personal values in the app
    public var values: [PersonalValueData] = []

    /// All terms (10-week periods) in the app
    public var terms: [TimePeriodData] = []

    /// All milestones in the app
    public var milestones: [MilestoneWithDetails] = []

    /// All obligations in the app
    public var obligations: [ObligationWithDetails] = []

    /// All measures (catalog of measurement units)
    public var measures: [MeasureData] = []

    /// Loading state for UI feedback
    public var isLoading: Bool = false

    /// Error message for user display
    public var errorMessage: String?

    // MARK: - Computed Properties

    /// Whether there's an error to display
    public var hasError: Bool {
        errorMessage != nil
    }

    /// Active goals (filtered by date range)
    /// Active means: no target date OR target date is in the future
    public var activeGoals: [GoalData] {
        let now = Date()
        return goals.filter { goal in
            if let targetDate = goal.targetDate {
                return targetDate >= now
            }
            return true  // No target date = always active
        }
    }

    /// Recent actions (sorted by most recent first)
    public var recentActions: [ActionData] {
        actions.sorted { $0.logTime > $1.logTime }
    }

    // MARK: - Action Filtering Helpers

    /// Get actions that contribute to a specific goal
    ///
    /// **Use Case**: Display actions on GoalDetailView, calculate progress for goal card
    /// **Performance**: O(n) filter on actions array (acceptable for typical action counts)
    public func actionsForGoal(_ goalId: UUID) -> [ActionData] {
        actions.filter { action in
            action.contributions.contains { $0.goalId == goalId }
        }
    }

    // MARK: - Dependencies

    /// Database dependency (injected, not stored as property)
    /// Internal access for GreetingService and other internal services
    @ObservationIgnored
    @Dependency(\.defaultDatabase) internal var database

    // MARK: - ValueObservation Subscriptions

    /// Combine cancellables for database observations
    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Initialization

    public init() {
        // NOTE: Don't start observing in init() - database may not be configured yet!
        // Call startObserving() explicitly after DatabaseBootstrap.configure() runs.
        //
        // WHY: @State properties initialize BEFORE App.init() runs, so DataStore
        // is created before DatabaseBootstrap.configure() sets up the real database.
        // If we observe here, we'll connect to the default in-memory database instead
        // of the production SQLite database.
        //
        // PATTERN: App creates DataStore → App.init() configures DB → App calls startObserving()
    }

    /// Start observing database changes
    ///
    /// **IMPORTANT**: Must be called AFTER DatabaseBootstrap.configure() to ensure
    /// observations connect to the production database, not the in-memory default.
    ///
    /// **When to call**: In App's .task modifier, after database is configured
    ///
    /// **Pattern**:
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     @State private var dataStore: DataStore?
    ///
    ///     init() {
    ///         DatabaseBootstrap.configure()  // ← Database ready
    ///     }
    ///
    ///     var body: some Scene {
    ///         WindowGroup {
    ///             ContentView()
    ///         }
    ///         .task {
    ///             if dataStore == nil {
    ///                 let store = DataStore()
    ///                 store.startObserving()  // ← Start observations
    ///                 dataStore = store
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    public func startObserving() {
        startObservingDatabase()
    }

    /// Start ValueObservation for all entity types
    ///
    /// **Pattern**: Subscribe to repository observations (repositories handle ValueObservation)
    /// **Tracking**: Automatic - GRDB figures out which tables affect each query
    /// **Updates**: Any write to relevant tables triggers re-fetch + @Observable propagation
    ///
    /// **Architecture**:
    /// - BaseRepository provides `observeAll()` → Combine publisher
    /// - DataStore subscribes → Updates @Observable properties
    /// - SwiftUI views observe DataStore → Automatic UI updates
    private func startObservingDatabase() {
        // Goals observation
        GoalRepository(database: database)
            .observeAll()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Goals observation failed: \(error)")
                    }
                },
                receiveValue: { [weak self] newGoals in
                    self?.goals = newGoals
                    print("🔄 Goals updated: \(newGoals.count)")
                }
            )
            .store(in: &cancellables)

        // Actions observation
        ActionRepository(database: database)
            .observeAll()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Actions observation failed: \(error)")
                    }
                },
                receiveValue: { [weak self] newActions in
                    self?.actions = newActions
                    print("🔄 Actions updated: \(newActions.count)")
                }
            )
            .store(in: &cancellables)

        // PersonalValues observation
        PersonalValueRepository(database: database)
            .observeAll()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Values observation failed: \(error)")
                    }
                },
                receiveValue: { [weak self] newValues in
                    self?.values = newValues
                    print("🔄 Values updated: \(newValues.count)")
                }
            )
            .store(in: &cancellables)

        // TimePeriods observation
        TimePeriodRepository(database: database)
            .observeAll()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Terms observation failed: \(error)")
                    }
                },
                receiveValue: { [weak self] newTerms in
                    self?.terms = newTerms
                    print("🔄 Terms updated: \(newTerms.count)")
                }
            )
            .store(in: &cancellables)

        // Milestones observation
        MilestoneRepository(database: database)
            .observeAll()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Milestones observation failed: \(error)")
                    }
                },
                receiveValue: { [weak self] newMilestones in
                    self?.milestones = newMilestones
                    print("🔄 Milestones updated: \(newMilestones.count)")
                }
            )
            .store(in: &cancellables)

        // Obligations observation
        ObligationRepository(database: database)
            .observeAll()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Obligations observation failed: \(error)")
                    }
                },
                receiveValue: { [weak self] newObligations in
                    self?.obligations = newObligations
                    print("🔄 Obligations updated: \(newObligations.count)")
                }
            )
            .store(in: &cancellables)

        // Measures observation
        MeasureRepository(database: database)
            .observeAll()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Measures observation failed: \(error)")
                    }
                },
                receiveValue: { [weak self] newMeasures in
                    self?.measures = newMeasures
                    print("🔄 Measures updated: \(newMeasures.count)")
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Goals Operations

    /// Load all goals from database
    ///
    /// **NOTE**: With ValueObservation, this is rarely needed!
    /// **Usage**: Only for manual refresh (pull-to-refresh)
    /// **Normal flow**: ValueObservation automatically updates on any database change
    public func loadGoals() async {
        isLoading = true
        errorMessage = nil

        do {
            let repository = GoalRepository(database: database)
            goals = try await repository.fetchAll()
            print("✅ DataStore: Manual load - \(goals.count) goals")
        } catch let error as ValidationError {
            errorMessage = error.userMessage
            print("❌ DataStore ValidationError: \(error.userMessage)")
        } catch {
            errorMessage = "Failed to load goals: \(error.localizedDescription)"
            print("❌ DataStore: \(error)")
        }

        isLoading = false
    }

    /// Create a new goal
    ///
    /// **Pattern**: Coordinator creates goal → ValueObservation auto-updates UI
    /// **Result**: List views automatically update (no manual reload needed!)
    public func createGoal(from formData: GoalFormData) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = GoalCoordinator(database: database)
            _ = try await coordinator.create(from: formData)
            errorMessage = nil

            print("✅ DataStore: Created goal (ValueObservation will update UI)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to create goal - \(error)")
            throw error
        }
    }

    /// Update an existing goal
    ///
    /// **Pattern**: Coordinator updates goal, reload all to get fresh data
    /// **Result**: List views automatically update (via @Observable)
    public func updateGoal(
        id: UUID,
        from formData: GoalFormData,
        existing: GoalData
    ) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            // Reconstruct entities from GoalData
            let goal = Goal(
                expectationId: existing.expectationId,
                startDate: existing.startDate,
                targetDate: existing.targetDate,
                actionPlan: existing.actionPlan,
                expectedTermLength: existing.expectedTermLength,
                id: existing.id
            )

            let expectation = Expectation(
                title: existing.title,
                detailedDescription: existing.detailedDescription,
                freeformNotes: existing.freeformNotes,
                expectationType: .goal,
                expectationImportance: existing.expectationImportance,
                expectationUrgency: existing.expectationUrgency,
                logTime: existing.logTime,
                id: existing.expectationId
            )

            let existingTargets = existing.measureTargets.map { target in
                ExpectationMeasure(
                    expectationId: existing.expectationId,
                    measureId: target.measureId,
                    targetValue: target.targetValue,
                    createdAt: target.createdAt,
                    freeformNotes: target.freeformNotes,
                    id: target.id
                )
            }

            let existingAlignments = existing.valueAlignments.map { alignment in
                GoalRelevance(
                    goalId: existing.id,
                    valueId: alignment.valueId,
                    alignmentStrength: alignment.alignmentStrength,
                    relevanceNotes: alignment.relevanceNotes,
                    createdAt: alignment.createdAt,
                    id: alignment.id
                )
            }

            let existingAssignment: TermGoalAssignment? = existing.termAssignment.map { assignment in
                TermGoalAssignment(
                    id: assignment.id,
                    termId: assignment.termId,
                    goalId: existing.id,
                    assignmentOrder: assignment.assignmentOrder,
                    createdAt: assignment.createdAt
                )
            }

            // Update via coordinator
            let coordinator = GoalCoordinator(database: database)
            _ = try await coordinator.update(
                goal: goal,
                expectation: expectation,
                existingTargets: existingTargets,
                existingAlignments: existingAlignments,
                existingAssignment: existingAssignment,
                from: formData
            )

            // Reload all goals to get fresh data
            errorMessage = nil

            print("✅ DataStore: Updated goal")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to update goal - \(error)")
            throw error
        }
    }

    /// Delete a goal
    ///
    /// **Pattern**: Coordinator deletes, store removes from array
    /// **Result**: List views automatically update
    public func deleteGoal(_ goalData: GoalData) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = GoalCoordinator(database: database)
            try await coordinator.delete(goalData)

            // Remove from in-memory array
            goals.removeAll { $0.id == goalData.id }
            errorMessage = nil

            print("✅ DataStore: Deleted goal '\(goalData.title ?? "")'")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to delete goal - \(error)")
            throw error
        }
    }

    // MARK: - Actions Operations

    /// Load all actions from database
    public func loadActions() async {
        isLoading = true
        errorMessage = nil

        do {
            let repository = ActionRepository(database: database)
            actions = try await repository.fetchAll()
            print("✅ DataStore: Loaded \(actions.count) actions")
        } catch let error as ValidationError {
            errorMessage = error.userMessage
            print("❌ DataStore ValidationError: \(error.userMessage)")
        } catch {
            errorMessage = "Failed to load actions: \(error.localizedDescription)"
            print("❌ DataStore: \(error)")
        }

        isLoading = false
    }

    /// Create a new action
    public func createAction(from formData: ActionFormData) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = ActionCoordinator(database: database)
            _ = try await coordinator.create(from: formData)

            errorMessage = nil

            print("✅ DataStore: Created action")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to create action - \(error)")
            throw error
        }
    }

    /// Update an existing action
    ///
    /// **Pattern**: Coordinator updates action → ValueObservation auto-updates UI
    /// **Result**: List views automatically update (via @Observable)
    public func updateAction(
        id: UUID,
        from formData: ActionFormData,
        existing: ActionData
    ) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            // Reconstruct entities from ActionData
            let action = Action(
                title: existing.title,
                detailedDescription: existing.detailedDescription,
                freeformNotes: existing.freeformNotes,
                durationMinutes: existing.durationMinutes,
                startTime: existing.startTime,
                logTime: existing.logTime,
                id: existing.id
            )

            let existingMeasurements = existing.measurements.map { measurement in
                MeasuredAction(
                    actionId: existing.id,
                    measureId: measurement.measureId,
                    value: measurement.value,
                    createdAt: measurement.createdAt,
                    id: measurement.id
                )
            }

            let existingContributions = existing.contributions.map { contribution in
                ActionGoalContribution(
                    actionId: existing.id,
                    goalId: contribution.goalId,
                    contributionAmount: contribution.contributionAmount,
                    measureId: contribution.measureId,
                    createdAt: contribution.createdAt,
                    id: contribution.id
                )
            }

            // Update via coordinator
            let coordinator = ActionCoordinator(database: database)
            _ = try await coordinator.update(
                action: action,
                measurements: existingMeasurements,
                contributions: existingContributions,
                from: formData
            )

            errorMessage = nil

            print("✅ DataStore: Updated action")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to update action - \(error)")
            throw error
        }
    }

    /// Delete an action
    public func deleteAction(_ actionData: ActionData) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = ActionCoordinator(database: database)
            try await coordinator.delete(actionData)

            actions.removeAll { $0.id == actionData.id }
            errorMessage = nil

            print("✅ DataStore: Deleted action '\(actionData.title ?? "")'")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to delete action - \(error)")
            throw error
        }
    }

    // MARK: - Values Operations

    /// Load all personal values from database
    public func loadValues() async {
        isLoading = true
        errorMessage = nil

        do {
            let repository = PersonalValueRepository(database: database)
            values = try await repository.fetchAll()
            print("✅ DataStore: Loaded \(values.count) values")
        } catch let error as ValidationError {
            errorMessage = error.userMessage
            print("❌ DataStore ValidationError: \(error.userMessage)")
        } catch {
            errorMessage = "Failed to load values: \(error.localizedDescription)"
            print("❌ DataStore: \(error)")
        }

        isLoading = false
    }

    /// Create a new personal value
    public func createValue(from formData: PersonalValueFormData) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = PersonalValueCoordinator(database: database)
            _ = try await coordinator.create(from: formData)

            errorMessage = nil

            print("✅ DataStore: Created value")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to create value - \(error)")
            throw error
        }
    }

    /// Update an existing personal value
    ///
    /// **Pattern**: Coordinator updates value → ValueObservation auto-updates UI
    /// **Result**: List views automatically update (via @Observable)
    public func updateValue(
        id: UUID,
        from formData: PersonalValueFormData,
        existing: PersonalValueData
    ) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            // Reconstruct entity from PersonalValueData
            // Convert valueLevel string to enum (PersonalValueData stores as String for Codable)
            let valueLevel = ValueLevel(rawValue: existing.valueLevel) ?? .general

            let value = PersonalValue(
                title: existing.title,
                detailedDescription: existing.detailedDescription,
                freeformNotes: existing.freeformNotes,
                priority: existing.priority,
                valueLevel: valueLevel,
                lifeDomain: existing.lifeDomain,
                alignmentGuidance: existing.alignmentGuidance,
                logTime: existing.logTime,
                id: existing.id
            )

            // Update via coordinator
            let coordinator = PersonalValueCoordinator(database: database)
            _ = try await coordinator.update(value: value, from: formData)

            errorMessage = nil

            print("✅ DataStore: Updated value")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to update value - \(error)")
            throw error
        }
    }

    /// Delete a personal value
    public func deleteValue(_ valueData: PersonalValueData) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = PersonalValueCoordinator(database: database)
            try await coordinator.delete(valueData)

            values.removeAll { $0.id == valueData.id }
            errorMessage = nil

            print("✅ DataStore: Deleted value '\(valueData.title)'")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to delete value - \(error)")
            throw error
        }
    }

    // MARK: - Terms Operations

    /// Load all terms from database
    public func loadTerms() async {
        isLoading = true
        errorMessage = nil

        do {
            let repository = TimePeriodRepository(database: database)
            terms = try await repository.fetchAll()
            print("✅ DataStore: Loaded \(terms.count) terms")
        } catch let error as ValidationError {
            errorMessage = error.userMessage
            print("❌ DataStore ValidationError: \(error.userMessage)")
        } catch {
            errorMessage = "Failed to load terms: \(error.localizedDescription)"
            print("❌ DataStore: \(error)")
        }

        isLoading = false
    }

    /// Create a new term
    public func createTerm(from formData: TimePeriodFormData) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = TimePeriodCoordinator(database: database)
            _ = try await coordinator.create(from: formData)

            errorMessage = nil

            print("✅ DataStore: Created term")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to create term - \(error)")
            throw error
        }
    }

    /// Update an existing term
    ///
    /// **Pattern**: Coordinator updates term → ValueObservation auto-updates UI
    /// **Result**: List views automatically update (via @Observable)
    public func updateTerm(
        id: UUID,
        from formData: TimePeriodFormData,
        existing: TimePeriodData
    ) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            // Reconstruct entities from TimePeriodData
            let timePeriod = TimePeriod(
                title: existing.timePeriodTitle,
                detailedDescription: nil,  // Not stored in TimePeriodData
                freeformNotes: nil,  // Not stored in TimePeriodData
                startDate: existing.startDate,
                endDate: existing.endDate,
                logTime: Date(),  // Will be preserved by coordinator
                id: existing.timePeriodId
            )

            let goalTerm = GoalTerm(
                timePeriodId: existing.timePeriodId,
                termNumber: existing.termNumber,
                theme: existing.theme,
                reflection: existing.reflection,
                status: existing.status.flatMap { TermStatus(rawValue: $0) },
                id: existing.id
            )

            // Update via coordinator
            let coordinator = TimePeriodCoordinator(database: database)
            _ = try await coordinator.update(
                timePeriod: timePeriod,
                goalTerm: goalTerm,
                from: formData
            )

            errorMessage = nil

            print("✅ DataStore: Updated term")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to update term - \(error)")
            throw error
        }
    }

    /// Delete a term
    public func deleteTerm(_ termData: TimePeriodData) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = TimePeriodCoordinator(database: database)
            try await coordinator.delete(termData)

            terms.removeAll { $0.id == termData.id }
            errorMessage = nil

            print("✅ DataStore: Deleted term \(termData.termNumber)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to delete term - \(error)")
            throw error
        }
    }

    // MARK: - Milestones Operations

    /// Load all milestones from database
    ///
    /// **NOTE**: With ValueObservation, this is rarely needed!
    /// **Usage**: Only for manual refresh (pull-to-refresh)
    /// **Normal flow**: ValueObservation automatically updates on any database change
    public func loadMilestones() async {
        isLoading = true
        errorMessage = nil

        do {
            let repository = MilestoneRepository(database: database)
            milestones = try await repository.fetchAll()
            print("✅ DataStore: Loaded \(milestones.count) milestones")
        } catch let error as ValidationError {
            errorMessage = error.userMessage
            print("❌ DataStore ValidationError: \(error.userMessage)")
        } catch {
            errorMessage = "Failed to load milestones: \(error.localizedDescription)"
            print("❌ DataStore: \(error)")
        }

        isLoading = false
    }

    /// Create a new milestone
    ///
    /// **Pattern**: Coordinator creates milestone → ValueObservation auto-updates UI
    /// **Result**: List views automatically update (no manual reload needed!)
    public func createMilestone(from formData: MilestoneFormData) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = MilestoneCoordinator(database: database)
            _ = try await coordinator.create(from: formData)
            errorMessage = nil

            print("✅ DataStore: Created milestone (ValueObservation will update UI)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to create milestone - \(error)")
            throw error
        }
    }

    /// Delete a milestone
    ///
    /// **Pattern**: Coordinator deletes, ValueObservation updates UI
    /// **Result**: List views automatically update
    public func deleteMilestone(_ milestoneData: MilestoneWithDetails) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = MilestoneCoordinator(database: database)
            try await coordinator.delete(milestoneId: milestoneData.id)

            milestones.removeAll { $0.id == milestoneData.id }
            errorMessage = nil

            print("✅ DataStore: Deleted milestone '\(milestoneData.expectation.title ?? "")'")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to delete milestone - \(error)")
            throw error
        }
    }

    // MARK: - Measures Operations

    /// Load all measures from database
    ///
    /// **NOTE**: With ValueObservation, this is rarely needed!
    /// **Usage**: Only for manual refresh (pull-to-refresh)
    /// **Normal flow**: ValueObservation automatically updates on any database change
    public func loadMeasures() async {
        isLoading = true
        errorMessage = nil

        do {
            let repository = MeasureRepository(database: database)
            measures = try await repository.fetchAll()
            print("✅ DataStore: Loaded \(measures.count) measures")
        } catch let error as ValidationError {
            errorMessage = error.userMessage
            print("❌ DataStore ValidationError: \(error.userMessage)")
        } catch {
            errorMessage = "Failed to load measures: \(error.localizedDescription)"
            print("❌ DataStore: \(error)")
        }

        isLoading = false
    }

    /// Create or retrieve an existing measure
    ///
    /// **Pattern**: Uses MeasureCoordinator.getOrCreate() for idempotent creation
    /// **Result**: Returns existing measure if duplicate, creates new if not
    ///
    /// **Use Case**: Inline measure creation from form components
    /// - MeasurementInputRow (action measurement input)
    /// - MetricTargetRow (goal metric targets)
    ///
    /// **Why DataStore?**
    /// - Views can't use @Dependency directly (SwiftUI structs)
    /// - Centralizes database access through single source of truth
    /// - ValueObservation automatically updates measures array
    @MainActor
    public func createMeasure(
        unit: String,
        measureType: String,
        title: String? = nil
    ) async throws -> Measure {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = MeasureCoordinator(database: database)
            let measure = try await coordinator.getOrCreate(
                unit: unit,
                measureType: measureType,
                title: title
            )
            errorMessage = nil

            print("✅ DataStore: Created/retrieved measure '\(measure.title ?? "")' (ValueObservation will update UI)")
            return measure
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to create measure - \(error)")
            throw error
        }
    }

    // MARK: - Obligations Operations

    /// Load all obligations from database
    ///
    /// **NOTE**: With ValueObservation, this is rarely needed!
    /// **Usage**: Only for manual refresh (pull-to-refresh)
    /// **Normal flow**: ValueObservation automatically updates on any database change
    public func loadObligations() async {
        isLoading = true
        errorMessage = nil

        do {
            let repository = ObligationRepository(database: database)
            obligations = try await repository.fetchAll()
            print("✅ DataStore: Loaded \(obligations.count) obligations")
        } catch let error as ValidationError {
            errorMessage = error.userMessage
            print("❌ DataStore ValidationError: \(error.userMessage)")
        } catch {
            errorMessage = "Failed to load obligations: \(error.localizedDescription)"
            print("❌ DataStore: \(error)")
        }

        isLoading = false
    }

    /// Create a new obligation
    ///
    /// **Pattern**: Coordinator creates obligation → ValueObservation auto-updates UI
    /// **Result**: List views automatically update (no manual reload needed!)
    public func createObligation(from formData: ObligationFormData) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = ObligationCoordinator(database: database)
            _ = try await coordinator.create(from: formData)
            errorMessage = nil

            print("✅ DataStore: Created obligation (ValueObservation will update UI)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to create obligation - \(error)")
            throw error
        }
    }

    /// Delete an obligation
    ///
    /// **Pattern**: Coordinator deletes, ValueObservation updates UI
    /// **Result**: List views automatically update
    public func deleteObligation(_ obligationData: ObligationWithDetails) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinator = ObligationCoordinator(database: database)
            try await coordinator.delete(obligationId: obligationData.id)

            obligations.removeAll { $0.id == obligationData.id }
            errorMessage = nil

            print("✅ DataStore: Deleted obligation '\(obligationData.expectation.title ?? "")'")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DataStore: Failed to delete obligation - \(error)")
            throw error
        }
    }
}
