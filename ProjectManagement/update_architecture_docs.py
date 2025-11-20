#!/usr/bin/env python3
"""
Architecture Documentation Automation
Written by Claude Code on 2025-11-19

PURPOSE: Scan Swift codebase, detect changes, and maintain architecture documentation
USAGE:
    ./update_architecture_docs.py                    # Full scan and update
    ./update_architecture_docs.py --init             # Initialize database from CSV
    ./update_architecture_docs.py --report           # Generate reports only
    ./update_architecture_docs.py --check-violations # Check for pattern violations
"""

import argparse
import csv
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_VERSION = "1.0.0"
PROJECT_ROOT = Path(__file__).parent.parent
SWIFT_SOURCES = PROJECT_ROOT / "swift" / "Sources"
DB_PATH = PROJECT_ROOT / "ProjectManagement" / "architecture.db"
CSV_PATH = PROJECT_ROOT / "ProjectManagement" / "ARCHITECTURE_MAP_COMPLETE.csv"
SCHEMA_PATH = PROJECT_ROOT / "ProjectManagement" / "schema.sql"

# File size thresholds for complexity
SIMPLE_THRESHOLD = 150  # lines
MEDIUM_THRESHOLD = 400  # lines

# =============================================================================
# DATABASE
# =============================================================================

