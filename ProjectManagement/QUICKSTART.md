# Architecture Documentation - Quick Start Guide

**Written by Claude Code on 2025-11-19**

## Installation (One-Time Setup)

```bash
cd /Users/davidwilliams/Coding/01_ACTIVE_PROJECTS/ten_week_goal_app/ProjectManagement

# Initialize database from existing CSV
./update_architecture_docs.py --init
```

**Output**: Creates `architecture.db` with 166 files imported

## Daily Usage

### Update Everything

```bash
./update_architecture_docs.py
```

**What it does**:
- ✅ Scans all 166 Swift files
- ✅ Detects changes (created/modified/deleted)
- ✅ Checks for architectural violations
- ✅ Generates `ARCHITECTURE_SUMMARY_LATEST.md`
- ⏱️  Takes ~30 seconds

### Export to CSV

```bash
./update_architecture_docs.py --export-csv
```

**Output**: `ARCHITECTURE_MAP_LATEST.csv` (for Excel/Numbers)

## Query Examples

### Check Violations

```bash
sqlite3 architecture.db << 'EOF'
.mode markdown
SELECT file_path, violation_type, severity, description
FROM open_violations
ORDER BY CASE severity
    WHEN 'critical' THEN 1
    WHEN 'high' THEN 2
    WHEN 'medium' THEN 3
    ELSE 4
END;
EOF
```

### Find Complex Files

```bash
sqlite3 architecture.db << 'EOF'
.mode column
.headers on
SELECT file_path, line_count, complexity
FROM active_files
WHERE complexity = 'Complex'
ORDER BY line_count DESC;
EOF
```

### Files by Layer

```bash
sqlite3 architecture.db "SELECT * FROM files_by_layer;"
```

### Recent Changes

```bash
sqlite3 architecture.db << 'EOF'
.mode list
.separator " | "
SELECT change_type, file_path, changed_at
FROM recent_changes
ORDER BY changed_at DESC
LIMIT 10;
EOF
```

### Track Specific File History

```bash
sqlite3 architecture.db << 'EOF'
.mode column
SELECT change_type, changed_at, previous_values, new_values
FROM file_history
WHERE file_path LIKE '%GoalRepository%'
ORDER BY changed_at DESC;
EOF
```

## Common Workflows

### Before Code Review

```bash
# 1. Update architecture docs
./update_architecture_docs.py

# 2. Check violations
sqlite3 architecture.db "SELECT * FROM open_violations;"

# 3. Export latest CSV for sharing
./update_architecture_docs.py --export-csv
```

### After Refactoring

```bash
# 1. Scan changes
./update_architecture_docs.py --scan

# 2. See what changed
sqlite3 architecture.db << 'EOF'
SELECT fh.change_type, f.file_path, fh.changed_at
FROM file_history fh
JOIN files f ON fh.file_id = f.id
WHERE fh.scan_run_id = (SELECT MAX(id) FROM scan_runs)
ORDER BY fh.changed_at DESC;
EOF
```

### Weekly Review

```bash
# Generate fresh report
./update_architecture_docs.py --report

# View summary
cat ARCHITECTURE_SUMMARY_LATEST.md
```

## Files Generated

| File | Description | When Updated |
|------|-------------|--------------|
| `architecture.db` | SQLite database | Every scan |
| `ARCHITECTURE_MAP_LATEST.csv` | Current architecture map | On --export-csv |
| `ARCHITECTURE_SUMMARY_LATEST.md` | Summary report | Every scan or --report |

## Violation Types

| Type | Severity | Description |
|------|----------|-------------|
| `missing_baserepository` | HIGH | Repository not extending BaseRepository |
| `missing_sendable` | MEDIUM | Coordinator/Service not marked Sendable |
| `missing_mainactor` | HIGH | ViewModel missing @MainActor |
| `raw_sql_without_typed_row` | MEDIUM | Using Row instead of typed struct |

## Database Views

Pre-built views for common queries:

```bash
# Active files (not deleted)
sqlite3 architecture.db "SELECT * FROM active_files LIMIT 10;"

# Recent changes (last 7 days)
sqlite3 architecture.db "SELECT * FROM recent_changes;"

# Files by complexity
sqlite3 architecture.db "SELECT * FROM files_by_complexity;"

# Files by layer
sqlite3 architecture.db "SELECT * FROM files_by_layer;"

# Files by domain
sqlite3 architecture.db "SELECT * FROM files_by_domain;"

# Open violations
sqlite3 architecture.db "SELECT * FROM open_violations;"

# Scan summary (all runs)
sqlite3 architecture.db "SELECT * FROM scan_summary;"
```

## Tips

### Pretty Output

```bash
# Markdown tables
sqlite3 -markdown architecture.db "SELECT * FROM files_by_layer;"

# CSV export
sqlite3 -csv architecture.db "SELECT * FROM active_files;" > export.csv

# Column-aligned
sqlite3 architecture.db << 'EOF'
.mode column
.headers on
SELECT * FROM files_by_complexity;
EOF
```

### Performance

- First scan: ~30 seconds (reads all files)
- Subsequent scans: ~5-10 seconds (only checks changed files)
- Database size: ~500KB for 166 files

### Automation

Add to crontab:

```bash
# Daily at 9am
0 9 * * * cd /Users/davidwilliams/Coding/01_ACTIVE_PROJECTS/ten_week_goal_app/ProjectManagement && ./update_architecture_docs.py
```

## Troubleshooting

### Database Locked

```bash
# Check who's using it
lsof architecture.db

# Force unlock
rm -f architecture.db-shm architecture.db-wal
```

### Reset Everything

```bash
rm architecture.db
./update_architecture_docs.py --init
```

### Check Script Version

```bash
grep "SCRIPT_VERSION" update_architecture_docs.py
# Should show: SCRIPT_VERSION = "1.0.0"
```

## Next Steps

1. **Read**: `README.md` - Full documentation
2. **Review**: `ARCHITECTURE_SUMMARY.md` - Comprehensive architecture guide
3. **Navigate**: `ARCHITECTURE_INDEX.md` - Navigation and search strategies
4. **Schema**: `schema.sql` - Database structure with comments

## Questions?

- Check `README.md` for detailed documentation
- Examine `schema.sql` for database structure
- Review `update_architecture_docs.py` source code
- Query database for examples

---

**Version**: 1.0.0
**Last Updated**: 2025-11-19
