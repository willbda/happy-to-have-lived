-- ABSTRACTION LAYER SCHEMA
-- Written by Claude Code on 2025-10-31
--
-- DomainAbstraction = Identifiable + Documentable + Timestamped
-- Full metadata entities with id, title, detailedDescription, freeformNotes, logTime

-- Actions: Record what was done (past-oriented)
CREATE TABLE actions (
    id TEXT PRIMARY KEY,
    title TEXT,
    detailedDescription TEXT,
    freeformNotes TEXT,
    logTime TEXT NOT NULL,
    durationMinutes REAL, -- There's some design/use tension here. Duration is available as a measure, where it is meant to relate to a goal target. Here it is meant to capture the time spent on the recorded action itself. These two concepts may often overlap, and the current design doesn't make it clear for the user that there is a distinction or why. Perhaps in future iterations we can clarify this in the UI or adjust the schema to better reflect user intent.
    startTime TEXT
);

-- Expectations: Base table for goals/milestones/obligations (table inheritance)
CREATE TABLE expectations (
    id TEXT PRIMARY KEY,
    title TEXT,
    detailedDescription TEXT,
    freeformNotes TEXT,
    logTime TEXT NOT NULL,
    expectationType TEXT NOT NULL CHECK(expectationType IN ('goal', 'milestone', 'obligation')),
    expectationImportance INTEGER NOT NULL,
    expectationUrgency INTEGER NOT NULL
);

-- Measures: Catalog of measurement units
CREATE TABLE measures (
    id TEXT PRIMARY KEY,
    title TEXT,
    detailedDescription TEXT,
    freeformNotes TEXT,
    logTime TEXT NOT NULL,
    unit TEXT NOT NULL,
    measureType TEXT NOT NULL,
    canonicalUnit TEXT,
    conversionFactor REAL
);

-- PersonalValues: Unified values and life areas
CREATE TABLE personalValues (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL CHECK(LENGTH(TRIM(title)) > 0),
    detailedDescription TEXT,
    freeformNotes TEXT,
    logTime TEXT NOT NULL,
    priority INTEGER NOT NULL,
    valueLevel TEXT NOT NULL CHECK(valueLevel IN ('general', 'major', 'highest_order', 'life_area')),
    lifeDomain TEXT,
    alignmentGuidance TEXT
);

-- TimePeriods: Pure chronological boundaries (no planning semantics)
CREATE TABLE timePeriods (
    id TEXT PRIMARY KEY,
    title TEXT,
    detailedDescription TEXT,
    freeformNotes TEXT,
    logTime TEXT NOT NULL,
    startDate TEXT NOT NULL,
    endDate TEXT NOT NULL,
    CHECK(startDate <= endDate)
);
-- BASIC LAYER SCHEMA
-- Written by Claude Code on 2025-10-31
--
-- DomainBasic = Identifiable
-- Lightweight working entities with id + FK references + type-specific fields

-- Goals: Expectation subtype with date ranges and action plans
CREATE TABLE goals (
    id TEXT PRIMARY KEY,
    expectationId TEXT NOT NULL,
    startDate TEXT,
    targetDate TEXT,
    actionPlan TEXT,
    expectedTermLength INTEGER,
    FOREIGN KEY (expectationId) REFERENCES expectations(id) ON DELETE CASCADE
);

-- Milestones: Expectation subtype for point-in-time checkpoints
CREATE TABLE milestones (
    id TEXT PRIMARY KEY,
    expectationId TEXT NOT NULL,
    targetDate TEXT NOT NULL,
    FOREIGN KEY (expectationId) REFERENCES expectations(id) ON DELETE CASCADE
);

-- Obligations: Expectation subtype for external commitments
CREATE TABLE obligations (
    id TEXT PRIMARY KEY,
    expectationId TEXT NOT NULL,
    deadline TEXT NOT NULL,
    requestedBy TEXT,
    consequence TEXT,
    FOREIGN KEY (expectationId) REFERENCES expectations(id) ON DELETE CASCADE
);

-- GoalTerms: Planning scaffolds with state (references TimePeriod for dates)
CREATE TABLE goalTerms (
    id TEXT PRIMARY KEY,
    timePeriodId TEXT NOT NULL,
    termNumber INTEGER NOT NULL,
    theme TEXT,
    reflection TEXT,
    status TEXT CHECK(status IN ('planned', 'active', 'completed', 'delayed', 'on_hold', 'cancelled')),
    FOREIGN KEY (timePeriodId) REFERENCES timePeriods(id) ON DELETE CASCADE
);

