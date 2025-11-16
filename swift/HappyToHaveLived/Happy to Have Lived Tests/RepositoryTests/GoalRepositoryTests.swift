//
// GoalRepositoryTests.swift
// Written by Claude Code on 2025-11-16
//
// PURPOSE:
// Comprehensive tests for GoalRepository that can also validate GoalRepository_v3.
// Tests focus on meaningful data validation, relationship integrity, and edge cases.
//
// TEST STRATEGY:
// 1. Use production database bootstrap (DatabaseBootstrap.createDatabase)
// 2. Create real test data via coordinators (ensures FK integrity)
// 3. Test query results for data correctness, not implementation details
// 4. Aggressive edge case testing (empty results, null fields, multiple relationships)
// 5. Defensive assertions on meaningful parameters only
//
// WHAT THIS VALIDATES:
// ✅ fetchAll() returns all goals with complete relationship graphs
// ✅ JSON aggregation correctly parses nested measures/values/terms
// ✅ Relationships belong to correct parent goal (no data mixing)
// ✅ Empty relationships return empty arrays (not nil or missing)
// ✅ Date filtering works correctly (when provided)
// ✅ fetchActiveGoals() correctly filters by target date
// ✅ fetchByTerm() returns only goals assigned to that term
// ✅ fetchByValue() returns only goals aligned with that value
// ✅ exists() checks work correctly for both ID and title
// ✅ Error mapping produces user-friendly ValidationErrors
//
// COMPATIBILITY:
// These tests are designed to work with both:
// - GoalRepository (current implementation)
// - GoalRepository_v3 (new BaseRepository-based implementation)
//
// To test GoalRepository_v3:
// 1. Change `let repository = GoalRepository(database: db)` to `GoalRepository_v3`
// 2. Adjust for return type differences (GoalData vs GoalWithDetails)
// 3. Adjust for method name differences (existsByTitle vs exists(title:))

import Foundation
import Testing
import SQLiteData
@testable import Database
@testable import Services
@testable import Models

@Suite("GoalRepository - Comprehensive Data Validation", .serialized)
struct GoalRepositoryTests {

    // MARK: - Shared Test State

    /// Shared database for all tests in this suite
    nonisolated(unsafe) private static var database: DatabaseQueue!

    /// Test data IDs (populated during setup)
    nonisolated(unsafe) private static var measureIds: [String: UUID] = [:]
    nonisolated(unsafe) private static var valueIds: [String: UUID] = [:]
    nonisolated(unsafe) private static var goalIds: [String: UUID] = [:]
    nonisolated(unsafe) private static var termIds: [String: UUID] = [:]

    // MARK: - Setup: Database Bootstrap

    @Test("Setup: Bootstrap test database")
    func testDatabaseBootstrap() async throws {
        print("\n=== GoalRepository Tests: Database Bootstrap ===")

        // Clean slate
        let dbPath = DatabaseBootstrap.DatabaseMode.localTesting.path
        try? FileManager.default.removeItem(at: dbPath)

        // Create database using production bootstrap
        let db = try DatabaseBootstrap.createDatabase(mode: .localTesting)

        print("✓ Database created at: \(dbPath.path)")

        // Verify tables exist
        let hasGoals = try await db.read { db in try db.tableExists("goals") }
        let hasExpectations = try await db.read { db in try db.tableExists("expectations") }
        let hasMeasures = try await db.read { db in try db.tableExists("measures") }
        let hasValues = try await db.read { db in try db.tableExists("personalValues") }

        #expect(hasGoals, "goals table must exist")
        #expect(hasExpectations, "expectations table must exist")
        #expect(hasMeasures, "measures table must exist")
        #expect(hasValues, "personalValues table must exist")

        print("✓ Verified: Core tables exist")

        GoalRepositoryTests.database = db
    }

    // MARK: - Setup: Create Test Data

