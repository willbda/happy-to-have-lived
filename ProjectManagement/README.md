# Architecture Documentation Automation

**Written by Claude Code on 2025-11-19**

## Overview

This system automatically scans the Swift codebase, tracks architectural patterns, detects changes over time, and maintains up-to-date documentation with violation detection.

## Files

```
ProjectManagement/
├── README.md                          # This file
├── schema.sql                         # SQLite database schema
├── update_architecture_docs.py        # Main automation script
├── architecture.db                    # SQLite database (generated)
│
├── ARCHITECTURE_MAP_COMPLETE.csv      # Initial baseline (from manual scan)
├── ARCHITECTURE_MAP_LATEST.csv        # Auto-generated current state
├── ARCHITECTURE_SUMMARY.md            # Comprehensive documentation
├── ARCHITECTURE_SUMMARY_LATEST.md     # Auto-generated summary
└── ARCHITECTURE_INDEX.md              # Navigation guide
```

## Quick Start

### 1. Initialize Database

First time setup (imports existing CSV):

```bash
cd ProjectManagement
./update_architecture_docs.py --init
```

This creates `architecture.db` and imports data from `ARCHITECTURE_MAP_COMPLETE.csv`.

### 2. Run Full Scan

Scan all Swift files, detect changes, check violations, and generate reports:

```bash
./update_architecture_docs.py
```

**Output:**
- Updates `architecture.db` with current file state
- Detects created/modified/deleted files
- Checks for architectural violations
- Generates `ARCHITECTURE_SUMMARY_LATEST.md`

### 3. Export Updated CSV

Export current architecture map to CSV:

```bash
./update_architecture_docs.py --export-csv
```

Generates `ARCHITECTURE_MAP_LATEST.csv` with current state.

## Usage Modes

### Full Automation (Default)

```bash
./update_architecture_docs.py
```

Runs: scan + violation check + report generation

### Individual Operations

```bash
# Just scan files
./update_architecture_docs.py --scan

# Just check violations
./update_architecture_docs.py --check-violations

# Just generate reports
./update_architecture_docs.py --report

# Export to CSV
./update_architecture_docs.py --export-csv
```

### Re-initialize Database

```bash
rm architecture.db
./update_architecture_docs.py --init
```

## Database Schema

### Core Tables

**`files`** - Current state of all Swift files
- File metadata (path, size, line count, hash)
- Architecture data (layer, domain, pattern, complexity)
- Concurrency markers (Sendable, @MainActor)
- Change tracking (first_seen, last_scanned, is_deleted)

**`file_history`** - Historical changes
- Change type (created, modified, deleted, renamed)
- Previous/new values (JSON)
- Linked to scan runs

**`scan_runs`** - Scan execution metadata
- Git context (branch, commit, message)
- Statistics (files scanned/created/modified/deleted)
- Execution context (Python version, user, hostname)

**`scan_statistics`** - Aggregated metrics per scan
- File distribution (by layer, domain, complexity)
- Code metrics (total lines, average lines, largest file)
- Complex files list

**`violations`** - Architectural pattern violations
- Violation type (missing_baserepository, raw_sql, missing_sendable, etc.)
- Severity (low, medium, high, critical)
- Status (open, acknowledged, fixed, wontfix)
- Recommendations

**`patterns`** - Catalog of architectural patterns
- Pattern name and category
- Required traits
- Example files

**`dependencies`** - Inter-file dependencies
- Import relationships
- Inheritance chains
- Protocol conformances

### Views for Reporting

**`active_files`** - Non-deleted files
**`recent_changes`** - Changes in last 7 days
**`files_by_complexity`** - Complexity distribution
**`files_by_layer`** - Layer distribution
**`files_by_domain`** - Domain distribution
**`open_violations`** - Unresolved violations
**`scan_summary`** - Latest scan overview

## Querying the Database

### SQLite CLI

```bash
sqlite3 architecture.db

# Show all repositories
SELECT file_path, complexity, line_count
FROM active_files
WHERE layer = 'Repository'
ORDER BY complexity DESC;

# Find violations
SELECT * FROM open_violations;

# Track file history
SELECT change_type, changed_at, previous_values, new_values
FROM file_history
WHERE file_path LIKE '%GoalRepository%'
ORDER BY changed_at DESC;

# Complexity trend over time
SELECT
    DATE(started_at) as date,
    json_extract(files_by_complexity, '$.Simple') as simple,
    json_extract(files_by_complexity, '$.Medium') as medium,
    json_extract(files_by_complexity, '$.Complex') as complex
FROM scan_runs sr
JOIN scan_statistics ss ON sr.id = ss.scan_run_id
ORDER BY date;
```