-- ExpectationMeasures: Measurable targets for expectations
-- Note: UNIQUE constraint removed for CloudKit sync compatibility
-- Uniqueness enforced at application level in repositories
CREATE TABLE expectationMeasures (
    id TEXT PRIMARY KEY,
    expectationId TEXT NOT NULL,
    measureId TEXT NOT NULL,
    targetValue REAL NOT NULL,
    freeformNotes TEXT,
    createdAt TEXT NOT NULL,
    FOREIGN KEY (expectationId) REFERENCES expectations(id) ON DELETE CASCADE,
    FOREIGN KEY (measureId) REFERENCES measures(id) ON DELETE RESTRICT
);
-- COMPOSIT LAYER SCHEMA
-- Written by Claude Code on 2025-10-31
--
-- DomainComposit = Identifiable
-- Pure junction tables with id + FK references + relationship data

-- MeasuredActions: Links actions to measurements
-- Note: UNIQUE constraint removed for CloudKit sync compatibility
-- Uniqueness enforced at application level in repositories
CREATE TABLE measuredActions (
    id TEXT PRIMARY KEY,
    actionId TEXT NOT NULL,
    measureId TEXT NOT NULL,
    value REAL NOT NULL,
    createdAt TEXT NOT NULL,
    FOREIGN KEY (actionId) REFERENCES actions(id) ON DELETE CASCADE,
    FOREIGN KEY (measureId) REFERENCES measures(id) ON DELETE RESTRICT
);

-- GoalRelevances: Links goals to values they serve
-- Note: UNIQUE constraint removed for CloudKit sync compatibility
-- Uniqueness enforced at application level in repositories
CREATE TABLE goalRelevances (
    id TEXT PRIMARY KEY,
    goalId TEXT NOT NULL,
    valueId TEXT NOT NULL,
    alignmentStrength INTEGER CHECK(alignmentStrength BETWEEN 1 AND 10),
    relevanceNotes TEXT,
    createdAt TEXT NOT NULL,
    FOREIGN KEY (goalId) REFERENCES goals(id) ON DELETE CASCADE,
    FOREIGN KEY (valueId) REFERENCES personalValues(id) ON DELETE CASCADE
);

-- ActionGoalContributions: Tracks action progress toward goals
-- Note: UNIQUE constraint removed for CloudKit sync compatibility
-- Uniqueness enforced at application level in repositories
CREATE TABLE actionGoalContributions (
    id TEXT PRIMARY KEY,
    actionId TEXT NOT NULL,
    goalId TEXT NOT NULL,
    contributionAmount REAL,
    measureId TEXT,
    createdAt TEXT NOT NULL,
    FOREIGN KEY (actionId) REFERENCES actions(id) ON DELETE CASCADE,
    FOREIGN KEY (goalId) REFERENCES goals(id) ON DELETE CASCADE,
    FOREIGN KEY (measureId) REFERENCES measures(id) ON DELETE RESTRICT
);

-- TermGoalAssignments: Assigns goals to terms
-- Note: UNIQUE constraint removed for CloudKit sync compatibility
-- Uniqueness enforced at application level in repositories
CREATE TABLE termGoalAssignments (
    id TEXT PRIMARY KEY,
    termId TEXT NOT NULL,
    goalId TEXT NOT NULL,
    assignmentOrder INTEGER,
    createdAt TEXT NOT NULL,
    FOREIGN KEY (termId) REFERENCES goalTerms(id) ON DELETE CASCADE,
    FOREIGN KEY (goalId) REFERENCES goals(id) ON DELETE CASCADE
);

-- =============================================================================
-- PERFORMANCE INDEXES
-- Written by Claude Code on 2025-11-03
-- PURPOSE: Optimize JOIN queries and foreign key lookups
-- =============================================================================

-- ActionsQuery indexes (for measured_actions + measures JOIN)
-- Used by: ActionsWithMeasuresAndGoals FetchKeyRequest
-- Impact: Eliminates N+1 query problem (763 queries → 3 queries)
CREATE INDEX IF NOT EXISTS idx_measured_actions_action_id ON measuredActions(actionId);
CREATE INDEX IF NOT EXISTS idx_measured_actions_measure_id ON measuredActions(measureId);

-- ActionsQuery indexes (for action_goal_contributions + goals JOIN)
-- Used by: ActionsWithMeasuresAndGoals FetchKeyRequest
-- Impact: Fast lookups for goal contributions per action
CREATE INDEX IF NOT EXISTS idx_action_goal_contributions_action_id ON actionGoalContributions(actionId);
CREATE INDEX IF NOT EXISTS idx_action_goal_contributions_goal_id ON actionGoalContributions(goalId);

