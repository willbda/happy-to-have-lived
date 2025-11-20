-- Architecture Documentation Tracking Database Schema
-- Written by Claude Code on 2025-11-19
--
-- PURPOSE: Track Swift codebase architecture over time with change detection
-- DESIGN: Normalized schema with historical tracking and metadata

-- =============================================================================
-- FILE TRACKING
-- =============================================================================

-- Current state of all Swift files
CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL UNIQUE,

    -- File metadata (removed CHECK constraint for flexibility)
    layer TEXT NOT NULL,

    domain_entity TEXT NOT NULL, -- Goal, Action, PersonalValue, Measure, TimePeriod, Milestone, Obligation, Cross-cutting

    -- File characteristics
    file_purpose TEXT,
    key_pattern TEXT,
    dependencies TEXT,
    extends_conforms TEXT,
    concurrency TEXT CHECK(concurrency IN ('None', 'Sendable', '@MainActor', '@unchecked Sendable', 'Sendable + @MainActor')),
    complexity TEXT CHECK(complexity IN ('Simple', 'Medium', 'Complex')),
    notes TEXT,

    -- File system metadata
    file_size_bytes INTEGER,
    line_count INTEGER,
    last_modified TIMESTAMP,
    file_hash TEXT, -- SHA256 of file contents for change detection

    -- Tracking metadata
    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_scanned TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted INTEGER DEFAULT 0,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_files_layer ON files(layer);
CREATE INDEX idx_files_domain ON files(domain_entity);
CREATE INDEX idx_files_complexity ON files(complexity);
CREATE INDEX idx_files_deleted ON files(is_deleted);
CREATE INDEX idx_files_hash ON files(file_hash);

-- =============================================================================
-- CHANGE HISTORY
-- =============================================================================

-- Historical snapshots of file changes
CREATE TABLE IF NOT EXISTS file_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER NOT NULL,

    -- What changed
    change_type TEXT NOT NULL CHECK(change_type IN (
        'created', 'modified', 'deleted', 'renamed', 'metadata_changed'
    )),

    -- Previous values (JSON for flexibility)
    previous_values TEXT, -- JSON: {"layer": "old_value", "complexity": "old_value"}
    new_values TEXT,      -- JSON: {"layer": "new_value", "complexity": "new_value"}

    -- File snapshot at time of change
    file_path TEXT NOT NULL,
    file_hash TEXT,
    line_count INTEGER,

    -- Metadata
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    scan_run_id INTEGER,

    FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE CASCADE,
    FOREIGN KEY (scan_run_id) REFERENCES scan_runs(id)
);

CREATE INDEX idx_history_file ON file_history(file_id);
CREATE INDEX idx_history_type ON file_history(change_type);
CREATE INDEX idx_history_date ON file_history(changed_at);
CREATE INDEX idx_history_run ON file_history(scan_run_id);

-- =============================================================================
-- SCAN TRACKING
-- =============================================================================

-- Track each scan run with metadata
CREATE TABLE IF NOT EXISTS scan_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Scan metadata
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    duration_seconds REAL,

    -- Scan results
    files_scanned INTEGER DEFAULT 0,
    files_created INTEGER DEFAULT 0,
    files_modified INTEGER DEFAULT 0,
    files_deleted INTEGER DEFAULT 0,
    errors_encountered INTEGER DEFAULT 0,

    -- Git context
    git_branch TEXT,
    git_commit_hash TEXT,
    git_commit_message TEXT,

    -- Execution context
    python_version TEXT,
    script_version TEXT DEFAULT '1.0.0',
    user TEXT,
    hostname TEXT
);

CREATE INDEX idx_scan_runs_date ON scan_runs(started_at);
CREATE INDEX idx_scan_runs_branch ON scan_runs(git_branch);

-- =============================================================================
-- STATISTICS & ANALYTICS
-- =============================================================================

-- Aggregated statistics per scan run
CREATE TABLE IF NOT EXISTS scan_statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_run_id INTEGER NOT NULL,

    -- File distribution
    total_files INTEGER,
    files_by_layer TEXT, -- JSON: {"Model": 30, "View": 44, ...}
    files_by_domain TEXT, -- JSON: {"Goal": 16, "Action": 11, ...}
    files_by_complexity TEXT, -- JSON: {"Simple": 91, "Medium": 57, ...}
    files_by_concurrency TEXT, -- JSON: {"Sendable": 85, "@MainActor": 63, ...}

    -- Code metrics
    total_lines INTEGER,
    avg_lines_per_file REAL,
    largest_file TEXT,
    largest_file_lines INTEGER,

    -- Complexity analysis
    complex_files_count INTEGER,
    complex_files_list TEXT, -- JSON array of file paths

    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (scan_run_id) REFERENCES scan_runs(id) ON DELETE CASCADE
);

CREATE INDEX idx_stats_run ON scan_statistics(scan_run_id);

-- =============================================================================
-- ARCHITECTURAL PATTERNS
-- =============================================================================

-- Catalog of architectural patterns used in codebase
CREATE TABLE IF NOT EXISTS patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    pattern_name TEXT NOT NULL UNIQUE,
    pattern_category TEXT, -- Repository, ViewModel, Coordinator, etc.
    description TEXT,

    -- Pattern characteristics
    required_traits TEXT, -- JSON: ["Sendable", "extends BaseRepository"]
    example_file TEXT,
    documentation_url TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Track which files use which patterns
CREATE TABLE IF NOT EXISTS file_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER NOT NULL,
    pattern_id INTEGER NOT NULL,

    confidence TEXT CHECK(confidence IN ('confirmed', 'likely', 'partial')),
    notes TEXT,

    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE CASCADE,
    FOREIGN KEY (pattern_id) REFERENCES patterns(id) ON DELETE CASCADE,

    UNIQUE(file_id, pattern_id)
);