class ArchitectureDB:
    """SQLite database wrapper for architecture tracking"""

    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.conn: Optional[sqlite3.Connection] = None

    def __enter__(self):
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.conn:
            self.conn.close()

    def initialize_schema(self, schema_path: Path):
        """Initialize database from schema.sql"""
        with open(schema_path, 'r') as f:
            schema = f.read()

        self.conn.executescript(schema)
        self.conn.commit()
        print(f"✅ Initialized database schema from {schema_path}")

    def start_scan_run(self) -> int:
        """Create new scan run and return its ID"""
        git_info = self._get_git_info()

        cursor = self.conn.execute("""
            INSERT INTO scan_runs (
                started_at, git_branch, git_commit_hash, git_commit_message,
                python_version, script_version, user, hostname
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            datetime.now().isoformat(),
            git_info['branch'],
            git_info['commit_hash'],
            git_info['commit_message'],
            sys.version.split()[0],
            SCRIPT_VERSION,
            os.getenv('USER', 'unknown'),
            os.uname().nodename
        ))
        self.conn.commit()
        return cursor.lastrowid

    def complete_scan_run(self, run_id: int, stats: Dict):
        """Update scan run with completion data"""
        duration = (datetime.now() - datetime.fromisoformat(
            self.conn.execute("SELECT started_at FROM scan_runs WHERE id = ?", (run_id,)).fetchone()[0]
        )).total_seconds()

        self.conn.execute("""
            UPDATE scan_runs SET
                completed_at = ?,
                duration_seconds = ?,
                files_scanned = ?,
                files_created = ?,
                files_modified = ?,
                files_deleted = ?,
                errors_encountered = ?
            WHERE id = ?
        """, (
            datetime.now().isoformat(),
            duration,
            stats.get('scanned', 0),
            stats.get('created', 0),
            stats.get('modified', 0),
            stats.get('deleted', 0),
            stats.get('errors', 0),
            run_id
        ))
        self.conn.commit()

    def get_file_by_path(self, file_path: str) -> Optional[sqlite3.Row]:
        """Retrieve file record by path"""
        cursor = self.conn.execute("SELECT * FROM files WHERE file_path = ?", (file_path,))
        return cursor.fetchone()

    def upsert_file(self, file_data: Dict, scan_run_id: int) -> Tuple[int, str]:
        """
        Insert or update file record.
        Returns (file_id, change_type) where change_type is 'created', 'modified', or 'unchanged'
        """
        existing = self.get_file_by_path(file_data['file_path'])

        if existing is None:
            # New file
            cursor = self.conn.execute("""
                INSERT INTO files (
                    file_path, layer, domain_entity, file_purpose, key_pattern,
                    dependencies, extends_conforms, concurrency, complexity, notes,
                    file_size_bytes, line_count, last_modified, file_hash,
                    first_seen, last_scanned
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                file_data['file_path'],
                file_data['layer'],
                file_data['domain_entity'],
                file_data.get('file_purpose'),
                file_data.get('key_pattern'),
                file_data.get('dependencies'),
                file_data.get('extends_conforms'),
                file_data.get('concurrency'),
                file_data.get('complexity'),
                file_data.get('notes'),
                file_data.get('file_size_bytes'),
                file_data.get('line_count'),
                file_data.get('last_modified'),
                file_data.get('file_hash'),
                datetime.now().isoformat(),
                datetime.now().isoformat()
            ))
            file_id = cursor.lastrowid

            # Record history
            self.conn.execute("""
                INSERT INTO file_history (
                    file_id, change_type, file_path, file_hash, line_count, scan_run_id
                ) VALUES (?, ?, ?, ?, ?, ?)
            """, (file_id, 'created', file_data['file_path'], file_data.get('file_hash'),
                  file_data.get('line_count'), scan_run_id))

            self.conn.commit()
            return file_id, 'created'

        else:
            # Existing file - check if modified
            file_id = existing['id']

            if existing['file_hash'] != file_data.get('file_hash'):
                # File modified - track changes
                previous = {
                    'layer': existing['layer'],
                    'domain_entity': existing['domain_entity'],
                    'complexity': existing['complexity'],
                    'line_count': existing['line_count']
                }
                new = {
                    'layer': file_data['layer'],
                    'domain_entity': file_data['domain_entity'],
                    'complexity': file_data.get('complexity'),
                    'line_count': file_data.get('line_count')
                }

                self.conn.execute("""
                    UPDATE files SET
                        layer = ?, domain_entity = ?, file_purpose = ?, key_pattern = ?,
                        dependencies = ?, extends_conforms = ?, concurrency = ?, complexity = ?,
                        notes = ?, file_size_bytes = ?, line_count = ?, last_modified = ?,
                        file_hash = ?, last_scanned = ?
                    WHERE id = ?
                """, (
                    file_data['layer'],
                    file_data['domain_entity'],
                    file_data.get('file_purpose'),
                    file_data.get('key_pattern'),
                    file_data.get('dependencies'),
                    file_data.get('extends_conforms'),
                    file_data.get('concurrency'),
                    file_data.get('complexity'),
                    file_data.get('notes'),
                    file_data.get('file_size_bytes'),
                    file_data.get('line_count'),
                    file_data.get('last_modified'),
                    file_data.get('file_hash'),
                    datetime.now().isoformat(),
                    file_id
                ))

                # Record history
                self.conn.execute("""
                    INSERT INTO file_history (
                        file_id, change_type, file_path, file_hash, line_count,
                        previous_values, new_values, scan_run_id
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    file_id, 'modified', file_data['file_path'], file_data.get('file_hash'),
                    file_data.get('line_count'), json.dumps(previous), json.dumps(new), scan_run_id
                ))

                self.conn.commit()
                return file_id, 'modified'
            else:
                # No changes
                self.conn.execute(
                    "UPDATE files SET last_scanned = ? WHERE id = ?",
                    (datetime.now().isoformat(), file_id)
                )
                self.conn.commit()
                return file_id, 'unchanged'

    def mark_deleted_files(self, scanned_paths: List[str], scan_run_id: int):
        """Mark files as deleted if they weren't scanned"""
        placeholders = ','.join(['?'] * len(scanned_paths))
        cursor = self.conn.execute(f"""
            SELECT id, file_path FROM files
            WHERE file_path NOT IN ({placeholders})
            AND is_deleted = 0
        """, scanned_paths)

        deleted_files = cursor.fetchall()

        for file in deleted_files:
            self.conn.execute("""
                UPDATE files SET is_deleted = 1, deleted_at = ? WHERE id = ?
            """, (datetime.now().isoformat(), file['id']))

            self.conn.execute("""
                INSERT INTO file_history (
                    file_id, change_type, file_path, scan_run_id
                ) VALUES (?, ?, ?, ?)
            """, (file['id'], 'deleted', file['file_path'], scan_run_id))

        self.conn.commit()
        return len(deleted_files)

    def save_statistics(self, scan_run_id: int, stats: Dict):
        """Save aggregated statistics for scan run"""
        self.conn.execute("""
            INSERT INTO scan_statistics (
                scan_run_id, total_files, files_by_layer, files_by_domain,
                files_by_complexity, files_by_concurrency, total_lines,
                avg_lines_per_file, largest_file, largest_file_lines,
                complex_files_count, complex_files_list
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            scan_run_id,
            stats.get('total_files', 0),
            json.dumps(stats.get('files_by_layer', {})),
            json.dumps(stats.get('files_by_domain', {})),
            json.dumps(stats.get('files_by_complexity', {})),
            json.dumps(stats.get('files_by_concurrency', {})),
            stats.get('total_lines', 0),
            stats.get('avg_lines_per_file', 0.0),
            stats.get('largest_file', ''),
            stats.get('largest_file_lines', 0),
            stats.get('complex_files_count', 0),
            json.dumps(stats.get('complex_files_list', []))
        ))
        self.conn.commit()

    def _get_git_info(self) -> Dict[str, str]:
        """Get current git branch and commit info"""
        try:
            branch = subprocess.check_output(
                ['git', 'branch', '--show-current'],
                cwd=PROJECT_ROOT,
                stderr=subprocess.DEVNULL
            ).decode().strip()

            commit_hash = subprocess.check_output(
                ['git', 'rev-parse', 'HEAD'],
                cwd=PROJECT_ROOT,
                stderr=subprocess.DEVNULL
            ).decode().strip()[:8]

            commit_msg = subprocess.check_output(
                ['git', 'log', '-1', '--pretty=%B'],
                cwd=PROJECT_ROOT,
                stderr=subprocess.DEVNULL
            ).decode().strip()

            return {
                'branch': branch,
                'commit_hash': commit_hash,
                'commit_message': commit_msg
            }
        except:
            return {'branch': 'unknown', 'commit_hash': '', 'commit_message': ''}

# =============================================================================
# FILE SCANNER
# =============================================================================

class SwiftFileScanner:
    """Scans Swift source files and extracts architectural metadata"""

    def __init__(self, sources_dir: Path):
        self.sources_dir = sources_dir

    def scan_all_files(self) -> List[Dict]:
        """Scan all Swift files and return metadata"""
        swift_files = list(self.sources_dir.rglob("*.swift"))
        print(f"📁 Found {len(swift_files)} Swift files")

        results = []
        for file_path in swift_files:
            try:
                metadata = self.analyze_file(file_path)
                results.append(metadata)
            except Exception as e:
                print(f"❌ Error analyzing {file_path}: {e}")

        return results

    def analyze_file(self, file_path: Path) -> Dict:
        """Extract metadata from a single Swift file"""
        relative_path = file_path.relative_to(PROJECT_ROOT)

        # Read file
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Calculate hash
        file_hash = hashlib.sha256(content.encode()).hexdigest()

        # Count lines
        lines = content.split('\n')
        line_count = len([l for l in lines if l.strip()])  # Non-empty lines

        # Get file stats
        stat = file_path.stat()

        # Determine complexity
        if line_count < SIMPLE_THRESHOLD:
            complexity = 'Simple'
        elif line_count < MEDIUM_THRESHOLD:
            complexity = 'Medium'
        else:
            complexity = 'Complex'

        # Extract metadata from file
        purpose = self._extract_purpose(content)
        layer = self._determine_layer(relative_path, content)
        domain_entity = self._determine_domain_entity(relative_path, content)
        key_pattern = self._extract_key_pattern(content, layer)
        concurrency = self._detect_concurrency(content)
        extends_conforms = self._extract_inheritance(content)
        dependencies = self._extract_dependencies(content)

        return {
            'file_path': str(relative_path),
            'layer': layer,
            'domain_entity': domain_entity,
            'file_purpose': purpose,
            'key_pattern': key_pattern,
            'dependencies': dependencies,
            'extends_conforms': extends_conforms,
            'concurrency': concurrency,
            'complexity': complexity,
            'notes': '',
            'file_size_bytes': stat.st_size,
            'line_count': line_count,
            'last_modified': datetime.fromtimestamp(stat.st_mtime).isoformat(),
            'file_hash': file_hash
        }

    def _extract_purpose(self, content: str) -> Optional[str]:
        """Extract PURPOSE comment from file header"""
        match = re.search(r'// PURPOSE:\s*(.+)', content)
        if match:
            return match.group(1).strip()

        # Try alternate format
        match = re.search(r'/// (.+)', content)
        if match:
            return match.group(1).strip()

        return None

    def _determine_layer(self, relative_path: Path, content: str) -> str:
        """Determine architectural layer from path"""
        path_str = str(relative_path)

        # Models
        if 'Models/Abstractions' in path_str:
            return 'Model-Abstraction'
        elif 'Models/Basics' in path_str:
            return 'Model-Basic'
        elif 'Models/Composits' in path_str:
            return 'Model-Composit'
        elif 'Models/DataTypes' in path_str:
            return 'Model-DataType'
        elif 'Models/SemanticTypes' in path_str:
            return 'Model-Semantic'
        elif 'Models/Deduplication' in path_str:
            return 'Model-Deduplication'

        # Database
        elif 'Database' in path_str:
            return 'Database'

        # Services
        elif 'Repositories/Core' in path_str:
            return 'Repository-Core'
        elif 'Repositories' in path_str:
            return 'Repository'
        elif 'Coordinators/FormData' in path_str:
            return 'Coordinator-FormData'
        elif 'Coordinators' in path_str:
            return 'Coordinator'
        elif 'Services/Progress' in path_str:
            return 'Service-Progress'
        elif 'Services/Validation' in path_str:
            return 'Service-Validation'
        elif 'Services/Embedding' in path_str:
            return 'Service-Embedding'
        elif 'Services/Semantic' in path_str:
            return 'Service-Semantic'
        elif 'Services/Deduplication' in path_str:
            return 'Service-Deduplication'
        elif 'Services/HealthKit' in path_str:
            return 'Service-HealthKit'
        elif 'Services/FoundationModels' in path_str:
            return 'Service-FoundationModels'
        elif 'Services/ImportExport' in path_str:
            return 'Service-ImportExport'
        elif 'Services' in path_str:
            return 'Service-Other'

        # ViewModels
        elif 'ViewModels/FormViewModels' in path_str:
            return 'ViewModel-Form'
        elif 'ViewModels/ListViewModels' in path_str:
            return 'ViewModel-List'
        elif 'ViewModels/LLMViewModels' in path_str:
            return 'ViewModel-LLM'
        elif 'ViewModels' in path_str:
            return 'ViewModel-Utility'

        # Views
        elif 'Views/ListViews' in path_str:
            return 'View-List'
        elif 'Views/FormViews' in path_str:
            return 'View-Form'
        elif 'Views/RowViews' in path_str:
            return 'View-Row'
        elif 'Views/Components' in path_str:
            return 'View-Component'
        elif 'Views/Dashboard' in path_str:
            return 'View-Dashboard'
        elif 'Views/Debug' in path_str:
            return 'View-Debug'
        elif 'Views/Analytics' in path_str:
            return 'View-Analytics'
        elif 'Views/Health' in path_str:
            return 'View-Health'
        elif 'Views/LLM' in path_str:
            return 'View-LLM'
        elif 'Views/CSV' in path_str:
            return 'View-CSV'
        elif 'Views/Templates' in path_str:
            return 'View-Template'

        return 'Unknown'

    def _determine_domain_entity(self, relative_path: Path, content: str) -> str:
        """Determine domain entity from filename and content"""
        filename = relative_path.stem.lower()

        # Check for specific domain entities
        if 'goal' in filename:
            return 'Goal'
        elif 'action' in filename:
            return 'Action'
        elif 'personalvalue' in filename or 'value' in filename:
            return 'PersonalValue'
        elif 'measure' in filename:
            return 'Measure'
        elif 'timeperiod' in filename or 'term' in filename:
            return 'TimePeriod'
        elif 'milestone' in filename:
            return 'Milestone'
        elif 'obligation' in filename:
            return 'Obligation'
        elif 'expectation' in filename:
            return 'Expectation'
        elif 'embedding' in filename or 'semantic' in filename:
            return 'Semantic'
        elif 'health' in filename:
            return 'HealthKit'
        elif 'llm' in filename or 'coach' in filename or 'foundationmodels' in filename:
            return 'LLM'

        return 'Cross-cutting'

    def _extract_key_pattern(self, content: str, layer: str) -> Optional[str]:
        """Extract architectural pattern used"""
        # Repository pattern
        if 'BaseRepository' in content:
            match = re.search(r'BaseRepository<(\w+)>', content)
            if match:
                return f"BaseRepository<{match.group(1)}>"
            return "BaseRepository"

        # ViewModel pattern
        if '@Observable' in content:
            if '@MainActor' in content:
                return "@Observable @MainActor"
            return "@Observable"

        # Model pattern
        if '@Table' in content:
            return "@Table"

        # SwiftUI View
        if ': View' in content:
            return "SwiftUI View"

        # Coordinator
        if 'Coordinator' in content and ': Sendable' in content:
            return "Sendable Coordinator"

        return None

    def _detect_concurrency(self, content: str) -> str:
        """Detect concurrency markers"""
        has_sendable = ': Sendable' in content or '@unchecked Sendable' in content
        has_mainactor = '@MainActor' in content

        if has_sendable and has_mainactor:
            return 'Sendable + @MainActor'
        elif '@unchecked Sendable' in content:
            return '@unchecked Sendable'
        elif has_sendable:
            return 'Sendable'
        elif has_mainactor:
            return '@MainActor'
        else:
            return 'None'

    def _extract_inheritance(self, content: str) -> Optional[str]:
        """Extract class/struct inheritance and protocol conformance"""
        matches = []

        # Find class/struct declarations
        for match in re.finditer(r'(?:class|struct|enum)\s+\w+\s*:\s*([^{]+){', content):
            inheritance = match.group(1).strip()
            matches.append(inheritance)

        if matches:
            return ', '.join(matches)

        return None

    def _extract_dependencies(self, content: str) -> Optional[str]:
        """Extract import statements"""
        imports = []
        for match in re.finditer(r'^import\s+(\w+)', content, re.MULTILINE):
            module = match.group(1)
            if module not in ['Foundation', 'SwiftUI']:
                imports.append(module)

        if imports:
            return ', '.join(sorted(set(imports)))

        return None

# =============================================================================
# VIOLATION DETECTOR
# =============================================================================

class ViolationDetector:
    """Detects architectural pattern violations"""

    def __init__(self, db: ArchitectureDB):
        self.db = db

    def check_all_violations(self):
        """Run all violation checks"""
        violations = []

        violations.extend(self._check_repository_baserepository())
        violations.extend(self._check_raw_sql_patterns())
        violations.extend(self._check_missing_sendable())
        violations.extend(self._check_missing_mainactor())

        # Save violations to database
        for v in violations:
            self.db.conn.execute("""
                INSERT OR IGNORE INTO violations (
                    file_id, violation_type, severity, description, recommendation, status
                ) VALUES (?, ?, ?, ?, ?, ?)
            """, (
                v['file_id'],
                v['violation_type'],
                v['severity'],
                v['description'],
                v['recommendation'],
                'open'
            ))

        self.db.conn.commit()
        return violations

    def _check_repository_baserepository(self) -> List[Dict]:
        """Check if repositories extend BaseRepository"""
        cursor = self.db.conn.execute("""
            SELECT * FROM files
            WHERE layer = 'Repository'
            AND is_deleted = 0
            AND (extends_conforms IS NULL OR extends_conforms NOT LIKE '%BaseRepository%')
            AND file_path NOT LIKE '%/Core/%'
        """)

        violations = []
        for row in cursor.fetchall():
            violations.append({
                'file_id': row['id'],
                'violation_type': 'missing_baserepository',
                'severity': 'high',
                'description': f"Repository {row['file_path']} does not extend BaseRepository",
                'recommendation': "Extend BaseRepository<DataType> for consistency with canonical pattern"
            })

        return violations

    def _check_raw_sql_patterns(self) -> List[Dict]:
        """Check for raw SQL without typed rows"""
        # This would require reading file contents
        # For now, return empty list
        return []

    def _check_missing_sendable(self) -> List[Dict]:
        """Check if coordinators/services are Sendable"""
        cursor = self.db.conn.execute("""
            SELECT * FROM files
            WHERE layer IN ('Coordinator', 'Repository', 'Service-Progress', 'Service-Validation')
            AND is_deleted = 0
            AND concurrency NOT LIKE '%Sendable%'
        """)

        violations = []
        for row in cursor.fetchall():
            violations.append({
                'file_id': row['id'],
                'violation_type': 'missing_sendable',
                'severity': 'medium',
                'description': f"{row['layer']} {row['file_path']} is not Sendable",
                'recommendation': "Add Sendable conformance for Swift 6 concurrency safety"
            })

        return violations

    def _check_missing_mainactor(self) -> List[Dict]:
        """Check if ViewModels have @MainActor"""
        cursor = self.db.conn.execute("""
            SELECT * FROM files
            WHERE layer LIKE 'ViewModel%'
            AND is_deleted = 0
            AND concurrency NOT LIKE '%@MainActor%'
        """)

        violations = []
        for row in cursor.fetchall():
            violations.append({
                'file_id': row['id'],
                'violation_type': 'missing_mainactor',
                'severity': 'high',
                'description': f"ViewModel {row['file_path']} is missing @MainActor",
                'recommendation': "Add @MainActor to ensure UI updates on main thread"
            })

        return violations

# =============================================================================
# REPORT GENERATOR
# =============================================================================

class ReportGenerator:
    """Generate Markdown and CSV reports"""

    def __init__(self, db: ArchitectureDB):
        self.db = db

    def generate_summary_report(self, output_path: Path):
        """Generate summary Markdown report"""
        # Get latest scan
        cursor = self.db.conn.execute("""
            SELECT * FROM scan_summary ORDER BY started_at DESC LIMIT 1
        """)
        latest_scan = cursor.fetchone()

        if not latest_scan:
            print("❌ No scan data found")
            return

        # Generate report
        report = f"""# Architecture Documentation Summary

Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
Scan ID: {latest_scan['id']}
Branch: {latest_scan['git_branch']}
Commit: {latest_scan['git_commit_hash']}

## Overview

- **Total Files**: {latest_scan['total_files']}
- **Total Lines**: {latest_scan['total_lines']:,}
- **Files Scanned**: {latest_scan['files_scanned']}
- **Changes**: {latest_scan['files_created']} created, {latest_scan['files_modified']} modified, {latest_scan['files_deleted']} deleted

## Files by Layer

"""
        # Add files by layer
        cursor = self.db.conn.execute("SELECT * FROM files_by_layer")
        for row in cursor.fetchall():
            report += f"- **{row['layer']}**: {row['count']} files (avg {row['avg_lines']:.0f} lines)\n"

        report += "\n## Files by Domain\n\n"
        cursor = self.db.conn.execute("SELECT * FROM files_by_domain")
        for row in cursor.fetchall():
            report += f"- **{row['domain_entity']}**: {row['count']} files\n"

        report += "\n## Complexity Distribution\n\n"
        cursor = self.db.conn.execute("SELECT * FROM files_by_complexity")
        for row in cursor.fetchall():
            report += f"- **{row['complexity']}**: {row['count']} files\n"

        report += "\n## Open Violations\n\n"
        cursor = self.db.conn.execute("""
            SELECT violation_type, severity, COUNT(*) as count
            FROM violations
            WHERE status = 'open'
            GROUP BY violation_type, severity
            ORDER BY
                CASE severity
                    WHEN 'critical' THEN 1
                    WHEN 'high' THEN 2
                    WHEN 'medium' THEN 3
                    WHEN 'low' THEN 4
                END
        """)

        violations = cursor.fetchall()
        if violations:
            for row in violations:
                report += f"- **{row['severity'].upper()}**: {row['violation_type']} ({row['count']} files)\n"
        else:
            report += "*No open violations found*\n"

        report += "\n## Recent Changes (Last 7 Days)\n\n"
        cursor = self.db.conn.execute("""
            SELECT change_type, COUNT(*) as count
            FROM recent_changes
            GROUP BY change_type
        """)

        changes = cursor.fetchall()
        if changes:
            for row in changes:
                report += f"- **{row['change_type']}**: {row['count']} files\n"
        else:
            report += "*No recent changes*\n"

        # Write report
        with open(output_path, 'w') as f:
            f.write(report)

        print(f"✅ Generated summary report: {output_path}")

    def export_to_csv(self, output_path: Path):
        """Export current architecture map to CSV"""
        cursor = self.db.conn.execute("""
            SELECT
                layer, domain_entity, file_path, file_purpose, key_pattern,
                dependencies, extends_conforms, concurrency, complexity, notes
            FROM active_files
            ORDER BY layer, domain_entity, file_path
        """)

        with open(output_path, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([
                'Layer', 'Domain Entity', 'File Path', 'File Purpose', 'Key Pattern',
                'Dependencies', 'Extends/Conforms', 'Concurrency', 'Complexity', 'Notes'
            ])

            for row in cursor.fetchall():
                writer.writerow([
                    row['layer'],
                    row['domain_entity'],
                    row['file_path'],
                    row['file_purpose'] or '',
                    row['key_pattern'] or '',
                    row['dependencies'] or '',
                    row['extends_conforms'] or '',
                    row['concurrency'],
                    row['complexity'],
                    row['notes'] or ''
                ])

        print(f"✅ Exported CSV: {output_path}")

# =============================================================================
# CSV MIGRATION
# =============================================================================

def migrate_from_csv(db: ArchitectureDB, csv_path: Path):
    """Import existing CSV data into database"""
    print(f"📥 Importing CSV data from {csv_path}")

    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    print(f"Found {len(rows)} rows in CSV")

    # Create initial scan run
    scan_run_id = db.start_scan_run()

    imported = 0
    for row in rows:
        # Map CSV columns to database schema
        file_data = {
            'file_path': row['File Path'],
            'layer': row['Layer'],
            'domain_entity': row['Domain Entity'],
            'file_purpose': row.get('File Purpose', ''),
            'key_pattern': row.get('Key Pattern', ''),
            'dependencies': row.get('Dependencies', ''),
            'extends_conforms': row.get('Extends/Conforms', ''),
            'concurrency': row.get('Concurrency', 'None'),
            'complexity': row.get('Complexity', 'Simple'),
            'notes': row.get('Notes', ''),
            'file_hash': '',  # Will be recalculated on next scan
            'line_count': 0,
            'file_size_bytes': 0,
            'last_modified': datetime.now().isoformat()
        }

        db.upsert_file(file_data, scan_run_id)
        imported += 1

    db.complete_scan_run(scan_run_id, {'scanned': imported, 'created': imported})

    print(f"✅ Imported {imported} files from CSV")

# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description='Architecture documentation automation')
    parser.add_argument('--init', action='store_true', help='Initialize database from CSV')
    parser.add_argument('--scan', action='store_true', help='Scan files and update database')
    parser.add_argument('--report', action='store_true', help='Generate reports')
    parser.add_argument('--check-violations', action='store_true', help='Check for violations')
    parser.add_argument('--export-csv', action='store_true', help='Export to CSV')

    args = parser.parse_args()

    # If no arguments, do full run
    if not any([args.init, args.scan, args.report, args.check_violations, args.export_csv]):
        args.scan = True
        args.report = True
        args.check_violations = True

    print("🏗️  Architecture Documentation Automation")
    print(f"Project: {PROJECT_ROOT.name}")
    print(f"Database: {DB_PATH}")
    print()

    with ArchitectureDB(DB_PATH) as db:
        # Initialize database
        if args.init or not DB_PATH.exists():
            print("🔧 Initializing database...")
            db.initialize_schema(SCHEMA_PATH)

            if CSV_PATH.exists():
                migrate_from_csv(db, CSV_PATH)

        # Scan files
        if args.scan:
            print("\n📊 Scanning Swift files...")
            scanner = SwiftFileScanner(SWIFT_SOURCES)
            files = scanner.scan_all_files()

            scan_run_id = db.start_scan_run()

            stats = {
                'scanned': 0,
                'created': 0,
                'modified': 0,
                'deleted': 0,
                'errors': 0
            }

            scanned_paths = []
            for file_data in files:
                file_id, change_type = db.upsert_file(file_data, scan_run_id)
                scanned_paths.append(file_data['file_path'])

                stats['scanned'] += 1
                if change_type == 'created':
                    stats['created'] += 1
                elif change_type == 'modified':
                    stats['modified'] += 1

            # Mark deleted files
            stats['deleted'] = db.mark_deleted_files(scanned_paths, scan_run_id)

            # Calculate statistics
            cursor = db.conn.execute("SELECT * FROM active_files")
            all_files = cursor.fetchall()

            by_layer = defaultdict(int)
            by_domain = defaultdict(int)
            by_complexity = defaultdict(int)
            by_concurrency = defaultdict(int)
            total_lines = 0
            largest_file = None
            largest_lines = 0
            complex_files = []

            for f in all_files:
                by_layer[f['layer']] += 1
                by_domain[f['domain_entity']] += 1
                by_complexity[f['complexity']] += 1
                by_concurrency[f['concurrency']] += 1
                total_lines += f['line_count'] or 0

                if f['line_count'] and f['line_count'] > largest_lines:
                    largest_lines = f['line_count']
                    largest_file = f['file_path']

                if f['complexity'] == 'Complex':
                    complex_files.append(f['file_path'])

            aggregate_stats = {
                'total_files': len(all_files),
                'files_by_layer': dict(by_layer),
                'files_by_domain': dict(by_domain),
                'files_by_complexity': dict(by_complexity),
                'files_by_concurrency': dict(by_concurrency),
                'total_lines': total_lines,
                'avg_lines_per_file': total_lines / len(all_files) if all_files else 0,
                'largest_file': largest_file,
                'largest_file_lines': largest_lines,
                'complex_files_count': len(complex_files),
                'complex_files_list': complex_files
            }

            db.save_statistics(scan_run_id, aggregate_stats)
            db.complete_scan_run(scan_run_id, stats)

            print(f"\n✅ Scan complete:")
            print(f"   - Scanned: {stats['scanned']} files")
            print(f"   - Created: {stats['created']} files")
            print(f"   - Modified: {stats['modified']} files")
            print(f"   - Deleted: {stats['deleted']} files")

        # Check violations
        if args.check_violations:
            print("\n🔍 Checking for architectural violations...")
            detector = ViolationDetector(db)
            violations = detector.check_all_violations()

            if violations:
                print(f"\n⚠️  Found {len(violations)} violations:")
                for v in violations:
                    print(f"   - [{v['severity'].upper()}] {v['violation_type']}: {v['description']}")
            else:
                print("✅ No violations found")

        # Generate reports
        if args.report:
            print("\n📄 Generating reports...")
            generator = ReportGenerator(db)

            report_dir = PROJECT_ROOT / "ProjectManagement"
            summary_path = report_dir / "ARCHITECTURE_SUMMARY_LATEST.md"
            generator.generate_summary_report(summary_path)

        # Export CSV
        if args.export_csv:
            print("\n📤 Exporting to CSV...")
            generator = ReportGenerator(db)
            csv_out = PROJECT_ROOT / "ProjectManagement" / "ARCHITECTURE_MAP_LATEST.csv"
            generator.export_to_csv(csv_out)

    print("\n✅ All tasks complete!")

if __name__ == '__main__':
    main()
