# Semantic Embeddings: Lessons Learned

**Written by Claude Code on 2025-11-20**

## Summary

Value alignment feature using automated semantic similarity scoring was removed in v0.7.0 due to systematically misleading results. This document captures the architectural lessons learned and establishes proper use cases for semantic embeddings.

---

## What Was Removed (2025-11-20)

### Deleted Files
- `ValueAlignmentHeatmapView.swift` - Legacy heatmap visualization
- `ValueAlignmentInsightsView.swift` - Modern insights UI with portfolio health scoring
- `ValueAlignmentHeatmapViewModel.swift` - ViewModel orchestrating alignment computation
- `ValueAlignmentService.swift` - Service performing flawed semantic comparison

### Preserved Infrastructure
- ✅ `EmbeddingGenerationService.swift` - Entity-aware embedding generation with caching
- ✅ `SemanticService.swift` - Core NLEmbedding wrapper with SHA256 cache invalidation
- ✅ `EmbeddingVector.swift` - Float32 vector with cosine similarity computation
- ✅ `semanticEmbeddings` table - 512-dimensional cached embeddings
- ✅ `ValueAlignmentInput.swift` - User-declared goal-value alignment (for future use)

---

## Root Cause Analysis

### The Problem: Variant Mismatch

**Flawed comparison strategy** (ValueAlignmentService:82-86):
```swift
// Goals used titleOnly variant (short, focused)
let goalEmbeddings = try await fetchGoalEmbeddings(goals, variant: .titleOnly)

// Values used fullContext variant (long, philosophical)
let valueEmbeddings = try await fetchValueEmbeddings(values, variant: .fullContext)
```

**Semantic density disparity**:
- Goal text: **3.3 words average** (range: 2-6 words)
  - Example: `"yoga, mobility, and strength"`
- Value text: **119.9 words average** (range: 40-298 words)
  - Example: `"physical health and longevity. like my mind, my body needs maintainence, upkeep, and consideration. when attended to with loving care, my body is capable of so much. without loving care, without skill and attention, it is possible to experience all manner of pain and disorder..."`

**36x text length difference** caused systematically low similarity scores.

### Observed Alignment Scores

From production database analysis (2025-11-20):

| Goal | Value | Cosine Similarity | User Expectation |
|------|-------|-------------------|------------------|
| "Yoga, Mobility, and Strength" | "Physical Health and Longevity" | **0.32** (Weak) | Should be Strong |
| "Spring into Running" | "Physical Health and Longevity" | **0.28** (Weak) | Should be Strong |
| "Write for Public Audience" | "Continuous Learning" | **0.15** (Weak) | Should be Moderate |
| "Building Friendships" | "Live Well" | **0.13** (Weak) | Should be Moderate |
| "Log weekly grumpies" | "Physical Health" | **-0.14** (Negative!) | Should be Weak |

**Average score across all pairs**: 0.08-0.20 range (all "Weak" by system thresholds)

### Why This Happened: Information-Theoretic Explanation

**Shannon entropy argument**:
- **Short text** (titleOnly): Low entropy, high information density per token
  - 100% of embedding vector represents the single concept
  - Example: `"run marathon"` → embedding entirely focused on running/marathon semantics

- **Long text** (fullContext): High entropy, information distributed across many concepts
  - Each concept gets ~5-10% of embedding space
  - Example: Physical Health value covers: longevity + maintenance + cardiovascular + strength + pain + deterioration + equanimity + stability...

**Cosine similarity penalizes asymmetry**:
```
Even if the goal's ENTIRE semantic content appears in the value,
it's diluted by the other 90% of value concepts.

Result: Genuinely aligned pairs score 0.30-0.50 instead of 0.75+
```

---

## Deeper Issue: Wrong Semantic Relationship

### Cosine Similarity Measures: Distributional Semantics

**What it captures**: "Do these texts talk about similar concepts using similar language?"
- Good for: synonyms, paraphrases, topic clustering, **duplicate detection**
- Based on: Firth's hypothesis - "You shall know a word by the company it keeps"

**What it doesn't capture**: Intentional or causal relationships
- ❌ "Does achieving this goal **contribute to** this value?"
- ❌ "Is this goal a **means** to that value as an **end**?"
- ❌ "Would someone holding this value recognize this goal as serving it?"

### Example: Semantic Similarity ≠ Alignment

