# GoalRepository Test Suite

## Overview

This directory contains comprehensive tests for **GoalRepository** and **GoalRepository_v3**, designed to validate that both implementations provide correct, defensive, and aggressive query behavior.

## Test Files

### 1. `GoalRepositoryTests.swift`
**Primary test suite for GoalRepository (current implementation)**

- **Coverage**: 30+ tests covering all repository methods
- **Strategy**: Defensive assertions on meaningful parameters only
- **Focus**: Data correctness, relationship integrity, edge cases
- **Compatible with**: GoalRepository (with minor adjustments for GoalRepository_v3)

**Key Test Areas:**
- ✅ Complete data retrieval (`fetchAll`)
- ✅ Relationship graph assembly (measures, values, terms)
- ✅ Empty relationship handling (empty arrays vs nil)
- ✅ Active goal filtering (`fetchActiveGoals`)
- ✅ Term assignment filtering (`fetchByTerm`)
- ✅ Value alignment filtering (`fetchByValue`)
- ✅ Existence checks (`exists(id:)`, `existsByTitle()`)
- ✅ Error mapping (ValidationError messages)
- ✅ Edge cases (nil dates, empty strings, data mixing prevention)

### 2. `GoalRepository_v3_Tests.swift`
**Test suite specifically for GoalRepository_v3 (BaseRepository-based implementation)**

- **Coverage**: Same 30+ tests adapted for v3 API differences
- **Strategy**: Same defensive approach
- **Focus**: v3-specific features + core compatibility
- **Compatible with**: GoalRepository_v3 only

**Additional v3 Tests:**
- ✅ `fetchForExport(from:to:)` date filtering
- ✅ `fetch(limit:offset:)` pagination
- ✅ `fetchRecent(limit:)` ordering
- ✅ Consistent return types (all GoalData)

## Test Philosophy

### Defensive Testing
Tests focus on **meaningful parameters** that affect correctness:
- ✅ **YES**: Verify relationship IDs match expected values
- ✅ **YES**: Verify measures belong to correct goals
- ✅ **YES**: Verify empty relationships return `[]` not `nil`
- ✅ **YES**: Verify error messages are user-friendly
- ❌ **NO**: Check implementation details (e.g., SQL syntax)
- ❌ **NO**: Verify internal data structures
- ❌ **NO**: Assert on performance metrics (unless critical)

### Aggressive Testing
Tests include extensive edge cases:
- Goals with **no measures** (empty arrays)
- Goals with **multiple measures** (relationship grouping)
- Goals with **no term assignment** (nil handling)
- Goals with **nil dates** (optional field handling)
- Goals with **past target dates** (filtering edge cases)
- **Case-insensitive** title checks
- **Invalid foreign keys** (error handling)
- **Data mixing prevention** (relationship isolation)

## Test Data Design

### Created Test Data
Each test suite creates **6 diverse goals**:

1. **"running"**: Complex goal (2 measures, 1 value, term assigned)
2. **"reading"**: No measures (empty array handling)
3. **"family"**: Multiple value alignments (relationship multiplicity)
4. **"spanish"**: Active goal with future target date
5. **"taxes"**: Past goal (target date in past)
6. **"mindfulness"**: No target date (nil handling)

### Test Measures
- **kilometers**: Distance measure
- **hours**: Duration measure
- **count**: Quantity measure

### Test Values
- **health**: Major value (aligned with multiple goals)
- **learning**: Major value
- **relationships**: Highest-order value

### Test Terms
- **term1**: Q1 2025 (has "running" goal assigned)
- **term2**: Q2 2025 (has "spanish" goal assigned)

## Running the Tests

### Run All Repository Tests
```bash
swift test --filter GoalRepository
```

### Run Original GoalRepository Tests Only
```bash
swift test --filter "GoalRepository - Comprehensive Data Validation"
```

### Run v3 Tests Only
```bash
swift test --filter "GoalRepository_v3 - BaseRepository Implementation"
```

### Run Specific Test Case
```bash
swift test --filter "fetchAll returns all goals"
```

## Adapting Tests for Different Implementations

### To Test GoalRepository_v3 with GoalRepositoryTests.swift

**Required Changes:**

1. **Change Repository Instantiation:**
```swift
// FROM:
let repository = GoalRepository(database: db)

// TO:
let repository = GoalRepository_v3(database: db)
```

2. **Adjust Return Type Access:**
```swift
// FROM (GoalWithDetails):
activeGoals.first?.goal.id

// TO (GoalData):
activeGoals.first?.id
```

