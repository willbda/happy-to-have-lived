import Foundation
import GRDB  // ARCHITECTURE NOTE: Required for low-level database initialization
import Models
import SQLiteData

// SyncConfiguration is in the same module (Database), no import needed

// ARCHITECTURE DECISION: Why GRDB import here?
// CONTEXT: DatabaseBootstrap needs low-level database setup APIs
// GRDB APIs REQUIRED (not exposed by SQLiteData):
//   - DatabaseQueue(path:) - Constructor to create database file
//   - barrierWriteWithoutTransaction - WAL mode setup outside transaction
//   - Database.tableExists() - Schema initialization check
//   - Database.execute(sql:) - Raw SQL execution for schema
// ALTERNATIVE: Could use DatabaseMigrator (see SQLiteData examples)
//   BUT: We already have schema_current.sql, so direct execute is simpler
// PATTERN: Bootstrap uses GRDB, rest of app uses SQLiteData
// SEE: sqlite-data-main/Examples/CaseStudies/SwiftUIDemo.swift:66-80 for migrator pattern

public enum DatabaseBootstrap {

    public static func configure(mode: DatabaseMode = .fromEnvironment) {
        prepareDependencies {
            do {
                let db = try createDatabase(mode: mode)
                $0.defaultDatabase = db
                $0.defaultSyncEngine = try SyncConfiguration.createSyncEngine(for: db)
            } catch {
                fatalError("Failed to configure database: \(error)")
            }
        }
    }

    /// Database configuration mode
    public enum DatabaseMode {
        case production  // Normal app database in ApplicationSupport
        case syncTesting  // Cloud-synced test database in ApplicationSupport
        case localTesting  // Local test database in project Tests directory

        /// Determine mode from environment variables (used by app at launch)
        public static var fromEnvironment: DatabaseMode {
            let env = ProcessInfo.processInfo.environment

            // Priority: USE_TEST_DB > USE_LOCAL_TEST_DB > production
            if env["USE_TEST_DB"] == "1" {
                return .syncTesting
            } else if env["USE_LOCAL_TEST_DB"] == "1" {
                return .localTesting
            } else {
                return .production
            }
        }

        var path: URL {
            let fm = FileManager.default
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

            switch self {
            case .production:
                return appSupport.appendingPathComponent("GoalTracker/application_data.db")
            case .syncTesting:
                return appSupport.appendingPathComponent("GoalTracker/synced_testing.db")
            case .localTesting:
                return fm.temporaryDirectory
                    .appendingPathComponent("GoalTracker/local_testing.db")
            }
        }
    }

    public static func createDatabase(mode: DatabaseMode = .fromEnvironment) throws
        -> DatabaseQueue
    {
        let dbPath = mode.path

        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: dbPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        print("Database: \(mode)")
        print("Path: \(dbPath.path)")

        // GRDB API: DatabaseQueue constructor
        let db = try DatabaseQueue(path: dbPath.path)

        // GRDB API: barrierWriteWithoutTransaction for WAL mode
        // ARCHITECTURE NOTE: WAL (Write-Ahead Logging) improves concurrency
        // MUST be set outside transaction, hence barrierWriteWithoutTransaction
        // SEE: https://www.sqlite.org/wal.html
        try db.barrierWriteWithoutTransaction { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }

        // Initialize schema if tables don't exist yet
        try initializeSchema(db)

        // Attach metadatabase for CloudKit sync metadata access
        // IMPORTANT: This allows querying SyncMetadata table from app database
        // See: https://swiftpackageindex.com/pointfreeco/sqlite-data/1.3.0/documentation/sqlitedata/cloudkit
        try db.write { db in
            try db.attachMetadatabase()
        }
        print("   Metadatabase: attached for SyncMetadata access")

        return db
    }

    private static func initializeSchema(_ db: DatabaseQueue) throws {
        let hasSchema = try db.read { db in
            try db.tableExists("actions")
        }

        guard !hasSchema else {
            print("Schema: already initialized")
            return
        }

        // Load schema SQL from bundle
        guard
            let schemaURL = Bundle.module.url(
                forResource: "schema_current",
                withExtension: "sql"
            )
        else {
            throw DatabaseError.schemaFileNotFound
        }

        let schemaSql = try String(contentsOf: schemaURL, encoding: .utf8)

        // GRDB API: Database.execute(sql:) for raw SQL
        // We use direct SQL execution instead of DatabaseMigrator
        // since schema_current.sql is our single source of truth
        try db.write { db in
            try db.execute(sql: schemaSql)
        }

        print("   Schema: initialized from schema_current.sql")
    }

    enum DatabaseError: Error {
        case schemaFileNotFound
    }
}
