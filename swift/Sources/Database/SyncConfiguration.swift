// SyncConfiguration.swift
// Centralized CloudKit sync table registration

import Foundation
import GRDB
import Models
import SQLiteData

/// Configuration for CloudKit sync
public enum SyncConfiguration {

    /// Create a SyncEngine with all configured tables
    ///
    /// NOTE: SyncEngine uses parameter packs (variadic generics), not arrays,
    /// so tables must be listed explicitly. This is the only place they're listed.
    /// - Parameter db: The database to sync
    /// - Returns: Configured SyncEngine ready for CloudKit sync
    public static func createSyncEngine(for db: DatabaseQueue) throws -> SyncEngine {
        return try SyncEngine(
            for: db,
            tables:
                // =================================================================
                // ABSTRACTION LAYER (5 tables)
                // =================================================================
                Action.self,  // CREATE TABLE actions (schema_current.sql:9)
            Expectation.self,  // CREATE TABLE expectations (schema_current.sql:19)
            Measure.self,  // CREATE TABLE measures (schema_current.sql:30)
            PersonalValue.self,  // CREATE TABLE personalValues (schema_current.sql:42)
            TimePeriod.self,  // CREATE TABLE timePeriods (schema_current.sql:56)
            // =================================================================
            // BASIC LAYER (5 tables)
            // =================================================================
            Goal.self,  // CREATE TABLE goals (schema_current.sql:71)
            Milestone.self,  // CREATE TABLE milestones (schema_current.sql:83)
            Obligation.self,  // CREATE TABLE obligations (schema_current.sql:91)
            GoalTerm.self,  // CREATE TABLE goalTerms (schema_current.sql:101)
            ExpectationMeasure.self,  // CREATE TABLE expectationMeasures (schema_current.sql:112)
            // =================================================================
            // COMPOSIT LAYER (4 tables)
            // =================================================================
            MeasuredAction.self,  // CREATE TABLE measuredActions (schema_current.sql:130)
            GoalRelevance.self,  // CREATE TABLE goalRelevances (schema_current.sql:145)
            ActionGoalContribution.self,  // CREATE TABLE actionGoalContributions (schema_current.sql:159)
            TermGoalAssignment.self,  // CREATE TABLE termGoalAssignments (schema_current.sql:174)
            // =================================================================
            // SEMANTIC/ML INFRASTRUCTURE (1 table)
            // =================================================================
            EmbeddingCacheEntry.self  // CREATE TABLE semanticEmbeddings (schema_current.sql:~280)
                // =================================================================
                // EXCLUDED FROM SYNC (3 tables)
                // =================================================================
                // - appledata: Device-local staging for HealthKit/EventKit, purged after parsing
                // - llmConversations: Not yet implemented (models don't exist)
                // - llmMessages: Not yet implemented (models don't exist)
        )
    }
}
