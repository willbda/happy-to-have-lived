-- DEDUPLICATION SCHEMA
-- Written by Claude Code on 2025-11-12
-- INTEGRATED: 2025-11-17 into schema_current.sql (lines 607-676)
--
-- PURPOSE: Tables for tracking and managing duplicate candidates
-- STRATEGY: Store similarity scores, allow user review and resolution
--
-- This schema supports both proactive (form validation) and reactive (data hygiene)
-- duplicate detection workflows.
--
-- NOTE: This file is now a reference only. The actual schema is in:
-- swift/Sources/Database/Schemas/schema_current.sql (DEDUPLICATION TRACKING SCHEMA section)
-- UNIQUE constraints were removed for CloudKit sync compatibility.

-- DuplicateCandidates: Track potential duplicates for user review
CREATE TABLE duplicateCandidates (
    -- Identity
    id TEXT PRIMARY KEY,

    -- Entity classification
    entityType TEXT NOT NULL CHECK(entityType IN (
        'action', 'expectation', 'measure', 'personalValue', 'timePeriod',
        'goal', 'milestone', 'obligation', 'goalTerm'
    )),

    -- The two entities being compared
    entity1Id TEXT NOT NULL,
    entity2Id TEXT NOT NULL,

    -- Similarity analysis
    similarity REAL NOT NULL CHECK(similarity >= 0.0 AND similarity <= 1.0),
    severity TEXT NOT NULL CHECK(severity IN ('exact', 'high', 'moderate', 'low')),

    -- Processing state
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'merged', 'ignored', 'resolved')),

    -- Temporal metadata
    createdAt TEXT NOT NULL,
    reviewedAt TEXT,
    resolvedAt TEXT,

    -- Resolution details
    resolution TEXT, -- 'merged_into_1', 'merged_into_2', 'kept_both', 'deleted_1', 'deleted_2'
    resolutionNotes TEXT,

    -- Ensure we don't duplicate the duplicate detection
    UNIQUE(entityType, entity1Id, entity2Id)
);

-- Index for finding unresolved duplicates by type
CREATE INDEX idx_duplicate_candidates_pending ON duplicateCandidates(entityType, status)
WHERE status = 'pending';

-- Index for finding duplicates for a specific entity
CREATE INDEX idx_duplicate_candidates_entity1 ON duplicateCandidates(entityType, entity1Id);
CREATE INDEX idx_duplicate_candidates_entity2 ON duplicateCandidates(entityType, entity2Id);

-- Index for high-severity duplicates requiring attention
CREATE INDEX idx_duplicate_candidates_severity ON duplicateCandidates(severity, status)
WHERE severity IN ('exact', 'high') AND status = 'pending';

-- =============================================================================
-- DEDUPLICATION SIGNATURES TABLE (Optional - for caching)
-- =============================================================================
-- Store precomputed MinHash signatures to avoid recomputation
-- This is an optimization that can be added later if performance requires it

CREATE TABLE IF NOT EXISTS entitySignatures (
    -- Identity
    id TEXT PRIMARY KEY,

    -- Entity reference
    entityType TEXT NOT NULL,
    entityId TEXT NOT NULL,

    -- Signature data
    signature BLOB NOT NULL, -- Serialized MinHash signature
    semanticContent TEXT NOT NULL, -- The content that was hashed (for debugging)

    -- Metadata
    computedAt TEXT NOT NULL,
    lshVersion INTEGER NOT NULL DEFAULT 1, -- Track algorithm version for invalidation

    -- Unique constraint
    UNIQUE(entityType, entityId)
);

-- Index for fast signature lookups
CREATE INDEX IF NOT EXISTS idx_entity_signatures_lookup ON entitySignatures(entityType, entityId);

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

-- Insert a duplicate candidate
/*
INSERT INTO duplicateCandidates (
    id, entityType, entity1Id, entity2Id,
    similarity, severity, status, createdAt
) VALUES (
    lower(hex(randomblob(16))),
    'action',
    'uuid-1',
    'uuid-2',
    0.87,
    'high',
    'pending',
    datetime('now')
);
*/

-- Find all pending duplicates for review
/*
SELECT
    dc.*,
    a1.title as entity1_title,
    a2.title as entity2_title
FROM duplicateCandidates dc
LEFT JOIN actions a1 ON dc.entity1Id = a1.id
LEFT JOIN actions a2 ON dc.entity2Id = a2.id
WHERE dc.status = 'pending'
  AND dc.entityType = 'action'
ORDER BY dc.similarity DESC;
*/

-- Mark duplicates as resolved after merge
/*
UPDATE duplicateCandidates
SET
    status = 'merged',
    resolvedAt = datetime('now'),
    resolution = 'merged_into_1',
    resolutionNotes = 'User confirmed these were duplicates'
WHERE id = ?;
*/

-- Ignore a false positive
/*
UPDATE duplicateCandidates
SET
    status = 'ignored',
    reviewedAt = datetime('now'),
    resolution = 'kept_both',
    resolutionNotes = 'User confirmed these are distinct'
WHERE id = ?;
*/

-- Find high-severity duplicates needing immediate attention
/*
SELECT COUNT(*) as duplicate_count, entityType, severity
FROM duplicateCandidates
WHERE status = 'pending'
GROUP BY entityType, severity
ORDER BY
    CASE severity
        WHEN 'exact' THEN 1
        WHEN 'high' THEN 2
        WHEN 'moderate' THEN 3
        WHEN 'low' THEN 4
    END;
*/

-- Clean up old resolved duplicates (housekeeping)
/*
DELETE FROM duplicateCandidates
WHERE status IN ('merged', 'resolved')
  AND resolvedAt < datetime('now', '-30 days');
*/