**High lexical overlap, low intentional alignment**:
```
Goal: "Read philosophy books weekly"
Value: "Economic Health and Independence"
Cosine: 0.15 (low - different semantic domains)
Actual alignment: LOW (philosophy ≠ finance)
```

**Low lexical overlap, high intentional alignment**:
```
Goal: "Meditate 5 minutes daily"
Value: "Equanimity, Peace, Freedom from Suffering"
Cosine: 0.25 (low - sparse overlap)
Actual alignment: HIGH (meditation → equanimity)
```

**Insight**: Alignment is an **entailment relationship**, not a **distributional similarity**.

---

## Valid Use Cases for Semantic Embeddings

### ✅ 1. Duplicate Detection (Original Design Purpose)

**Pattern**: Compare entities of SAME type with SAME variant
```swift
// Detect duplicate goals using titleOnly variant
let goal1 = "run a marathon this year"
let goal2 = "complete 26.2 mile race by december"
// Cosine: ~0.85 (Strong - likely duplicate)
```

**Why it works**:
- Symmetric comparison (both titleOnly, similar length)
- Measuring genuine semantic equivalence, not intentionality

### ✅ 2. Semantic Search

**Pattern**: User query against entity catalog
```swift
// User searches: "fitness goals"
// Matches goals with embeddings close to query embedding
// Returns: "yoga practice", "run marathon", "strength training"
```

**Why it works**:
- Query and results in same semantic space
- User interprets results (not relying on threshold automation)

### ✅ 3. LLM RAG (Retrieval-Augmented Generation)

**Pattern**: Retrieve relevant context for LLM tool calls
```swift
// LLM is creating a goal about "building strength"
// RetrieveMemoryTool fetches:
// - Existing "strength training" goal (avoid duplicate)
// - "Physical Health" value (suggest alignment)
// - Historical strength-related actions (provide context)
```

**Why it works**:
- LLM interprets retrieved context semantically
- No automated threshold decisions
- Human (or LLM) makes final judgment

### ❌ 4. Automated Goal-Value Alignment (INVALID)

**Why it fails**:
- Compares different semantic densities (short goals vs long values)
- Measures distributional similarity, not intentional entailment
- No user context for disambiguation
- Produces misleading confidence scores

---

## Future Design: Proper Alignment Detection

### Phase 1: User-Declared Alignment (CURRENT INFRASTRUCTURE)

**Already implemented** (preserved in removal):
- `ValueAlignmentInput.swift` - Struct for user declarations
- `GoalRelevance` table - Stores goal-value links with strength (1-10)
- `GoalFormView` - UI for selecting aligned values during goal creation

**Pattern**:
```swift
// User creating goal: "Run 120km over 10 weeks"
// User selects: "Physical Health" (strength: 8/10)
// System stores: GoalRelevance(goalId, valueId, alignmentStrength: 8)
```

**Advantage**: Captures intentionality that semantics can't detect

### Phase 2: LLM-Augmented Reasoning

**Pattern**: Use Foundation Models to reason about entailment
```swift
let prompt = """
Does achieving this goal serve this value?

Goal: \(goal.title). \(goal.description)
Value: \(value.title). \(value.description)

Consider:
1. Does the goal's concrete actions contribute to the value's essence?
2. Is the goal an instrumental means to the value as an end?
3. Would someone holding this value recognize this as serving it?

Rate alignment (0-10) with 2-sentence reasoning.
"""

// LLM response:
// "Alignment: 8/10. Running 120km directly builds cardiovascular
// health and physical capacity, core aspects of the Physical Health
// value. The structured approach shows commitment to bodily care."
```

**Advantage**: Captures causal/intentional relationships, not just lexical overlap

### Phase 3: Hybrid Scoring

**Combine multiple signals**:
```swift
struct AlignmentScore {
    let userDeclared: Double?           // If user explicitly linked (0-10)
    let llmReasoning: Double?           // If LLM analyzed entailment (0-10)
    let semanticSimilarity: Double      // Cosine similarity (0-1)
    let contributionHistory: Double?    // If actions logged toward goal+value

    var composite: Double {
        // Weight user intent heavily, LLM reasoning second, semantics as fallback
        if let declared = userDeclared {
            return declared * 0.7 + (llmReasoning ?? semanticSimilarity * 10) * 0.3
        } else if let llm = llmReasoning {
            return llm
        } else {
            return semanticSimilarity * 10  // Only use if no better signal available
        }
    }
}
```

**Design principle**: System provides **evidence and suggestions**, user makes **final judgment**.