-- TermsQuery index (for goal_terms + time_periods JOIN)
-- Used by: TermsWithPeriods FetchKeyRequest
-- Impact: Fast lookups for term periods (already efficient, but ensures index usage)
CREATE INDEX IF NOT EXISTS idx_goal_terms_time_period_id ON goalTerms(timePeriodId);

-- GoalsQuery indexes (for future implementation in Phase 1)
-- Used by: Upcoming GoalsWithExpectations FetchKeyRequest
-- Impact: Fast lookups for goal details and targets
CREATE INDEX IF NOT EXISTS idx_goals_expectation_id ON goals(expectationId);
CREATE INDEX IF NOT EXISTS idx_expectation_measures_expectation_id ON expectationMeasures(expectationId);
CREATE INDEX IF NOT EXISTS idx_expectation_measures_measure_id ON expectationMeasures(measureId);

-- Value alignment indexes (for future goal-value queries)
-- Used by: Upcoming value alignment features
-- Impact: Fast filtering of goals by aligned values
CREATE INDEX IF NOT EXISTS idx_goal_relevances_goal_id ON goalRelevances(goalId);
CREATE INDEX IF NOT EXISTS idx_goal_relevances_value_id ON goalRelevances(valueId);

-- Term assignment indexes (for goal planning queries)
-- Used by: Term planning features showing assigned goals
-- Impact: Fast lookups of goals per term and terms per goal
CREATE INDEX IF NOT EXISTS idx_term_goal_assignments_term_id ON termGoalAssignments(termId);
CREATE INDEX IF NOT EXISTS idx_term_goal_assignments_goal_id ON termGoalAssignments(goalId);

-- =============================================================================
-- INDEX USAGE NOTES
-- =============================================================================
--
-- Query patterns these indexes support:
--
-- 1. "Show all measurements for action X"
--    SELECT * FROM measuredActions WHERE actionId = ?
--    → Uses idx_measured_actions_action_id
--
-- 2. "Show all actions using metric Y"
--    SELECT * FROM measuredActions WHERE measureId = ?
--    → Uses idx_measured_actions_measure_id
--
-- 3. "Show all goals this action contributes to"
--    SELECT * FROM actionGoalContributions WHERE actionId = ?
--    → Uses idx_action_goal_contributions_action_id
--
-- 4. "Show all actions contributing to goal Z"
--    SELECT * FROM actionGoalContributions WHERE goalId = ?
--    → Uses idx_action_goal_contributions_goal_id
--
-- 5. "Show term details with dates"
--    SELECT * FROM goalTerms JOIN timePeriods ON goalTerms.timePeriodId = timePeriods.id
--    → Uses idx_goal_terms_time_period_id
--
-- 6. "Show goal with expectation details"
--    SELECT * FROM goals JOIN expectations ON goals.expectationId = expectations.id
--    → Uses idx_goals_expectation_id
--
-- 7. "Show all goals aligned with value V"
--    SELECT * FROM goalRelevances WHERE valueId = ?
--    → Uses idx_goal_relevances_value_id
--
-- 8. "Show all goals in term T"
--    SELECT * FROM termGoalAssignments WHERE termId = ?
--    → Uses idx_term_goal_assignments_term_id
--
-- =============================================================================