3. **Adjust Method Names:**
```swift
// FROM:
repository.existsByTitle("title")

// TO:
repository.exists(title: "title")
```

## Key Differences Between Implementations

| Feature | GoalRepository | GoalRepository_v3 |
|---------|---------------|-------------------|
| **fetchAll()** | Returns `[GoalData]` | Returns `[GoalData]` ✅ Same |
| **fetchActiveGoals()** | Returns `[GoalWithDetails]` | Returns `[GoalData]` ⚠️ Different |
| **fetchByTerm()** | Returns `[GoalWithDetails]` | Returns `[GoalData]` ⚠️ Different |
| **fetchByValue()** | Returns `[Goal]` | Returns `[GoalData]` ⚠️ Different |
| **Title check** | `existsByTitle(String)` | `exists(title: String)` ⚠️ Different name |
| **Export** | `fetchAll(from:to:)` | `fetchForExport(from:to:)` ⚠️ Different name |
| **Pagination** | ❌ Not available | ✅ `fetch(limit:offset:)` |
| **Recent fetch** | ❌ Not available | ✅ `fetchRecent(limit:)` |
| **Error mapping** | Custom implementation | Inherits from BaseRepository |

## Test Assertions Strategy

### What Gets Asserted
✅ **Data Correctness:**
- Goal IDs match created goals
- Relationship counts match expected values
- Measure targets have correct values
- Value alignments have correct strengths

✅ **Relationship Integrity:**
- Measures belong to correct goal (no mixing)
- Values align with correct goals
- Terms assign to correct goals

✅ **Edge Case Handling:**
- Empty arrays for missing relationships
- Nil for optional unassigned relationships
- Past goals filtered from active results
- Case-insensitive title matching

✅ **Error Quality:**
- ValidationError thrown (not generic Error)
- Error messages mention relevant entities
- User-friendly error text

### What Doesn't Get Asserted
❌ **Implementation Details:**
- SQL query structure
- JSON parsing internals
- Performance metrics (unless critical)
- Internal data structure layout

## Test Failure Analysis

### If GoalRepository Tests Fail
This indicates a **breaking change** in the current implementation:
- Check for database schema changes
- Verify coordinator creates data correctly
- Review relationship table FK constraints

### If GoalRepository_v3 Tests Fail
This indicates v3 **doesn't match** GoalRepository capabilities:
- Missing functionality (method not implemented)
- Incorrect return types
- Broken relationship assembly
- Error mapping issues

## Expected Test Results

### Current Status
- **GoalRepositoryTests.swift**: ✅ Should PASS against GoalRepository
- **GoalRepository_v3_Tests.swift**: ⚠️ Should PASS against GoalRepository_v3 (when fully implemented)

### Success Criteria
Both test suites should:
1. ✅ Create 6 diverse goals without errors
2. ✅ Fetch all goals with complete relationships
3. ✅ Filter active goals correctly
4. ✅ Filter by term correctly
5. ✅ Filter by value correctly
6. ✅ Handle empty relationships gracefully
7. ✅ Throw user-friendly ValidationErrors
8. ✅ Prevent data mixing between goals

## Contributing

When adding new tests:
1. **Focus on meaningful assertions** (not implementation details)
2. **Add equivalent tests to both files** (maintain parity)
3. **Document edge cases** being tested
4. **Use descriptive test names** that explain what's being validated
5. **Include print statements** for debugging visibility

## Architecture Notes

### Why Two Test Files?
- **GoalRepositoryTests.swift**: Tests the **current production** implementation
- **GoalRepository_v3_Tests.swift**: Tests the **future refactored** implementation

This approach ensures:
- ✅ Current implementation remains validated during refactor
- ✅ New implementation matches existing behavior
- ✅ No regression when migrating to v3
- ✅ Clear documentation of API differences

### Test Isolation
Both test suites use:
- **Separate database instances** (`.localTesting` mode)
- **Independent test data** (created in setup)
- **Serialized execution** (`.serialized` suite attribute)
- **Clean slate** (database deleted before each suite)

This ensures tests don't interfere with each other or production data.

## Questions?

See the test file headers for:
- **PURPOSE**: Why the test exists
- **TEST STRATEGY**: How it validates behavior
- **WHAT THIS VALIDATES**: Specific guarantees checked
- **COMPATIBILITY**: Which implementations it works with

For implementation questions, refer to:
- `GoalRepository.swift` (current implementation)
- `GoalRepository_v3.swift` (BaseRepository-based implementation)
- `BaseRepository.swift` (shared base class)