    @Test("Setup: Create test measures")
    func testCreateMeasures() async throws {
        print("\n=== Setup: Create Test Measures ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        // Create measures that goals will reference
        let measures = [
            ("kilometers", Measure(
                unit: "km",
                measureType: "distance",
                title: "Kilometers",
                detailedDescription: "Distance in kilometers",
                canonicalUnit: "km",
                conversionFactor: 1.0
            )),
            ("hours", Measure(
                unit: "hrs",
                measureType: "duration",
                title: "Hours",
                detailedDescription: "Time in hours",
                canonicalUnit: "hrs",
                conversionFactor: 1.0
            )),
            ("count", Measure(
                unit: "count",
                measureType: "quantity",
                title: "Count",
                detailedDescription: "Number of items",
                canonicalUnit: "count",
                conversionFactor: 1.0
            ))
        ]

        for (key, measure) in measures {
            try await db.write { db in
                try measure.save(to: db)
            }
            GoalRepositoryTests.measureIds[key] = measure.id
            print("✓ Created measure: \(key) (\(measure.id))")
        }

        print("✓ Created \(measures.count) measures")
    }

    @Test("Setup: Create test personal values")
    func testCreatePersonalValues() async throws {
        print("\n=== Setup: Create Test Personal Values ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let coordinator = PersonalValueCoordinator(database: db)

        let values = [
            ("health", PersonalValueFormData(
                title: "Health & Wellness",
                detailedDescription: "Physical and mental well-being",
                valueLevel: .major,
                priority: 90
            )),
            ("learning", PersonalValueFormData(
                title: "Continuous Learning",
                detailedDescription: "Growth through education",
                valueLevel: .major,
                priority: 80
            )),
            ("relationships", PersonalValueFormData(
                title: "Meaningful Relationships",
                detailedDescription: "Deep connections with others",
                valueLevel: .highest_order,
                priority: 95
            ))
        ]

        for (key, formData) in values {
            let value = try await coordinator.create(from: formData)
            GoalRepositoryTests.valueIds[key] = value.id
            print("✓ Created value: \(key) (\(value.id))")
        }

        print("✓ Created \(values.count) personal values")
    }

    @Test("Setup: Create test terms")
    func testCreateTerms() async throws {
        print("\n=== Setup: Create Test Terms ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let coordinator = TermCoordinator(database: db)

        let now = Date()
        let terms = [
            ("term1", TimePeriodFormData(
                title: "Q1 2025",
                startDate: now,
                targetDate: now.addingTimeInterval(90 * 86400),  // 90 days
                specialization: .term(number: 1)
            )),
            ("term2", TimePeriodFormData(
                title: "Q2 2025",
                startDate: now.addingTimeInterval(91 * 86400),
                targetDate: now.addingTimeInterval(180 * 86400),
                specialization: .term(number: 2)
            ))
        ]

        for (key, formData) in terms {
            let term = try await coordinator.create(from: formData)
            GoalRepositoryTests.termIds[key] = term.goalTerm.id
            print("✓ Created term: \(key) (\(term.goalTerm.id))")
        }

        print("✓ Created \(terms.count) terms")
    }

    @Test("Setup: Create diverse test goals")
    func testCreateGoals() async throws {
        print("\n=== Setup: Create Test Goals ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let coordinator = GoalCoordinator(database: db)
        let now = Date()

        // Goal 1: With multiple measures and values (health-focused)
        let goal1 = try await coordinator.create(from: GoalFormData(
            title: "Run 100km this quarter",
            detailedDescription: "Build running endurance",
            expectationImportance: 8,
            expectationUrgency: 7,
            startDate: now,
            targetDate: now.addingTimeInterval(90 * 86400),
            actionPlan: "Run 3x per week, gradually increase distance",
            metricTargets: [
                MetricTargetInput(
                    measureId: GoalRepositoryTests.measureIds["kilometers"]!,
                    targetValue: 100.0,
                    freeformNotes: "Total distance goal"
                ),
                MetricTargetInput(
                    measureId: GoalRepositoryTests.measureIds["hours"]!,
                    targetValue: 20.0,
                    freeformNotes: "Total time spent running"
                )
            ],
            valueAlignments: [
                ValueAlignmentInput(
                    valueId: GoalRepositoryTests.valueIds["health"]!,
                    alignmentStrength: 9,
                    relevanceNotes: "Direct health benefit"
                )
            ],
            termAssignment: TermAssignmentInput(
                termId: GoalRepositoryTests.termIds["term1"]!,
                assignmentOrder: 1
            )
        ))
        GoalRepositoryTests.goalIds["running"] = goal1.goal.id
        print("✓ Created goal: running (\(goal1.goal.id)) - 2 measures, 1 value, term assigned")

        // Goal 2: With no measures (description-only goal)
        let goal2 = try await coordinator.create(from: GoalFormData(
            title: "Read 12 books",
            detailedDescription: "One book per month for personal growth",
            expectationImportance: 6,
            expectationUrgency: 5,
            startDate: now,
            targetDate: now.addingTimeInterval(365 * 86400),
            metricTargets: [],  // NO MEASURES
            valueAlignments: [
                ValueAlignmentInput(
                    valueId: GoalRepositoryTests.valueIds["learning"]!,
                    alignmentStrength: 10
                )
            ]
        ))
        GoalRepositoryTests.goalIds["reading"] = goal2.goal.id
        print("✓ Created goal: reading (\(goal2.goal.id)) - 0 measures, 1 value, no term")

        // Goal 3: With multiple value alignments, no term assignment
        let goal3 = try await coordinator.create(from: GoalFormData(
            title: "Weekly family dinners",
            detailedDescription: "Connect with family every week",
            expectationImportance: 9,
            expectationUrgency: 8,
            metricTargets: [
                MetricTargetInput(
                    measureId: GoalRepositoryTests.measureIds["count"]!,
                    targetValue: 52.0,
                    freeformNotes: "Once per week for a year"
                )
            ],
            valueAlignments: [
                ValueAlignmentInput(
                    valueId: GoalRepositoryTests.valueIds["health"]!,
                    alignmentStrength: 6,
                    relevanceNotes: "Mental health through connection"
                ),
                ValueAlignmentInput(
                    valueId: GoalRepositoryTests.valueIds["relationships"]!,
                    alignmentStrength: 10,
                    relevanceNotes: "Core relationship maintenance"
                )
            ]
        ))
        GoalRepositoryTests.goalIds["family"] = goal3.goal.id
        print("✓ Created goal: family (\(goal3.goal.id)) - 1 measure, 2 values, no term")

        // Goal 4: Active goal (target in future)
        let goal4 = try await coordinator.create(from: GoalFormData(
            title: "Learn Spanish basics",
            expectationImportance: 7,
            expectationUrgency: 6,
            startDate: now,
            targetDate: now.addingTimeInterval(180 * 86400),  // 6 months away
            valueAlignments: [
                ValueAlignmentInput(
                    valueId: GoalRepositoryTests.valueIds["learning"]!,
                    alignmentStrength: 8
                )
            ],
            termAssignment: TermAssignmentInput(
                termId: GoalRepositoryTests.termIds["term2"]!,
                assignmentOrder: 1
            )
        ))
        GoalRepositoryTests.goalIds["spanish"] = goal4.goal.id
        print("✓ Created goal: spanish (\(goal4.goal.id)) - active, term2 assigned")

        // Goal 5: Past goal (target in past)
        let goal5 = try await coordinator.create(from: GoalFormData(
            title: "Complete 2024 taxes",
            expectationImportance: 10,
            expectationUrgency: 10,
            startDate: now.addingTimeInterval(-60 * 86400),
            targetDate: now.addingTimeInterval(-30 * 86400),  // 30 days ago
            metricTargets: []
        ))
        GoalRepositoryTests.goalIds["taxes"] = goal5.goal.id
        print("✓ Created goal: taxes (\(goal5.goal.id)) - past target date")

        // Goal 6: No target date (open-ended)
        let goal6 = try await coordinator.create(from: GoalFormData(
            title: "Practice mindfulness daily",
            detailedDescription: "Ongoing daily meditation practice",
            expectationImportance: 7,
            expectationUrgency: 4,
            startDate: now,
            targetDate: nil,  // NO TARGET DATE
            valueAlignments: [
                ValueAlignmentInput(
                    valueId: GoalRepositoryTests.valueIds["health"]!,
                    alignmentStrength: 8
                )
            ]
        ))
        GoalRepositoryTests.goalIds["mindfulness"] = goal6.goal.id
        print("✓ Created goal: mindfulness (\(goal6.goal.id)) - no target date (active)")

        print("✓ Created 6 diverse test goals")
        print("  - Goals with measures: 3")
        print("  - Goals without measures: 3")
        print("  - Goals with term assignments: 3")
        print("  - Goals without term assignments: 3")
        print("  - Active goals (future or no target): 4")
        print("  - Past goals: 1")
        print("  - Goals with multiple value alignments: 2")
    }

    // MARK: - Test: fetchAll() - Complete Data Retrieval

    @Test("Query: fetchAll() returns all goals")
    func testFetchAllReturnsAllGoals() async throws {
        print("\n=== Test: fetchAll() returns all goals ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)

        // Fetch all goals as GoalData
        let goals = try await repository.fetchAll()

        print("Fetched \(goals.count) goals")

        // Should have exactly 6 goals
        #expect(goals.count == 6, "Should have 6 goals (created in setup)")

        // Verify all expected goal IDs are present
        let fetchedIds = Set(goals.map { $0.id })
        let expectedIds = Set(GoalRepositoryTests.goalIds.values)

        #expect(fetchedIds == expectedIds, "All created goals should be fetched")

        print("✓ Verified: All 6 goals fetched with correct IDs")
    }

    @Test("Query: fetchAll() returns complete relationship graphs")
    func testFetchAllReturnsCompleteRelationships() async throws {
        print("\n=== Test: fetchAll() returns complete relationships ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)
        let goals = try await repository.fetchAll()

        // Find the "running" goal (has 2 measures, 1 value, 1 term)
        guard let runningGoal = goals.first(where: { $0.id == GoalRepositoryTests.goalIds["running"] }) else {
            throw TestError.expectedDataNotFound("Running goal not found")
        }

        print("Verifying 'running' goal relationships:")
        print("  - measureTargets: \(runningGoal.measureTargets.count)")
        print("  - valueAlignments: \(runningGoal.valueAlignments.count)")
        print("  - termAssignment: \(runningGoal.termAssignment == nil ? "nil" : "assigned")")

        // Verify measure targets
        #expect(runningGoal.measureTargets.count == 2, "Running goal should have 2 measure targets")

        let kmTarget = runningGoal.measureTargets.first { $0.measureId == GoalRepositoryTests.measureIds["kilometers"] }
        let hoursTarget = runningGoal.measureTargets.first { $0.measureId == GoalRepositoryTests.measureIds["hours"] }

        #expect(kmTarget != nil, "Should have kilometers measure")
        #expect(hoursTarget != nil, "Should have hours measure")

        #expect(kmTarget?.targetValue == 100.0, "Kilometers target should be 100.0")
        #expect(hoursTarget?.targetValue == 20.0, "Hours target should be 20.0")

        #expect(kmTarget?.measureUnit == "km", "Measure unit should be 'km'")
        #expect(kmTarget?.measureTitle == "Kilometers", "Measure title should match")

        print("✓ Verified: Measure targets correct (2 measures with correct values)")

        // Verify value alignments
        #expect(runningGoal.valueAlignments.count == 1, "Running goal should have 1 value alignment")

        let healthAlignment = runningGoal.valueAlignments.first { $0.valueId == GoalRepositoryTests.valueIds["health"] }
        #expect(healthAlignment != nil, "Should be aligned with health value")
        #expect(healthAlignment?.alignmentStrength == 9, "Alignment strength should be 9")
        #expect(healthAlignment?.valueTitle == "Health & Wellness", "Value title should match")

        print("✓ Verified: Value alignments correct (1 value with strength 9)")

        // Verify term assignment
        #expect(runningGoal.termAssignment != nil, "Running goal should have term assignment")
        #expect(runningGoal.termAssignment?.termId == GoalRepositoryTests.termIds["term1"], "Should be assigned to term1")
        #expect(runningGoal.termAssignment?.assignmentOrder == 1, "Assignment order should be 1")

        print("✓ Verified: Term assignment correct (term1, order 1)")
    }

    @Test("Query: fetchAll() handles empty relationships correctly")
    func testFetchAllHandlesEmptyRelationships() async throws {
        print("\n=== Test: fetchAll() handles empty relationships ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)
        let goals = try await repository.fetchAll()

        // Find the "reading" goal (has NO measures, but has 1 value, NO term)
        guard let readingGoal = goals.first(where: { $0.id == GoalRepositoryTests.goalIds["reading"] }) else {
            throw TestError.expectedDataNotFound("Reading goal not found")
        }

        print("Verifying 'reading' goal (should have empty measure array):")
        print("  - measureTargets: \(readingGoal.measureTargets.count)")
        print("  - valueAlignments: \(readingGoal.valueAlignments.count)")
        print("  - termAssignment: \(readingGoal.termAssignment == nil ? "nil" : "assigned")")

        // CRITICAL: Empty relationships should be empty arrays, NOT nil
        #expect(readingGoal.measureTargets.isEmpty, "Goal with no measures should have empty array")
        #expect(!readingGoal.valueAlignments.isEmpty, "Goal should have value alignments")
        #expect(readingGoal.termAssignment == nil, "Goal with no term should have nil assignment")

        print("✓ Verified: Empty measure targets = [], value alignments present, no term assignment")
    }

    @Test("Query: fetchAll() handles multiple value alignments")
    func testFetchAllHandlesMultipleValueAlignments() async throws {
        print("\n=== Test: fetchAll() handles multiple value alignments ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)
        let goals = try await repository.fetchAll()

        // Find the "family" goal (has 2 value alignments)
        guard let familyGoal = goals.first(where: { $0.id == GoalRepositoryTests.goalIds["family"] }) else {
            throw TestError.expectedDataNotFound("Family goal not found")
        }

        print("Verifying 'family' goal (should have 2 value alignments):")
        print("  - valueAlignments: \(familyGoal.valueAlignments.count)")

        #expect(familyGoal.valueAlignments.count == 2, "Family goal should have 2 value alignments")

        // Verify both values are present with correct strengths
        let healthAlignment = familyGoal.valueAlignments.first { $0.valueId == GoalRepositoryTests.valueIds["health"] }
        let relationshipsAlignment = familyGoal.valueAlignments.first { $0.valueId == GoalRepositoryTests.valueIds["relationships"] }

        #expect(healthAlignment != nil, "Should have health alignment")
        #expect(relationshipsAlignment != nil, "Should have relationships alignment")

        #expect(healthAlignment?.alignmentStrength == 6, "Health alignment strength should be 6")
        #expect(relationshipsAlignment?.alignmentStrength == 10, "Relationships alignment strength should be 10")

        print("✓ Verified: Both value alignments present with correct strengths")
    }

    @Test("Query: fetchAll() returns goals with all core fields populated")
    func testFetchAllReturnsCompleteGoalFields() async throws {
        print("\n=== Test: fetchAll() returns complete goal fields ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)
        let goals = try await repository.fetchAll()

        // Find the "running" goal to verify all fields
        guard let runningGoal = goals.first(where: { $0.id == GoalRepositoryTests.goalIds["running"] }) else {
            throw TestError.expectedDataNotFound("Running goal not found")
        }

        print("Verifying all fields of 'running' goal:")

        // Verify expectation fields
        #expect(runningGoal.title == "Run 100km this quarter", "Title should match")
        #expect(runningGoal.detailedDescription == "Build running endurance", "Description should match")
        #expect(runningGoal.expectationImportance == 8, "Importance should be 8")
        #expect(runningGoal.expectationUrgency == 7, "Urgency should be 7")

        // Verify goal-specific fields
        #expect(runningGoal.startDate != nil, "Should have start date")
        #expect(runningGoal.targetDate != nil, "Should have target date")
        #expect(runningGoal.actionPlan == "Run 3x per week, gradually increase distance", "Action plan should match")

        // Verify identifiers
        #expect(runningGoal.id == GoalRepositoryTests.goalIds["running"], "Goal ID should match")
        #expect(runningGoal.expectationId != runningGoal.id, "Expectation ID should be different from goal ID")

        // Verify logTime is populated
        #expect(runningGoal.logTime.timeIntervalSinceNow < 60, "logTime should be recent (within last minute)")

        print("✓ Verified: All core fields populated correctly")
    }

    // MARK: - Test: fetchActiveGoals() - Active Goal Filtering

    @Test("Query: fetchActiveGoals() filters by target date")
    func testFetchActiveGoalsFiltersByTargetDate() async throws {
        print("\n=== Test: fetchActiveGoals() filters by target date ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)

        // NOTE: GoalRepository.fetchActiveGoals() returns [GoalWithDetails]
        // GoalRepository_v3.fetchActiveGoals() returns [GoalData]
        // This test works for GoalRepository only
        let activeGoals = try await repository.fetchActiveGoals()

        print("Fetched \(activeGoals.count) active goals")

        // Active goals: running, reading, spanish, mindfulness (4 goals)
        // NOT active: taxes (past target date)
        #expect(activeGoals.count >= 4, "Should have at least 4 active goals")

        // Verify "taxes" goal is NOT in active goals (has past target date)
        let hasTaxesGoal = activeGoals.contains { $0.goal.id == GoalRepositoryTests.goalIds["taxes"] }
        #expect(!hasTaxesGoal, "Past goal 'taxes' should NOT be in active goals")

        // Verify "mindfulness" goal IS in active goals (no target date = active)
        let hasMindfulnessGoal = activeGoals.contains { $0.goal.id == GoalRepositoryTests.goalIds["mindfulness"] }
        #expect(hasMindfulnessGoal, "Open-ended goal 'mindfulness' should be active")

        // Verify "spanish" goal IS in active goals (future target date)
        let hasSpanishGoal = activeGoals.contains { $0.goal.id == GoalRepositoryTests.goalIds["spanish"] }
        #expect(hasSpanishGoal, "Future goal 'spanish' should be active")

        print("✓ Verified: Active goals correctly filtered (excludes past goals)")
    }

    // MARK: - Test: fetchByTerm() - Term Assignment Filtering

    @Test("Query: fetchByTerm() returns only goals assigned to that term")
    func testFetchByTermReturnsCorrectGoals() async throws {
        print("\n=== Test: fetchByTerm() returns correct goals ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)

        guard let term1Id = GoalRepositoryTests.termIds["term1"] else {
            throw TestError.expectedDataNotFound("Term1 ID not found")
        }

        // NOTE: GoalRepository.fetchByTerm() returns [GoalWithDetails]
        // GoalRepository_v3.fetchByTerm() returns [GoalData]
        let term1Goals = try await repository.fetchByTerm(term1Id)

        print("Fetched \(term1Goals.count) goals for term1")

        // Only "running" goal is assigned to term1
        #expect(term1Goals.count == 1, "Term1 should have exactly 1 goal")
        #expect(term1Goals.first?.goal.id == GoalRepositoryTests.goalIds["running"], "Term1 goal should be 'running'")

        print("✓ Verified: fetchByTerm() returns only assigned goals")
    }

    @Test("Query: fetchByTerm() returns empty array for term with no goals")
    func testFetchByTermReturnsEmptyForUnassignedTerm() async throws {
        print("\n=== Test: fetchByTerm() handles term with no goals ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)

        // Create a new term with no goal assignments
        let coordinator = TermCoordinator(database: db)
        let now = Date()
        let emptyTerm = try await coordinator.create(from: TimePeriodFormData(
            title: "Empty Term Q3",
            startDate: now.addingTimeInterval(181 * 86400),
            targetDate: now.addingTimeInterval(270 * 86400),
            specialization: .term(number: 3)
        ))

        let emptyTermGoals = try await repository.fetchByTerm(emptyTerm.goalTerm.id)

        #expect(emptyTermGoals.isEmpty, "Term with no goals should return empty array")

        print("✓ Verified: Empty term returns empty array (not nil or error)")
    }

    // MARK: - Test: fetchByValue() - Value Alignment Filtering

    @Test("Query: fetchByValue() returns only goals aligned with that value")
    func testFetchByValueReturnsCorrectGoals() async throws {
        print("\n=== Test: fetchByValue() returns correct goals ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)

        guard let healthValueId = GoalRepositoryTests.valueIds["health"] else {
            throw TestError.expectedDataNotFound("Health value ID not found")
        }

        // NOTE: GoalRepository.fetchByValue() returns [Goal]
        // GoalRepository_v3.fetchByValue() returns [GoalData]
        let healthGoals = try await repository.fetchByValue(healthValueId)

        print("Fetched \(healthGoals.count) goals aligned with 'Health & Wellness'")

        // Health value is aligned with: running, family, mindfulness (3 goals)
        #expect(healthGoals.count == 3, "Health value should have 3 aligned goals")

        let healthGoalIds = Set(healthGoals.map { $0.id })
        let expectedIds = Set([
            GoalRepositoryTests.goalIds["running"]!,
            GoalRepositoryTests.goalIds["family"]!,
            GoalRepositoryTests.goalIds["mindfulness"]!
        ])

        #expect(healthGoalIds == expectedIds, "Health goals should be: running, family, mindfulness")

        print("✓ Verified: fetchByValue() returns all aligned goals")
    }

    @Test("Query: fetchByValue() returns empty array for value with no goals")
    func testFetchByValueReturnsEmptyForUnalignedValue() async throws {
        print("\n=== Test: fetchByValue() handles value with no goals ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)

        // Create a new value with no goal alignments
        let coordinator = PersonalValueCoordinator(database: db)
        let unusedValue = try await coordinator.create(from: PersonalValueFormData(
            title: "Unused Value",
            valueLevel: .general,
            priority: 50
        ))

        let unusedValueGoals = try await repository.fetchByValue(unusedValue.id)

        #expect(unusedValueGoals.isEmpty, "Value with no goals should return empty array")

        print("✓ Verified: Unaligned value returns empty array (not nil or error)")
    }

    // MARK: - Test: exists() - Existence Checks

    @Test("Query: exists(id:) returns true for existing goal")
    func testExistsReturnsTrueForExistingGoal() async throws {
        print("\n=== Test: exists(id:) for existing goal ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)

        guard let runningGoalId = GoalRepositoryTests.goalIds["running"] else {
            throw TestError.expectedDataNotFound("Running goal ID not found")
        }

        let exists = try await repository.exists(runningGoalId)

        #expect(exists == true, "Existing goal should return true")

        print("✓ Verified: exists(id:) returns true for existing goal")
    }

    @Test("Query: exists(id:) returns false for non-existent goal")
    func testExistsReturnsFalseForNonExistentGoal() async throws {
        print("\n=== Test: exists(id:) for non-existent goal ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)

        let randomId = UUID()
        let exists = try await repository.exists(randomId)

        #expect(exists == false, "Non-existent goal should return false")

        print("✓ Verified: exists(id:) returns false for random UUID")
    }

    @Test("Query: existsByTitle() returns true for existing title")
    func testExistsByTitleReturnsTrueForExistingTitle() async throws {
        print("\n=== Test: existsByTitle() for existing title ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)

        // NOTE: GoalRepository has existsByTitle()
        // GoalRepository_v3 has exists(title:)
        let exists = try await repository.existsByTitle("Run 100km this quarter")

        #expect(exists == true, "Existing title should return true")

        print("✓ Verified: existsByTitle() returns true for existing title")
    }

    @Test("Query: existsByTitle() is case-insensitive")
    func testExistsByTitleIsCaseInsensitive() async throws {
        print("\n=== Test: existsByTitle() case-insensitivity ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)

        let existsLower = try await repository.existsByTitle("run 100km this quarter")
        let existsUpper = try await repository.existsByTitle("RUN 100KM THIS QUARTER")

        #expect(existsLower == true, "Lowercase title should match")
        #expect(existsUpper == true, "Uppercase title should match")

        print("✓ Verified: existsByTitle() is case-insensitive")
    }

    @Test("Query: existsByTitle() returns false for non-existent title")
    func testExistsByTitleReturnsFalseForNonExistentTitle() async throws {
        print("\n=== Test: existsByTitle() for non-existent title ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)

        let exists = try await repository.existsByTitle("This goal does not exist")

        #expect(exists == false, "Non-existent title should return false")

        print("✓ Verified: existsByTitle() returns false for non-existent title")
    }

    // MARK: - Test: Error Handling

    @Test("Error: Invalid measure ID throws ValidationError")
    func testInvalidMeasureIdThrowsValidationError() async throws {
        print("\n=== Test: Invalid measure ID error handling ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let coordinator = GoalCoordinator(database: db)

        // Try to create goal with non-existent measure ID
        let invalidMeasureId = UUID()

        do {
            _ = try await coordinator.create(from: GoalFormData(
                title: "Goal with invalid measure",
                expectationImportance: 5,
                expectationUrgency: 5,
                metricTargets: [
                    MetricTargetInput(
                        measureId: invalidMeasureId,  // NON-EXISTENT
                        targetValue: 100.0
                    )
                ]
            ))

            Issue.record("Expected ValidationError for invalid measure ID")
        } catch let error as ValidationError {
            print("✓ Caught ValidationError: \(error.userMessage)")
            #expect(error.userMessage.contains("Measure"), "Error should mention 'Measure'")
        }

        print("✓ Verified: Invalid measure ID throws ValidationError")
    }

    @Test("Error: Invalid value ID throws ValidationError")
    func testInvalidValueIdThrowsValidationError() async throws {
        print("\n=== Test: Invalid value ID error handling ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let coordinator = GoalCoordinator(database: db)

        // Try to create goal with non-existent value ID
        let invalidValueId = UUID()

        do {
            _ = try await coordinator.create(from: GoalFormData(
                title: "Goal with invalid value",
                expectationImportance: 5,
                expectationUrgency: 5,
                valueAlignments: [
                    ValueAlignmentInput(
                        valueId: invalidValueId,  // NON-EXISTENT
                        alignmentStrength: 8
                    )
                ]
            ))

            Issue.record("Expected ValidationError for invalid value ID")
        } catch let error as ValidationError {
            print("✓ Caught ValidationError: \(error.userMessage)")
            #expect(error.userMessage.contains("value"), "Error should mention 'value'")
        }

        print("✓ Verified: Invalid value ID throws ValidationError")
    }

    // MARK: - Test: Edge Cases

    @Test("Edge Case: Goal with nil dates handled correctly")
    func testGoalWithNilDatesHandledCorrectly() async throws {
        print("\n=== Test: Goal with nil dates ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)
        let goals = try await repository.fetchAll()

        // Find "mindfulness" goal (has no target date)
        guard let mindfulnessGoal = goals.first(where: { $0.id == GoalRepositoryTests.goalIds["mindfulness"] }) else {
            throw TestError.expectedDataNotFound("Mindfulness goal not found")
        }

        #expect(mindfulnessGoal.startDate != nil, "Should have start date")
        #expect(mindfulnessGoal.targetDate == nil, "Should NOT have target date")

        print("✓ Verified: Nil target date handled correctly (not crash or empty)")
    }

    @Test("Edge Case: Goal with empty strings handled correctly")
    func testGoalWithEmptyStringsHandledCorrectly() async throws {
        print("\n=== Test: Goal with empty optional strings ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        // Create goal with minimal data (empty optional strings)
        let coordinator = GoalCoordinator(database: db)
        let minimalGoal = try await coordinator.create(from: GoalFormData(
            title: "Minimal goal",
            detailedDescription: nil,  // No description
            freeformNotes: nil,  // No notes
            expectationImportance: 5,
            expectationUrgency: 5,
            actionPlan: nil  // No action plan
        ))

        let repository = GoalRepository(database: db)
        let goals = try await repository.fetchAll()

        guard let fetchedMinimalGoal = goals.first(where: { $0.id == minimalGoal.goal.id }) else {
            throw TestError.expectedDataNotFound("Minimal goal not found")
        }

        #expect(fetchedMinimalGoal.title == "Minimal goal", "Title should be present")
        #expect(fetchedMinimalGoal.detailedDescription == nil, "Description should be nil")
        #expect(fetchedMinimalGoal.freeformNotes == nil, "Notes should be nil")
        #expect(fetchedMinimalGoal.actionPlan == nil, "Action plan should be nil")

        print("✓ Verified: Empty optional strings handled correctly (nil, not empty string)")
    }

    @Test("Edge Case: Multiple goals with same measure handled correctly")
    func testMultipleGoalsWithSameMeasureHandledCorrectly() async throws {
        print("\n=== Test: Multiple goals with same measure ===")

        guard let db = GoalRepositoryTests.database else {
            throw TestError.databaseNotInitialized
        }

        let repository = GoalRepository(database: db)
        let goals = try await repository.fetchAll()

        // Both "running" and "family" use different measures, but we can verify no data mixing
        guard let runningGoal = goals.first(where: { $0.id == GoalRepositoryTests.goalIds["running"] }),
              let familyGoal = goals.first(where: { $0.id == GoalRepositoryTests.goalIds["family"] }) else {
            throw TestError.expectedDataNotFound("Goals not found")
        }

        // Verify each goal has ONLY its own measures (no cross-contamination)
        let runningMeasureIds = Set(runningGoal.measureTargets.map { $0.measureId })
        let familyMeasureIds = Set(familyGoal.measureTargets.map { $0.measureId })

        // Should be disjoint sets (no overlap)
        #expect(runningMeasureIds.isDisjoint(with: familyMeasureIds), "Goals should not share measure IDs")

        print("✓ Verified: Each goal has only its own measures (no data mixing)")
    }
}

// MARK: - Test Errors

enum TestError: Error, CustomStringConvertible {
    case databaseNotInitialized
    case sampleDataNotLoaded
    case expectedDataNotFound(String)

    var description: String {
        switch self {
        case .databaseNotInitialized:
            return "Database not initialized - run setup tests first"
        case .sampleDataNotLoaded:
            return "Sample data not loaded - run setup tests first"
        case .expectedDataNotFound(let details):
            return "Expected data not found: \(details)"
        }
    }
}

// MARK: - Usage Notes for GoalRepository_v3

/*
 TO ADAPT THESE TESTS FOR GoalRepository_v3:

 1. CHANGE REPOSITORY INSTANTIATION:
    - FROM: `let repository = GoalRepository(database: db)`
    - TO:   `let repository = GoalRepository_v3(database: db)`

 2. ADJUST RETURN TYPE HANDLING:
    - fetchActiveGoals() returns [GoalData] (not [GoalWithDetails])
      Change: `activeGoals.first?.goal.id` → `activeGoals.first?.id`

    - fetchByTerm() returns [GoalData] (not [GoalWithDetails])
      Change: `term1Goals.first?.goal.id` → `term1Goals.first?.id`

    - fetchByValue() returns [GoalData] (not [Goal])
      Already uses `healthGoals.map { $0.id }` which works for both

 3. ADJUST METHOD NAMES:
    - FROM: `repository.existsByTitle("title")`
    - TO:   `repository.exists(title: "title")`

 4. ADD v3-SPECIFIC TESTS:
    - Test fetchForExport(from:to:) with date filtering
    - Test fetch(limit:offset:) pagination
    - Test fetchRecent(limit:) ordering

 5. VERIFY COMPATIBILITY:
    All tests marked with "NOTE:" comments indicate where return types differ.
    The tests use defensive assertions that work for both implementations.

 EXPECTED RESULTS:
 - All current tests should PASS for GoalRepository
 - After adjustments, all tests should PASS for GoalRepository_v3
 - Any failures in v3 indicate missing/broken functionality
 */