---

## Architectural Lessons

### 1. Domain Modeling Principle

**Question before building**: "What semantic relationship am I trying to capture?"

- Synonymy/equivalence → Cosine similarity ✅
- Topic similarity → Cosine similarity ✅
- Causal/intentional relationship → LLM reasoning or user declaration ✅
- Hierarchical relationship → Graph structure + explicit links ✅

### 2. Beware Asymmetric Comparisons

When comparing texts of vastly different lengths:
- Longer text will have distributed semantic content
- Shorter text will have focused semantic content
- Cosine similarity will be systematically lower
- **Solution**: Compare same variants (titleOnly-titleOnly or fullContext-fullContext)

### 3. Interpretability Over Automation

❌ **Authoritative**: "This goal has 32% alignment with Physical Health"
- User thinks: "That seems wrong!" (loses trust)

✅ **Interpretable**: "Semantic overlap: 32%. Your declaration: Strong (8/10). **Composite: Strong alignment**"
- User understands reasoning (maintains trust)

### 4. User Agency in Subjective Domains

**Alignment is ultimately a subjective judgment** the user makes based on their personal philosophy.

The system should:
- Provide suggestions (semantic search, LLM insights)
- Show evidence (contribution history, related goals)
- **Respect user overrides** (learn from corrections)

NOT:
- Dictate alignment scores with false precision
- Hide reasoning behind opaque metrics
- Ignore user corrections

---

## Database Considerations

### Current State (Preserved)

**Table**: `semanticEmbeddings`
```sql
CREATE TABLE semanticEmbeddings (
    id TEXT PRIMARY KEY,
    entityType TEXT NOT NULL,
    entityId TEXT NOT NULL,
    sourceVariant TEXT NOT NULL,  -- 'title_only' or 'full_context'
    textHash TEXT NOT NULL,       -- SHA256 for cache invalidation
    sourceText TEXT NOT NULL,
    embedding BLOB NOT NULL,      -- 512-dim Float32 array (2048 bytes)
    dimensionality INTEGER NOT NULL,
    generatedAt TEXT NOT NULL
);
```

**Current usage** (2025-11-20):
- 516 goal embeddings (titleOnly) - **43x cache bloat from edits**
- 12 goal embeddings (fullContext)
- 387 value embeddings (fullContext) - **43x cache bloat**
- 9 value embeddings (titleOnly)
- 400 action embeddings (both variants)

**Cache bloat**: Orphaned embeddings from text edits accumulate (no purge mechanism yet)

### Recommended Maintenance

**Add periodic cache purge**:
```swift
// Remove embeddings for deleted entities
DELETE FROM semanticEmbeddings
WHERE entityType = 'goal'
  AND entityId NOT IN (SELECT id FROM goals);

// Remove orphaned embeddings (newer version exists)
DELETE FROM semanticEmbeddings se1
WHERE EXISTS (
    SELECT 1 FROM semanticEmbeddings se2
    WHERE se2.entityId = se1.entityId
      AND se2.entityType = se1.entityType
      AND se2.sourceVariant = se1.sourceVariant
      AND se2.generatedAt > se1.generatedAt
);
```

---

## References

### Removed Code Locations
- Commit: TBD (2025-11-20)
- Branch: main
- Related issue: Value alignment scores misleadingly low

### Related Documentation
- `swift/docs/VALUE_ALIGNMENT_REDESIGN.md` - Original design (now deprecated)
- `swift/docs/LIQUID_GLASS_VISUAL_SYSTEM.md` - UI design principles
- `/Users/davidwilliams/Coding/REFERENCE/documents/appleDeveloper/foundationmodels/` - LLM APIs for future implementation

### Key Insight Attribution

**User observation** (2025-11-20): "I'm surprised to see my scores so low"

**Root cause discovery**: Variant mismatch (titleOnly vs fullContext) creates 36x text length disparity

**Architectural decision**: "Embeddings are useful but not for checking value alignment"

---

## Conclusion

Semantic embeddings are powerful infrastructure for duplicate detection, search, and LLM RAG. However, automated goal-value alignment requires capturing **intentional and causal relationships**, not just **distributional similarity**.

Future alignment features should combine:
1. **User declarations** (captures true intent)
2. **LLM reasoning** (analyzes entailment relationships)
3. **Semantic similarity** (suggests candidates only, not scores)

**Core principle**: Build **interpretable tools** that augment user judgment, not **opaque automation** that replaces it.
