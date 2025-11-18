//
// GoalCoordinator.swift
// Written by Claude Code on 2025-11-03
//
// PURPOSE: Coordinates creation of Goal entities with full relationship graph
// ARCHITECTURE: Most complex coordinator - 5+ models atomically
// MODELS: Expectation + Goal + ExpectationMeasure[] + GoalRelevance[] + TermGoalAssignment?
//

import Dependencies
import Foundation
import Models
import SQLiteData

/// Coordinates creation of Goal entities with atomic persistence.
///
/// ARCHITECTURE DECISION: Five-model atomic transaction
/// - Creates Expectation (base) + Goal (subtype) atomically
/// - Creates ExpectationMeasure[] records for each metric target
/// - Creates GoalRelevance[] records for each value alignment
/// - Optionally creates TermGoalAssignment if term specified
///
/// Validation Strategy (Two-Phase):
/// - Phase 1: Validate form data (business rules) BEFORE assembly
/// - Phase 2: Validate complete entity (referential integrity) AFTER assembly
/// - FK existence checked: Measures, Values, Terms must exist
/// - Database enforces: NOT NULL, foreign keys, CHECK constraints
///
/// PATTERN: Multi-model coordinator (most complex in app)
/// Simpler than: None (this is the most complex)
/// More complex than: ActionCoordinator (3 models), TimePeriodCoordinator (2 models)
public final class GoalCoordinator: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Semantic Services (Lazy access for Sendable conformance)

    /// Semantic service for duplicate detection (lazy to maintain Sendable)
    private var semanticService: SemanticService {
        @Dependency(\.semanticService) var service
        return service
    }

    // Note: EmbeddingCache dependency removed - caching now integrated in SemanticService

    /// Creates Goal with full relationship graph from form data.
    /// - Parameter formData: Validated form data with targets and alignments
    /// - Returns: Persisted Goal with generated ID
    /// - Throws: Database errors if constraints violated or referenced entities don't exist
    ///
    /// IMPLEMENTATION:
    /// 1. Validate measureIds exist in Measures table
    /// 2. Validate valueIds exist in PersonalValue table
    /// 3. Validate termId exists in GoalTerm table (if provided)
    /// 4. Insert Expectation (base entity, .goal type)
    /// 5. Insert Goal (subtype, FK to Expectation)
    /// 6. Insert ExpectationMeasure[] for each valid metric target
    /// 7. Insert GoalRelevance[] for each valid value alignment
    /// 8. Insert TermGoalAssignment if termId provided
    /// 9. Return Goal (caller accesses relationships via GoalsQuery)
    public func create(from formData: GoalFormData) async throws -> Goal {
        // Phase 1: Validate form data (business rules)
        // Throws: ValidationError.invalidExpectation, ValidationError.invalidDateRange, etc.
        try GoalValidation.validateFormData(formData)

        // Phase 1.5: Check for semantic duplicates (if title provided and semantic service available)
        if !formData.title.isEmpty && semanticService.isAvailable {
            try await checkForDuplicates(title: formData.title)
        }

        // COORDINATOR COMPOSITION: Get-or-create measures BEFORE transaction
        // This ensures all measures exist before we start the atomic write
        let measureCoordinator = MeasureCoordinator(database: database)

        // Build resolved targets array (Swift 6: use compactMap for immutable result)
        let resolvedTargets: [(measureId: UUID, value: Double, notes: String?)] = try await {
            var targets: [(measureId: UUID, value: Double, notes: String?)] = []

            for target in formData.measureTargets where target.isValid {
                let measureId: UUID

                if let existingId = target.measureId {
                    // Pattern 1: Use existing measure (measureId provided)
                    measureId = existingId
                } else if let unit = target.unit, let measureType = target.measureType {
                    // Pattern 2: Get-or-create measure (unit + measureType provided)
                    // This is idempotent - returns existing measure if duplicate found
                    let measure = try await measureCoordinator.getOrCreate(
                        unit: unit,
                        measureType: measureType,
                        title: target.measureTitle
                    )
                    measureId = measure.id
                } else {
                    // Invalid target (should be caught by isValid, but defensive)
                    continue
                }

                targets.append(
                    (
                        measureId: measureId,
                        value: target.targetValue,
                        notes: target.notes
                    ))
            }

            return targets
        }()

        let createdGoal = try await database.write { db in
            // Validate resolved measureIds still exist (defensive - measures created above)
            for target in resolvedTargets {
                let measureExists = try Measure.find(target.measureId).fetchOne(db) != nil
                guard measureExists else {
                    throw ValidationError.invalidMeasure("Measure \(target.measureId) not found")
                }
            }

            // Validate valueIds exist (if any alignments provided)
            for alignment in formData.valueAlignments where alignment.valueId != nil {
                let valueExists = try PersonalValue.find(alignment.valueId!).fetchOne(db) != nil
                guard valueExists else {
                    throw ValidationError.foreignKeyViolation(
                        "PersonalValue \(alignment.valueId!) not found")
                }
            }

            // Validate termId exists (if provided)
            if let termId = formData.termId {
                let termExists = try GoalTerm.find(termId).fetchOne(db) != nil
                guard termExists else {
                    throw ValidationError.foreignKeyViolation("Term \(termId) not found")
                }
            }

            // 4. Insert Expectation (base entity with .goal type)
            let expectation = try Expectation.insert {
                Expectation.Draft(
                    id: UUID(),
                    logTime: Date(),
                    title: formData.title.isEmpty ? nil : formData.title,
                    detailedDescription: formData.detailedDescription.isEmpty
                        ? nil : formData.detailedDescription,
                    freeformNotes: formData.freeformNotes.isEmpty ? nil : formData.freeformNotes,
                    expectationType: .goal,
                    expectationImportance: formData.expectationImportance,
                    expectationUrgency: formData.expectationUrgency
                )
            }
            .returning { $0 }
            .fetchOne(db)!  // Safe: successful insert always returns value

            // 5. Insert Goal (subtype with FK to Expectation)
            let goal = try Goal.insert {
                Goal.Draft(
                    id: UUID(),
                    expectationId: expectation.id,
                    startDate: formData.startDate,
                    targetDate: formData.targetDate,
                    actionPlan: formData.actionPlan?.isEmpty == true ? nil : formData.actionPlan,
                    expectedTermLength: formData.expectedTermLength
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // 6. Insert ExpectationMeasure records for each resolved metric target
            // Uses resolvedTargets (measures guaranteed to exist from coordinator composition)
            for target in resolvedTargets {
                try ExpectationMeasure.insert {
                    ExpectationMeasure.Draft(
                        id: UUID(),
                        freeformNotes: target.notes?.isEmpty == true ? nil : target.notes,
                        expectationId: expectation.id,
                        measureId: target.measureId,  // From resolved targets (guaranteed to exist)
                        targetValue: target.value,
                        createdAt: Date()
                    )
                }
                .execute(db)
            }

            // 7. Insert GoalRelevance records for each valid value alignment
            for alignment in formData.valueAlignments where alignment.isValid {
                try GoalRelevance.insert {
                    GoalRelevance.Draft(
                        id: UUID(),
                        goalId: goal.id,
                        valueId: alignment.valueId!,  // Already validated above
                        alignmentStrength: alignment.alignmentStrength,
                        relevanceNotes: alignment.relevanceNotes?.isEmpty == true
                            ? nil : alignment.relevanceNotes,
                        createdAt: Date()
                    )
                }
                .execute(db)
            }

            // 8. Insert TermGoalAssignment if termId provided
            if let termId = formData.termId {
                try TermGoalAssignment.insert {
                    TermGoalAssignment.Draft(
                        id: UUID(),
                        termId: termId,
                        goalId: goal.id,
                        assignmentOrder: nil,  // Can be set later via term management
                        createdAt: Date()
                    )
                }
                .execute(db)
            }

            // Phase 2: Validate complete entity graph (referential integrity)
            // Build the arrays for validation using resolved targets
            let measurements = resolvedTargets.map { target -> ExpectationMeasure in
                ExpectationMeasure(
                    expectationId: expectation.id,
                    measureId: target.measureId,  // From resolved targets
                    targetValue: target.value,
                    createdAt: Date(),
                    freeformNotes: target.notes,
                    id: UUID()
                )
            }

            let relevances = formData.valueAlignments.compactMap { alignment -> GoalRelevance? in
                guard let valueId = alignment.valueId, alignment.isValid else { return nil }
                return GoalRelevance(
                    goalId: goal.id,
                    valueId: valueId,
                    alignmentStrength: alignment.alignmentStrength,
                    relevanceNotes: alignment.relevanceNotes,
                    createdAt: Date(),
                    id: UUID()
                )
            }

            try GoalValidation.validateComplete(expectation, goal, measurements, relevances)

            // 9. Return Goal (caller accesses full data via GoalsQuery)
            return goal
        }

        // 10. Generate embeddings asynchronously (fire-and-forget, don't block return)
        // Fire task AFTER database.write completes to avoid blocking goal creation
        let goalId = createdGoal.id
        Task.detached(priority: .background) { [database = self.database] in
            // Fetch full GoalData and generate both embedding variants
            let repository = GoalRepository(database: database)
            guard let goalData = try? await repository.fetchAll().first(where: { $0.id == goalId }) else {
                print("⚠️ Failed to fetch GoalData for embedding generation (goal: \(goalId))")
                return
            }

            let embeddingService = EmbeddingGenerationService(database: database)

            // Generate title-only embedding (for duplicate detection)
            do {
                _ = try await embeddingService.generateGoalEmbedding(goal: goalData, variant: .titleOnly)
                print("✅ Generated title-only embedding for goal: \(goalData.title ?? "Untitled")")
            } catch {
                print("⚠️ Failed to generate title-only embedding for goal '\(goalData.title ?? "Untitled")': \(error)")
            }

            // Generate full-context embedding (for semantic search & LLM RAG)
            do {
                _ = try await embeddingService.generateGoalEmbedding(goal: goalData, variant: .fullContext)
                print("✅ Generated full-context embedding for goal: \(goalData.title ?? "Untitled")")
            } catch {
                print("⚠️ Failed to generate full-context embedding for goal '\(goalData.title ?? "Untitled")': \(error)")
            }
        }

        return createdGoal
    }

    /// Updates existing Goal with new form data.
    /// - Parameters:
    ///   - goal: Existing Goal to update
    ///   - expectation: Existing Expectation to update
    ///   - existingTargets: Current ExpectationMeasures to replace
    ///   - existingAlignments: Current GoalRelevances to replace
    ///   - existingAssignment: Current TermGoalAssignment to replace (if any)
    ///   - formData: New form data
    /// - Returns: Updated Goal
    /// - Throws: Database errors if constraints violated
    ///
    /// IMPLEMENTATION:
    /// 1. Update Expectation (preserve id and logTime)
    /// 2. Update Goal (preserve id)
    /// 3. Delete old ExpectationMeasures
    /// 4. Insert new ExpectationMeasures from formData
    /// 5. Delete old GoalRelevances
    /// 6. Insert new GoalRelevances from formData
    /// 7. Delete old TermGoalAssignment (if any)
    /// 8. Insert new TermGoalAssignment (if termId provided)
    /// 9. Return updated Goal
    ///
    /// NOTE: Replace strategy (delete + insert) rather than diff strategy for simplicity
    public func update(
        goal: Goal,
        expectation: Expectation,
        existingTargets: [ExpectationMeasure],
        existingAlignments: [GoalRelevance],
        existingAssignment: TermGoalAssignment?,
        from formData: GoalFormData
    ) async throws -> Goal {
        // Phase 1: Validate form data (business rules)
        try GoalValidation.validateFormData(formData)

        return try await database.write { db in
            // Validate new measureIds exist (if any)
            for target in formData.measureTargets where target.measureId != nil {
                let measureExists = try Measure.find(target.measureId!).fetchOne(db) != nil
                guard measureExists else {
                    throw ValidationError.invalidMeasure("Measure \(target.measureId!) not found")
                }
            }

            // Validate new valueIds exist (if any)
            for alignment in formData.valueAlignments where alignment.valueId != nil {
                let valueExists = try PersonalValue.find(alignment.valueId!).fetchOne(db) != nil
                guard valueExists else {
                    throw ValidationError.foreignKeyViolation(
                        "PersonalValue \(alignment.valueId!) not found")
                }
            }

            // Validate new termId exists (if provided)
            if let termId = formData.termId {
                let termExists = try GoalTerm.find(termId).fetchOne(db) != nil
                guard termExists else {
                    throw ValidationError.foreignKeyViolation("Term \(termId) not found")
                }
            }

            // 1. Update Expectation (preserve id and logTime)
            let updatedExpectation = try Expectation.upsert {
                Expectation.Draft(
                    id: expectation.id,  // Preserve ID
                    logTime: expectation.logTime,  // Preserve original logTime
                    title: formData.title.isEmpty ? nil : formData.title,
                    detailedDescription: formData.detailedDescription.isEmpty
                        ? nil : formData.detailedDescription,
                    freeformNotes: formData.freeformNotes.isEmpty ? nil : formData.freeformNotes,
                    expectationType: .goal,
                    expectationImportance: formData.expectationImportance,
                    expectationUrgency: formData.expectationUrgency
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // 2. Update Goal (preserve id)
            let updatedGoal = try Goal.upsert {
                Goal.Draft(
                    id: goal.id,  // Preserve ID
                    expectationId: updatedExpectation.id,
                    startDate: formData.startDate,
                    targetDate: formData.targetDate,
                    actionPlan: formData.actionPlan?.isEmpty == true ? nil : formData.actionPlan,
                    expectedTermLength: formData.expectedTermLength
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // 3. Delete old ExpectationMeasures
            for target in existingTargets {
                try ExpectationMeasure.delete(target).execute(db)
            }

            // 4. Insert new ExpectationMeasures from formData
            for target in formData.measureTargets where target.isValid {
                try ExpectationMeasure.insert {
                    ExpectationMeasure.Draft(
                        id: UUID(),  // New ID for new record
                        freeformNotes: target.notes?.isEmpty == true ? nil : target.notes,
                        expectationId: updatedExpectation.id,
                        measureId: target.measureId!,
                        targetValue: target.targetValue,
                        createdAt: Date()
                    )
                }
                .execute(db)
            }

            // 5. Delete old GoalRelevances
            for alignment in existingAlignments {
                try GoalRelevance.delete(alignment).execute(db)
            }

            // 6. Insert new GoalRelevances from formData
            for alignment in formData.valueAlignments where alignment.isValid {
                try GoalRelevance.insert {
                    GoalRelevance.Draft(
                        id: UUID(),  // New ID for new record
                        goalId: updatedGoal.id,
                        valueId: alignment.valueId!,
                        alignmentStrength: alignment.alignmentStrength,
                        relevanceNotes: alignment.relevanceNotes?.isEmpty == true
                            ? nil : alignment.relevanceNotes,
                        createdAt: Date()
                    )
                }
                .execute(db)
            }

            // 7. Delete old TermGoalAssignment (if any)
            if let existingAssignment = existingAssignment {
                try TermGoalAssignment.delete(existingAssignment).execute(db)
            }

            // 8. Insert new TermGoalAssignment (if termId provided)
            if let termId = formData.termId {
                try TermGoalAssignment.insert {
                    TermGoalAssignment.Draft(
                        id: UUID(),  // New ID for new record
                        termId: termId,
                        goalId: updatedGoal.id,
                        assignmentOrder: nil,
                        createdAt: Date()
                    )
                }
                .execute(db)
            }

            // Phase 2: Validate complete entity graph
            let newMeasurements = formData.measureTargets.compactMap {
                target -> ExpectationMeasure? in
                guard let measureId = target.measureId, target.isValid else { return nil }
                return ExpectationMeasure(
                    expectationId: updatedExpectation.id,
                    measureId: measureId,
                    targetValue: target.targetValue,
                    createdAt: Date(),
                    freeformNotes: target.notes,
                    id: UUID()
                )
            }

            let newRelevances = formData.valueAlignments.compactMap { alignment -> GoalRelevance? in
                guard let valueId = alignment.valueId, alignment.isValid else { return nil }
                return GoalRelevance(
                    goalId: updatedGoal.id,
                    valueId: valueId,
                    alignmentStrength: alignment.alignmentStrength,
                    relevanceNotes: alignment.relevanceNotes,
                    createdAt: Date(),
                    id: UUID()
                )
            }

            try GoalValidation.validateComplete(
                updatedExpectation, updatedGoal, newMeasurements, newRelevances)

            return updatedGoal
        }
    }

    /// Deletes Goal and all its relationships.
    /// - Parameters:
    ///   - goal: Goal to delete
    ///   - expectation: Associated Expectation to delete
    ///   - targets: Associated ExpectationMeasures to delete
    ///   - alignments: Associated GoalRelevances to delete
    ///   - assignment: Associated TermGoalAssignment to delete (if any)
    /// - Throws: Database errors if constraints violated
    ///
    /// IMPLEMENTATION:
    /// 1. Delete ExpectationMeasures first (FK dependency)
    /// 2. Delete GoalRelevances (FK dependency)
    /// 3. Delete TermGoalAssignment (FK dependency)
    /// 4. Delete Goal (FK to Expectation)
    /// 5. Delete Expectation last
    ///
    /// Delete goal and all its relationships using canonical GoalData
    ///
    /// Deletes in correct order respecting foreign key constraints:
    /// 1. ExpectationMeasures (FK → Expectation)
    /// 2. GoalRelevances (FK → Goal)
    /// 3. TermGoalAssignment (FK → Goal)
    /// 4. Goal (FK → Expectation)
    /// 5. Expectation
    ///
    /// - Parameter goalData: Canonical goal with all relationships
    /// - Throws: DatabaseError if deletion fails
    public func delete(_ goalData: GoalData) async throws {
        try await database.write { db in
            // 1. Delete ExpectationMeasures by ID
            for target in goalData.measureTargets {
                try db.execute(
                    sql: "DELETE FROM expectationMeasures WHERE id = ?",
                    arguments: [target.id.uuidString.lowercased()]
                )
            }

            // 2. Delete GoalRelevances by ID
            for alignment in goalData.valueAlignments {
                try db.execute(
                    sql: "DELETE FROM goalRelevances WHERE id = ?",
                    arguments: [alignment.id.uuidString.lowercased()]
                )
            }

            // 3. Delete TermGoalAssignment if exists
            if let assignment = goalData.termAssignment {
                try db.execute(
                    sql: "DELETE FROM termGoalAssignments WHERE id = ?",
                    arguments: [assignment.id.uuidString.lowercased()]
                )
            }

            // 4. Delete Goal by ID
            try db.execute(
                sql: "DELETE FROM goals WHERE id = ?",
                arguments: [goalData.id.uuidString.lowercased()]
            )

            // 5. Delete Expectation by ID
            try db.execute(
                sql: "DELETE FROM expectations WHERE id = ?",
                arguments: [goalData.expectationId.uuidString]
            )
        }
    }

    // MARK: - Duplicate Detection (v0.7.5)

    /// Check for semantic duplicates before creating goal
    /// - Parameter title: Goal title to check
    /// - Throws: ValidationError.duplicateGoal if blocking duplicate found
    private func checkForDuplicates(title: String) async throws {
        // Fetch existing goals (canonical GoalData from repository)
        let repository = GoalRepository(database: database)
        let existingGoals = try await repository.fetchAll()

        // No existing goals - no duplicates possible
        guard !existingGoals.isEmpty else {
            return
        }

        // Create detector and check for blocking duplicates
        let detector = SemanticGoalDetector(
            semanticService: semanticService,
            config: .goals  // Uses default 0.75 threshold with blocking on high severity
        )

        // Check for blocking duplicate (high or exact similarity)
        if let blockingDuplicate = try await detector.checkForBlockingDuplicate(
            title: title,
            in: existingGoals
        ) {
            // Throw user-friendly validation error
            throw ValidationError.duplicateGoal(
                title: title,
                similarTo: blockingDuplicate.title,
                similarity: blockingDuplicate.similarity
            )
        }

        // No blocking duplicates - proceed with creation
    }
}