### Python Queries

```python
import sqlite3

conn = sqlite3.connect('architecture.db')
conn.row_factory = sqlite3.Row

# Find all ViewModels missing @MainActor
cursor = conn.execute("""
    SELECT file_path, concurrency
    FROM active_files
    WHERE layer LIKE 'ViewModel%'
    AND concurrency NOT LIKE '%@MainActor%'
""")

for row in cursor:
    print(f"{row['file_path']}: {row['concurrency']}")
```

## Violation Detection

### Automatic Checks

The system automatically detects these violations:

1. **`missing_baserepository`** (HIGH)
   - Repository files not extending BaseRepository
   - Excludes Core/ infrastructure files

2. **`missing_sendable`** (MEDIUM)
   - Coordinators/Repositories/Services not marked Sendable
   - Required for Swift 6 concurrency safety

3. **`missing_mainactor`** (HIGH)
   - ViewModels without @MainActor annotation
   - UI updates must be on main thread

4. **`raw_sql_without_typed_row`** (MEDIUM)
   - SQL queries using raw Row instead of typed structs
   - Bypasses type safety

### Viewing Violations

```bash
sqlite3 architecture.db "SELECT * FROM open_violations;"
```

Or in generated report: `ARCHITECTURE_SUMMARY_LATEST.md`

## Change Detection

### How It Works

1. **File Hashing**: SHA256 of file contents
2. **Comparison**: New hash vs. stored hash
3. **History Tracking**: Previous/new values stored in JSON
4. **Scan Runs**: Each scan creates timestamped record

### Change Types

- **`created`**: New file added
- **`modified`**: Hash changed (content modified)
- **`deleted`**: File no longer exists
- **`renamed`**: Path changed (detected manually)
- **`metadata_changed`**: Architecture data updated

### Viewing Changes

```bash
# Recent changes (last 7 days)
sqlite3 architecture.db "SELECT * FROM recent_changes;"

# Changes in last scan
sqlite3 architecture.db "
SELECT fh.*, f.file_path
FROM file_history fh
JOIN files f ON fh.file_id = f.id
WHERE fh.scan_run_id = (SELECT MAX(id) FROM scan_runs)
ORDER BY fh.changed_at DESC;
"
```

## Statistics & Analytics

### Codebase Metrics

```bash
# Current statistics
sqlite3 architecture.db "SELECT * FROM scan_summary ORDER BY started_at DESC LIMIT 1;"

# Complexity distribution
sqlite3 architecture.db "SELECT * FROM files_by_complexity;"

# Layer distribution
sqlite3 architecture.db "SELECT * FROM files_by_layer;"

# Domain distribution
sqlite3 architecture.db "SELECT * FROM files_by_domain;"
```

### Trend Analysis

```sql
-- File count over time
SELECT
    DATE(started_at) as date,
    files_scanned,
    files_created,
    files_modified,
    files_deleted
FROM scan_runs
ORDER BY started_at;

-- Code growth
SELECT
    DATE(sr.started_at) as date,
    ss.total_files,
    ss.total_lines,
    ss.complex_files_count
FROM scan_runs sr
JOIN scan_statistics ss ON sr.id = ss.scan_run_id
ORDER BY sr.started_at;
```

## Integration with Git

### Pre-Commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash

# Update architecture documentation before commit
cd ProjectManagement
./update_architecture_docs.py --scan --check-violations

# Check for critical violations
VIOLATIONS=$(sqlite3 architecture.db "SELECT COUNT(*) FROM violations WHERE status = 'open' AND severity = 'critical';")

if [ "$VIOLATIONS" -gt 0 ]; then
    echo "❌ Found $VIOLATIONS critical architectural violations"
    echo "Run: cd ProjectManagement && sqlite3 architecture.db 'SELECT * FROM open_violations;'"
    exit 1
fi