-- Apple Data Staging Table
-- Written by Claude Code on 2025-10-31
--
-- PURPOSE: Temporary storage for raw Apple SDK responses (HealthKit, EventKit)
-- STRATEGY: Ingest → Parse → Normalize → Purge
--
-- This table stores raw JSON from Apple SDKs, allowing:
-- 1. Incremental parsing (don't block on data fetch)
-- 2. Re-parsing with improved logic (fix bugs retroactively)
-- 3. Data archaeology (can extract new measures from old data)
-- 4. Audit trail (see exactly what Apple returned)

CREATE TABLE appledata (
    -- Identity
    id TEXT PRIMARY KEY,

    -- Source classification
    sourceSDK TEXT NOT NULL CHECK(sourceSDK IN ('HealthKit', 'EventKit')),
    dataType TEXT NOT NULL,          -- 'sleep', 'calories', 'workout', 'calendar', 'reminder'

    -- Temporal metadata
    fetchedAt TEXT NOT NULL,         -- When we fetched this from Apple
    startDate TEXT NOT NULL,         -- Data period start (for queries)
    endDate TEXT NOT NULL,           -- Data period end (for queries)

    -- Raw data storage
    rawJSON TEXT NOT NULL,           -- Complete Apple SDK response (encoded as JSON string)

    -- Processing state
    parsed BOOLEAN DEFAULT 0,        -- Has this been processed into normalized measures?
    parsedAt TEXT,                   -- When we parsed it
    parseError TEXT,                 -- If parsing failed, why?

    -- Lifecycle management
    purgeAfter TEXT,                 -- Auto-delete after this date
    logTime TEXT NOT NULL            -- Record creation timestamp
);

-- Index for finding unparsed data (batch processing)
CREATE INDEX idx_appledata_unparsed ON appledata(parsed, sourceSDK, dataType)
WHERE parsed = 0;

-- Index for purge cleanup (periodic deletion)
CREATE INDEX idx_appledata_purge ON appledata(purgeAfter)
WHERE purgeAfter IS NOT NULL;

-- Index for date range queries (re-fetch detection)
CREATE INDEX idx_appledata_dates ON appledata(sourceSDK, dataType, startDate, endDate);

-- Unique constraint: Don't store duplicate fetches
CREATE UNIQUE INDEX idx_appledata_unique_fetch ON appledata(sourceSDK, dataType, startDate, endDate);

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

-- Insert raw HealthKit sleep data
/*
INSERT INTO appledata (id, sourceSDK, dataType, fetchedAt, startDate, endDate, rawJSON, purgeAfter, logTime)
VALUES (
    lower(hex(randomblob(16))),
    'HealthKit',
    'sleep',
    datetime('now'),
    '2025-10-30 00:00:00',
    '2025-10-31 00:00:00',
    '[{"uuid":"ABC","startDate":"2025-10-30T23:00:00Z","endDate":"2025-10-31T07:30:00Z","value":"asleep"}]',
    datetime('now', '+7 days'),  -- Purge after 7 days
    datetime('now')
);
*/

-- Find unparsed records for processing
/*
SELECT id, sourceSDK, dataType, rawJSON
FROM appledata
WHERE parsed = 0
ORDER BY fetchedAt ASC
LIMIT 100;
*/

-- Mark as parsed after successful processing
/*
UPDATE appledata
SET parsed = 1, parsedAt = datetime('now')
WHERE id = ?;
*/

-- Purge old data (run daily)
/*
DELETE FROM appledata
WHERE purgeAfter < datetime('now')
  AND parsed = 1;  -- Only delete if successfully parsed
*/

-- Count unparsed records by type
/*
SELECT sourceSDK, dataType, COUNT(*) as unparsed_count
FROM appledata
WHERE parsed = 0
GROUP BY sourceSDK, dataType;
*/

-- Find parse errors
/*
SELECT id, sourceSDK, dataType, parseError, fetchedAt
FROM appledata
WHERE parseError IS NOT NULL
ORDER BY fetchedAt DESC;
*/

-- SEMANTIC & LLM INFRASTRUCTURE SCHEMA
-- Written by Claude Code on 2025-11-12
--
-- PURPOSE: Foundation for semantic similarity, search, and LLM integration
--
-- DESIGN PRINCIPLES:
-- 1. Single embedding cache serves deduplication, search, and LLM RAG
-- 2. Simple conversation storage in v0.7.5, extensible for future phases
-- 3. Optimize for read-heavy workload (embeddings cached, rarely regenerated)

-- =============================================================================
-- SEMANTIC EMBEDDINGS CACHE
-- =============================================================================

-- Semantic Embeddings: Cached vector representations for similarity operations
-- Used by: DuplicationDetector (semantic matching), SearchService (semantic search),
--          LLM Tools (RetrieveMemoryTool for RAG)
CREATE TABLE semanticEmbeddings (
    id TEXT PRIMARY KEY,

    -- Entity reference
    entityType TEXT NOT NULL,
    entityId TEXT NOT NULL,

    -- Source variant (what text was embedded)
    sourceVariant TEXT NOT NULL CHECK(sourceVariant IN ('title_only', 'full_context')),

    -- Source text tracking (for cache invalidation)
    textHash TEXT NOT NULL,         -- SHA256 of source text (detect changes)
    sourceText TEXT NOT NULL,       -- Original text (for debugging/audit)

    -- Embedding data
    embedding BLOB NOT NULL,        -- Serialized float32 array from NLEmbedding
    embeddingModel TEXT NOT NULL,   -- 'NLEmbedding-sentence-english' (for future model migrations)
    dimensionality INTEGER NOT NULL, -- Vector size (for validation)

    -- Metadata
    generatedAt TEXT NOT NULL,
    logTime TEXT NOT NULL
);

-- Indexes for fast lookups
CREATE INDEX idx_semantic_embeddings_entity ON semanticEmbeddings(entityType, entityId, sourceVariant);
CREATE INDEX idx_semantic_embeddings_type ON semanticEmbeddings(entityType, sourceVariant);
CREATE INDEX idx_semantic_embeddings_generated ON semanticEmbeddings(generatedAt);

-- =============================================================================
-- USAGE NOTES: semanticEmbeddings
-- =============================================================================
--
-- SOURCE VARIANT STRATEGY:
-- Each entity can have TWO embeddings (same entityId, different sourceVariant):
--
-- 1. title_only: Fast duplicate detection (3KB vector)
--    - Contains just the title/semantic key
--    - Used by: DuplicationDetector, quick similarity checks
--    - Example: "run a marathon this year"
--
-- 2. full_context: Rich semantic search for LLM RAG (3KB vector)
--    - Contains title + description + notes + domain-specific fields
--    - Used by: SemanticSearchService, LLM RetrieveMemoryTool
--    - Example: "run a marathon this year. complete 26.2 miles by december. targets: 120 km. values: health"
--
-- QUERY PATTERN:
-- SELECT embedding FROM semanticEmbeddings
-- WHERE entityType = 'goal' AND entityId = ? AND sourceVariant = 'title_only'
--
-- STORAGE EFFICIENCY:
-- - Each entity: 2 embeddings × 3KB = 6KB total
-- - 1000 goals: 6MB total (negligible storage cost)
-- - Separate storage enables independent cache invalidation
--
-- CACHE INVALIDATION STRATEGY:
-- When entity text changes, textHash changes → new embedding generated
-- Old embeddings automatically orphaned (cleaned up by periodic purge)
--
-- Example: Goal title changes from "Run marathon" to "Complete 26.2 miles"
-- 1. Title-only embedding regenerated (title changed)
-- 2. Full-context embedding regenerated (title is part of full context)
-- 3. Old embeddings remain until purge
-- 4. No foreign key cascade needed (cache is ephemeral)
--
-- Example: Goal description changes (title unchanged)
-- 1. Title-only embedding UNCHANGED (title didn't change, hash matches)
-- 2. Full-context embedding regenerated (description is part of full context)
-- 3. Independent invalidation saves compute (no need to regenerate title embedding)
--
-- LAZY GENERATION PATTERN:
-- Embeddings generated on-demand during:
-- - Duplicate detection (when checking new entity) → title_only variant
-- - Semantic search (first query for entity type) → full_context variant
-- - LLM tool calls (when RetrieveMemoryTool queries) → full_context variant
--
-- BACKGROUND GENERATION:
-- Optional batch process can pre-generate embeddings for:
-- - All existing goals/actions/values (one-time migration)
-- - New entities created in last 24 hours (daily cron)
--
-- =============================================================================

-- =============================================================================
-- LLM CONVERSATION STORAGE (v0.7.5 - Simple Version)
-- =============================================================================

-- LLM Conversations: Header records for conversation threads
-- Used by: GoalCoachViewModel, ValuesAlignmentCoachViewModel
CREATE TABLE llmConversations (
    id TEXT PRIMARY KEY,

    -- User and type
    userId TEXT NOT NULL,           -- For multi-user support (future)
    conversationType TEXT NOT NULL CHECK(conversationType IN (
        'goal_setting',             -- Conversational goal creation
        'reflection',               -- Weekly/daily reflection
        'values_alignment',         -- Values alignment analysis
        'general'                   -- Open-ended coaching
    )),

    -- Temporal tracking
    startedAt TEXT NOT NULL,
    lastMessageAt TEXT NOT NULL,

    -- Session management (for context window overflow handling)
    sessionNumber INTEGER NOT NULL DEFAULT 1,

    -- Lifecycle
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'archived', 'deleted')),

    logTime TEXT NOT NULL
);