CREATE INDEX idx_file_patterns_file ON file_patterns(file_id);
CREATE INDEX idx_file_patterns_pattern ON file_patterns(pattern_id);

-- =============================================================================
-- ARCHITECTURAL VIOLATIONS
-- =============================================================================

-- Track deviations from canonical patterns
CREATE TABLE IF NOT EXISTS violations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER NOT NULL,

    violation_type TEXT NOT NULL CHECK(violation_type IN (
        'missing_baserepository',
        'raw_sql_without_typed_row',
        'missing_sendable',
        'missing_mainactor',
        'inconsistent_pattern',
        'deprecated_pattern',
        'missing_documentation'
    )),

    severity TEXT CHECK(severity IN ('low', 'medium', 'high', 'critical')),
    description TEXT,
    recommendation TEXT,

    -- Status tracking
    status TEXT DEFAULT 'open' CHECK(status IN ('open', 'acknowledged', 'fixed', 'wontfix')),
    assigned_to TEXT,

    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,

    FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE CASCADE
);

CREATE INDEX idx_violations_file ON violations(file_id);
CREATE INDEX idx_violations_type ON violations(violation_type);
CREATE INDEX idx_violations_severity ON violations(severity);
CREATE INDEX idx_violations_status ON violations(status);

-- =============================================================================
-- DEPENDENCIES
-- =============================================================================

-- Track inter-file dependencies
CREATE TABLE IF NOT EXISTS dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    from_file_id INTEGER NOT NULL,
    to_file_id INTEGER NOT NULL,

    dependency_type TEXT CHECK(dependency_type IN (
        'import', 'inheritance', 'composition', 'protocol_conformance', 'uses'
    )),

    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (from_file_id) REFERENCES files(id) ON DELETE CASCADE,
    FOREIGN KEY (to_file_id) REFERENCES files(id) ON DELETE CASCADE,

    UNIQUE(from_file_id, to_file_id, dependency_type)
);

CREATE INDEX idx_deps_from ON dependencies(from_file_id);
CREATE INDEX idx_deps_to ON dependencies(to_file_id);
CREATE INDEX idx_deps_type ON dependencies(dependency_type);

-- =============================================================================
-- VIEWS FOR REPORTING
-- =============================================================================

-- Active files (not deleted)
CREATE VIEW active_files AS
SELECT * FROM files WHERE is_deleted = 0;

-- Recent changes (last 7 days)
CREATE VIEW recent_changes AS
SELECT
    fh.*,
    f.file_path,
    f.layer,
    f.domain_entity
FROM file_history fh
JOIN files f ON fh.file_id = f.id
WHERE fh.changed_at > datetime('now', '-7 days')
ORDER BY fh.changed_at DESC;

-- Files by complexity
CREATE VIEW files_by_complexity AS
SELECT
    complexity,
    COUNT(*) as count,
    GROUP_CONCAT(file_path, ', ') as files
FROM active_files
GROUP BY complexity
ORDER BY
    CASE complexity
        WHEN 'Simple' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Complex' THEN 3
    END;

-- Files by layer
CREATE VIEW files_by_layer AS
SELECT
    layer,
    COUNT(*) as count,
    ROUND(AVG(line_count), 0) as avg_lines
FROM active_files
GROUP BY layer
ORDER BY count DESC;

-- Files by domain
CREATE VIEW files_by_domain AS
SELECT
    domain_entity,
    COUNT(*) as count,
    GROUP_CONCAT(DISTINCT layer) as layers
FROM active_files
GROUP BY domain_entity
ORDER BY count DESC;

-- Open violations
CREATE VIEW open_violations AS
SELECT
    v.*,
    f.file_path,
    f.layer,
    f.domain_entity
FROM violations v
JOIN files f ON v.file_id = f.id
WHERE v.status = 'open'
ORDER BY
    CASE v.severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
    END,
    v.detected_at DESC;

-- Scan summary
CREATE VIEW scan_summary AS
SELECT
    sr.id,
    sr.started_at,
    sr.git_branch,
    sr.git_commit_hash,
    sr.files_scanned,
    sr.files_created,
    sr.files_modified,
    sr.files_deleted,
    ss.total_files,
    ss.total_lines
FROM scan_runs sr
LEFT JOIN scan_statistics ss ON sr.id = ss.scan_run_id
ORDER BY sr.started_at DESC;

-- =============================================================================
-- SAMPLE QUERIES
-- =============================================================================

-- Find all repositories not extending BaseRepository
-- SELECT * FROM active_files
-- WHERE layer = 'Repository'
--   AND extends_conforms NOT LIKE '%BaseRepository%';

-- Find complex files without documentation
-- SELECT * FROM active_files
-- WHERE complexity = 'Complex'
--   AND (file_purpose IS NULL OR file_purpose = '');

-- Track changes to a specific file
-- SELECT * FROM file_history
-- WHERE file_path = 'swift/Sources/Services/Repositories/GoalRepository.swift'
-- ORDER BY changed_at DESC;

-- Files changed in last scan
-- SELECT * FROM recent_changes
-- WHERE scan_run_id = (SELECT MAX(id) FROM scan_runs);

-- Complexity distribution over time
-- SELECT
--     DATE(sr.started_at) as scan_date,
--     json_extract(ss.files_by_complexity, '$.Simple') as simple,
--     json_extract(ss.files_by_complexity, '$.Medium') as medium,
--     json_extract(ss.files_by_complexity, '$.Complex') as complex
-- FROM scan_runs sr
-- JOIN scan_statistics ss ON sr.id = ss.scan_run_id
-- ORDER BY sr.started_at;