exit 0
```

### GitHub Actions Workflow

Add to `.github/workflows/architecture-check.yml`:

```yaml
name: Architecture Documentation

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'

      - name: Update architecture docs
        run: |
          cd ProjectManagement
          ./update_architecture_docs.py --scan --check-violations

      - name: Check for violations
        run: |
          cd ProjectManagement
          VIOLATIONS=$(sqlite3 architecture.db "SELECT COUNT(*) FROM open_violations WHERE severity IN ('critical', 'high');")
          echo "Found $VIOLATIONS high-severity violations"

          if [ "$VIOLATIONS" -gt 0 ]; then
            echo "## Architectural Violations" >> $GITHUB_STEP_SUMMARY
            sqlite3 -markdown architecture.db "SELECT severity, violation_type, file_path, description FROM open_violations WHERE severity IN ('critical', 'high');" >> $GITHUB_STEP_SUMMARY
            exit 1
          fi

      - name: Upload architecture database
        uses: actions/upload-artifact@v3
        with:
          name: architecture-db
          path: ProjectManagement/architecture.db
```

## Automation Schedule

### Recommended Schedule

**Daily** (via cron):
```bash
0 9 * * * cd /path/to/project/ProjectManagement && ./update_architecture_docs.py
```

**Weekly** (Sunday):
```bash
0 0 * * 0 cd /path/to/project/ProjectManagement && ./update_architecture_docs.py --export-csv
```

**On-Demand**:
- Before major refactoring
- After completing features
- Before code reviews
- Before releases

## Maintenance

### Database Cleanup

```bash
# Remove old history (keep last 30 days)
sqlite3 architecture.db "DELETE FROM file_history WHERE changed_at < datetime('now', '-30 days');"

# Vacuum database
sqlite3 architecture.db "VACUUM;"
```

### Backup

```bash
# Backup database
cp architecture.db architecture.db.backup.$(date +%Y%m%d)

# Restore from backup
cp architecture.db.backup.20250119 architecture.db
```

### Reset

```bash
# Complete reset
rm architecture.db
./update_architecture_docs.py --init
```

## Extending the System

### Add New Violation Checks

Edit `update_architecture_docs.py`, add method to `ViolationDetector`:

```python
def _check_custom_pattern(self) -> List[Dict]:
    """Check for custom architectural pattern"""
    cursor = self.db.conn.execute("""
        SELECT * FROM files
        WHERE layer = 'MyLayer'
        AND /* custom condition */
    """)

    violations = []
    for row in cursor.fetchall():
        violations.append({
            'file_id': row['id'],
            'violation_type': 'custom_pattern_violation',
            'severity': 'medium',
            'description': f"File {row['file_path']} violates custom pattern",
            'recommendation': "Follow the canonical pattern..."
        })

    return violations
```

Then call in `check_all_violations()`:

```python
violations.extend(self._check_custom_pattern())
```

### Add New Metrics

Edit `update_architecture_docs.py`, extend `SwiftFileScanner.analyze_file()`:

```python
def analyze_file(self, file_path: Path) -> Dict:
    # ... existing code ...

    # Add custom metric
    custom_metric = self._extract_custom_metric(content)

    return {
        # ... existing fields ...
        'custom_metric': custom_metric
    }
```

Update `schema.sql` to add column:

```sql
ALTER TABLE files ADD COLUMN custom_metric TEXT;
```

## Troubleshooting

### Database Locked

```bash
# Close any open connections
lsof architecture.db

# Kill processes
kill <PID>
```

### Inconsistent Data

```bash
# Re-scan from scratch
rm architecture.db
./update_architecture_docs.py --init
./update_architecture_docs.py --scan
```

### Missing Files

```bash
# Check for deleted files
sqlite3 architecture.db "SELECT file_path FROM files WHERE is_deleted = 1;"

# Restore deleted file tracking
sqlite3 architecture.db "UPDATE files SET is_deleted = 0 WHERE file_path = 'path/to/file.swift';"
```

## Resources

- **Schema Documentation**: `schema.sql` (comprehensive comments)
- **Script Source**: `update_architecture_docs.py` (well-documented)
- **Project CLAUDE.md**: Canonical architectural patterns
- **Swift Language Guide**: `/Users/davidwilliams/Coding/REFERENCE/documents/SwiftLanguage/`

## Support

For questions or issues:
1. Check this README
2. Review `schema.sql` comments
3. Examine script source code
4. Query database for examples
5. Consult `ARCHITECTURE_SUMMARY.md`

---

**Last Updated**: 2025-11-19
**Version**: 1.0.0
**Maintainer**: David Williams
