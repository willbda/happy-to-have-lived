#!/usr/bin/env python3
"""
Analyze Value Alignment Scores
Written by Claude Code on 2025-11-20

PURPOSE: Extract embeddings from production database and compute actual similarity scores
         to understand why alignment scores are lower than expected.
"""

import sqlite3
import struct
import math
from typing import List, Tuple, Dict

DB_PATH = '/Users/davidwilliams/Library/Containers/9CA210C7-734C-4D95-A193-A52963B93094/Data/Library/Application Support/GoalTracker/application_data.db'

def deserialize_embedding(blob: bytes) -> List[float]:
    """Deserialize Float32 array from database BLOB"""
    # Each float is 4 bytes, so we should have dimensionality = len(blob) / 4
    num_floats = len(blob) // 4
    # Little-endian float32 format: '<' + 'f' * count
    format_string = f'<{num_floats}f'
    return list(struct.unpack(format_string, blob))

def cosine_similarity(a: List[float], b: List[float]) -> float:
    """Compute cosine similarity between two vectors"""
    if len(a) != len(b):
        return 0.0

    dot_product = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(x * x for x in b))

    if norm_a == 0 or norm_b == 0:
        return 0.0

    return dot_product / (norm_a * norm_b)

def get_alignment_level(score: float) -> str:
    """Classify similarity score into alignment level"""
    if score >= 0.90:
        return "Very Strong (90%+)"
    elif score >= 0.75:
        return "Strong (75-89%)"
    elif score >= 0.60:
        return "Moderate (60-74%)"
    else:
        return "Weak (<60%)"