CREATE INDEX idx_llm_conversations_user ON llmConversations(userId, status);
CREATE INDEX idx_llm_conversations_type ON llmConversations(conversationType, status);
CREATE INDEX idx_llm_conversations_active ON llmConversations(status, lastMessageAt);

-- LLM Messages: Individual messages in conversation threads
-- Used by: Conversation persistence, UI rendering
CREATE TABLE llmMessages (
    id TEXT PRIMARY KEY,
    conversationId TEXT NOT NULL,

    -- Message content
    role TEXT NOT NULL CHECK(role IN ('user', 'assistant', 'system', 'tool_call', 'tool_response')),
    content TEXT NOT NULL,          -- User message, assistant response, or tool output

    -- Optional structured data (for tool calls and responses)
    structuredDataJSON TEXT,        -- Serialized @Generable types (GoalCreationData, etc.)
    toolName TEXT,                  -- If role='tool_call', which tool was invoked

    -- Metadata
    timestamp TEXT NOT NULL,
    sessionNumber INTEGER NOT NULL DEFAULT 1,

    -- Lifecycle
    isArchived INTEGER NOT NULL DEFAULT 0,  -- Moved out of active context window

    FOREIGN KEY (conversationId) REFERENCES llmConversations(id) ON DELETE CASCADE
);

CREATE INDEX idx_llm_messages_conversation ON llmMessages(conversationId, isArchived, timestamp);
CREATE INDEX idx_llm_messages_session ON llmMessages(conversationId, sessionNumber);

-- =============================================================================
-- USAGE NOTES: llmConversations + llmMessages
-- =============================================================================
--
-- Simple v0.7.5 Pattern:
-- - One conversation per goal-setting session
-- - All messages stored with role (user/assistant/tool_call/tool_response)
-- - No token counting yet (Phase 2 feature)
-- - No transcript serialization yet (Phase 2 feature)
--
-- Example Flow:
-- 1. User starts conversation → INSERT llmConversations
-- 2. User: "I want to write more" → INSERT llmMessages (role='user')
-- 3. LLM calls GetValuesTool → INSERT llmMessages (role='tool_call', toolName='getPersonalValues')
-- 4. Tool returns values → INSERT llmMessages (role='tool_response')
-- 5. LLM: "I see you value creativity..." → INSERT llmMessages (role='assistant')
--
-- Context Window Management (Phase 2):
-- When conversation exceeds 15 messages:
-- 1. Increment sessionNumber
-- 2. Mark old messages as isArchived=1
-- 3. Generate summary, store in new system message
-- 4. Continue with fresh context window
--
-- Conversation Resumption:
-- 1. Load llmMessages WHERE conversationId = X AND isArchived = 0
-- 2. Reconstruct Transcript from messages
-- 3. Create new LanguageModelSession with transcript
--
-- =============================================================================

-- =============================================================================
-- FUTURE SCHEMA EXTENSIONS (Phase 2+)
-- =============================================================================
--
-- Phase 2: Token Tracking & Summarization
-- ALTER TABLE llmConversations ADD COLUMN tokenCount INTEGER DEFAULT 0;
-- ALTER TABLE llmConversations ADD COLUMN summaryText TEXT;
-- ALTER TABLE llmMessages ADD COLUMN tokenCount INTEGER;
--
-- Phase 3: RAG & Memory Management
-- CREATE TABLE llmMemoryChunks (
--     id TEXT PRIMARY KEY,
--     userId TEXT NOT NULL,
--     contentType TEXT NOT NULL,
--     contentId TEXT NOT NULL,
--     textChunk TEXT NOT NULL,
--     embeddingId TEXT NOT NULL,
--     relevanceScore REAL,
--     FOREIGN KEY (embeddingId) REFERENCES semanticEmbeddings(id)
-- );
--
-- Phase 3: Usage Analytics
-- CREATE TABLE llmUsageTracking (
--     id TEXT PRIMARY KEY,
--     userId TEXT NOT NULL,
--     date TEXT NOT NULL,
--     conversationCount INTEGER DEFAULT 0,
--     messageCount INTEGER DEFAULT 0,
--     toolCallCount INTEGER DEFAULT 0,
--     averageResponseTime REAL
-- );
--
-- =============================================================================

-- =============================================================================
-- MIGRATION PATH FROM CURRENT SCHEMA
-- =============================================================================
--
-- This schema extends the existing schema_current.sql without modifying it.
-- No foreign keys to existing tables (semanticEmbeddings is a cache layer).
--
-- Integration points:
-- 1. semanticEmbeddings.entityId references goals.id, actions.id, personalValues.id
--    (no FK constraint - cache can outlive entities)
-- 2. LLM tools query existing tables via FetchKeyRequest patterns
-- 3. LLM CreateGoalTool uses GoalCoordinator (writes to goals + expectations tables)
--
-- =============================================================================