def main():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    print("=" * 80)
    print("VALUE ALIGNMENT SCORE ANALYSIS")
    print("=" * 80)
    print()

    # Get goals with their embeddings (titleOnly variant)
    print("Loading goal embeddings (titleOnly variant)...")
    cursor.execute("""
        SELECT
            g.id,
            e.title,
            se.sourceText,
            se.embedding,
            se.dimensionality
        FROM goals g
        JOIN expectations e ON g.expectationId = e.id
        LEFT JOIN semanticEmbeddings se ON se.entityId = g.id
            AND se.entityType = 'goal'
            AND se.sourceVariant = 'title_only'
        WHERE se.embedding IS NOT NULL
        ORDER BY e.title
    """)

    goals = []
    for row in cursor.fetchall():
        goal_id, title, source_text, embedding_blob, dimensionality = row
        embedding = deserialize_embedding(embedding_blob)
        goals.append({
            'id': goal_id,
            'title': title,
            'source_text': source_text,
            'embedding': embedding,
            'dimensionality': dimensionality
        })

    print(f"✓ Loaded {len(goals)} goals")
    print()

    # Get values with their embeddings (fullContext variant)
    print("Loading value embeddings (fullContext variant)...")
    cursor.execute("""
        SELECT
            pv.id,
            pv.title,
            se.sourceText,
            se.embedding,
            se.dimensionality
        FROM personalValues pv
        LEFT JOIN semanticEmbeddings se ON se.entityId = pv.id
            AND se.entityType = 'value'
            AND se.sourceVariant = 'full_context'
        WHERE se.embedding IS NOT NULL
        ORDER BY pv.priority DESC
    """)

    values = []
    for row in cursor.fetchall():
        value_id, title, source_text, embedding_blob, dimensionality = row
        embedding = deserialize_embedding(embedding_blob)
        values.append({
            'id': value_id,
            'title': title,
            'source_text': source_text,
            'embedding': embedding,
            'dimensionality': dimensionality
        })

    print(f"✓ Loaded {len(values)} values")
    print()

    # Compute alignment matrix
    print("=" * 80)
    print("ALIGNMENT MATRIX")
    print("=" * 80)
    print()

    all_scores = []

    for goal in goals:
        print(f"\n{'─' * 80}")
        print(f"GOAL: {goal['title']}")
        print(f"Source: \"{goal['source_text']}\"")
        print(f"Embedding: {goal['dimensionality']}-dimensional vector")
        print(f"{'─' * 80}")

        goal_scores = []

        for value in values:
            score = cosine_similarity(goal['embedding'], value['embedding'])
            level = get_alignment_level(score)
            goal_scores.append((value['title'], score, level))
            all_scores.append(score)

        # Sort by score descending
        goal_scores.sort(key=lambda x: x[1], reverse=True)

        # Show all alignments
        for value_title, score, level in goal_scores:
            # Color code by level
            if score >= 0.75:
                marker = "🟢"
            elif score >= 0.60:
                marker = "🟡"
            else:
                marker = "🔴"

            print(f"  {marker} {score:.4f} [{level:20s}] {value_title}")

    # Statistics
    print("\n" + "=" * 80)
    print("STATISTICAL SUMMARY")
    print("=" * 80)
    print()

    avg_score = sum(all_scores) / len(all_scores)
    min_score = min(all_scores)
    max_score = max(all_scores)

    very_strong = sum(1 for s in all_scores if s >= 0.90)
    strong = sum(1 for s in all_scores if 0.75 <= s < 0.90)
    moderate = sum(1 for s in all_scores if 0.60 <= s < 0.75)
    weak = sum(1 for s in all_scores if s < 0.60)

    print(f"Total comparisons: {len(all_scores)} ({len(goals)} goals × {len(values)} values)")
    print(f"Average score: {avg_score:.4f}")
    print(f"Min score: {min_score:.4f}")
    print(f"Max score: {max_score:.4f}")
    print()
    print("Distribution by level:")
    print(f"  🟢 Very Strong (≥0.90): {very_strong:3d} ({very_strong/len(all_scores)*100:5.1f}%)")
    print(f"  🟢 Strong (≥0.75):      {strong:3d} ({strong/len(all_scores)*100:5.1f}%)")
    print(f"  🟡 Moderate (≥0.60):    {moderate:3d} ({moderate/len(all_scores)*100:5.1f}%)")
    print(f"  🔴 Weak (<0.60):        {weak:3d} ({weak/len(all_scores)*100:5.1f}%)")
    print()

    # Top 5 highest scores
    print("=" * 80)
    print("TOP 5 HIGHEST ALIGNMENT SCORES")
    print("=" * 80)
    print()

    top_pairs = []
    for goal in goals:
        for value in values:
            score = cosine_similarity(goal['embedding'], value['embedding'])
            top_pairs.append((goal, value, score))

    top_pairs.sort(key=lambda x: x[2], reverse=True)

    for i, (goal, value, score) in enumerate(top_pairs[:5], 1):
        level = get_alignment_level(score)
        print(f"{i}. Score: {score:.4f} [{level}]")
        print(f"   Goal: {goal['title']}")
        print(f"   Goal source: \"{goal['source_text']}\"")
        print(f"   Value: {value['title']}")
        print(f"   Value source (first 150 chars): \"{value['source_text'][:150]}...\"")
        print()

    # Bottom 5 scores
    print("=" * 80)
    print("TOP 5 LOWEST ALIGNMENT SCORES")
    print("=" * 80)
    print()

    for i, (goal, value, score) in enumerate(top_pairs[-5:], 1):
        level = get_alignment_level(score)
        print(f"{i}. Score: {score:.4f} [{level}]")
        print(f"   Goal: {goal['title']}")
        print(f"   Goal source: \"{goal['source_text']}\"")
        print(f"   Value: {value['title']}")
        print(f"   Value source (first 150 chars): \"{value['source_text'][:150]}...\"")
        print()

    # Sample embedding inspection
    print("=" * 80)
    print("EMBEDDING SANITY CHECKS")
    print("=" * 80)
    print()

    # Check for zero vectors
    zero_goals = [g for g in goals if all(x == 0.0 for x in g['embedding'])]
    zero_values = [v for v in values if all(x == 0.0 for x in v['embedding'])]

    print(f"Goals with zero embeddings: {len(zero_goals)}")
    print(f"Values with zero embeddings: {len(zero_values)}")
    print()

    # Sample first 10 values from first goal embedding
    if goals:
        sample = goals[0]
        print(f"Sample embedding (first 10 values from '{sample['title']}'):")
        print(f"  {sample['embedding'][:10]}")
        print()

    # Text length comparison
    print("=" * 80)
    print("TEXT LENGTH ANALYSIS (Root Cause of Low Scores)")
    print("=" * 80)
    print()

    goal_lengths = [len(g['source_text'].split()) for g in goals]
    value_lengths = [len(v['source_text'].split()) for v in values]

    print(f"Goal source text (titleOnly variant):")
    print(f"  Average length: {sum(goal_lengths)/len(goal_lengths):.1f} words")
    print(f"  Min: {min(goal_lengths)} words")
    print(f"  Max: {max(goal_lengths)} words")
    print()

    print(f"Value source text (fullContext variant):")
    print(f"  Average length: {sum(value_lengths)/len(value_lengths):.1f} words")
    print(f"  Min: {min(value_lengths)} words")
    print(f"  Max: {max(value_lengths)} words")
    print()

    ratio = (sum(value_lengths)/len(value_lengths)) / (sum(goal_lengths)/len(goal_lengths))
    print(f"📊 VALUE TEXT IS {ratio:.1f}x LONGER THAN GOAL TEXT")
    print()
    print("INTERPRETATION:")
    print("  When comparing a short, focused concept (goal title) to a long,")
    print("  multi-faceted description (value full context), cosine similarity")
    print("  will be systematically lower because:")
    print()
    print("  1. Goal embedding: Dense representation of ONE concept")
    print("     Example: 'yoga, mobility, and strength' → fitness/flexibility")
    print()
    print("  2. Value embedding: Distributed across MANY concepts")
    print("     Example: 'health + longevity + maintenance + cardiovascular")
    print("              + strength + pain avoidance + deterioration...'")
    print()
    print("  3. Even if goal strongly aligns with ONE aspect of the value,")
    print("     that aspect is diluted among many others in the value embedding.")
    print()
    print("  4. Result: Genuinely aligned pairs score 0.40-0.60 instead of 0.75+")
    print()

    conn.close()

if __name__ == '__main__':
    main()
