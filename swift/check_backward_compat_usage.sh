#!/bin/bash
# check_backward_compat_usage.sh
#
# PURPOSE: Monitor usage of backward compatibility methods to determine
#          when it's safe to remove them
#
# USAGE: ./check_backward_compat_usage.sh
#
# EXIT CODES:
#   0 = Safe to remove (no usages found)
#   1 = Not safe to remove (usages still exist)

set -e

echo "🔍 Checking backward compatibility method usage..."
echo ""

# Count usages (excluding DataTypes definitions and comments)
USAGES=$(grep -r "\.asValue\|\.asDetails\|\.asWithPeriod" \
  --include="*.swift" Sources/ | \
  grep -v "Sources/Models/DataTypes" | \
  grep -v "^[[:space:]]*//.*\.as" | \
  wc -l | tr -d ' ')

echo "📊 Found $USAGES usages of backward compatibility methods"
echo ""

if [ "$USAGES" -eq 0 ]; then
  echo "✅ Safe to remove backward compatibility extensions!"
  echo ""
  echo "Next steps:"
  echo "  1. Remove .asValue from PersonalValueData.swift"
  echo "  2. Remove .asDetails from GoalData.swift"
  echo "  3. Remove .asDetails from ActionData.swift"
  echo "  4. Remove .asWithPeriod from TermData.swift"
  echo "  5. Run swift build to verify"
  exit 0
else
  echo "⚠️  Still have $USAGES usages - not safe to remove yet"
  echo ""
  echo "Usage breakdown by file:"
  grep -r "\.asValue\|\.asDetails\|\.asWithPeriod" \
    --include="*.swift" Sources/ | \
    grep -v "Sources/Models/DataTypes" | \
    grep -v "^[[:space:]]*//.*\.as" | \
    cut -d: -f1 | sort | uniq -c | sort -rn | \
    awk '{printf "  %3d  %s\n", $1, $2}'

  echo ""
  echo "Usage breakdown by method:"

  # Count .asValue
  AS_VALUE=$(grep -r "\.asValue" --include="*.swift" Sources/ | \
    grep -v "Sources/Models/DataTypes" | \
    grep -v "^[[:space:]]*//.*\.as" | \
    wc -l | tr -d ' ')
  echo "  .asValue:      $AS_VALUE"

  # Count .asDetails
  AS_DETAILS=$(grep -r "\.asDetails" --include="*.swift" Sources/ | \
    grep -v "Sources/Models/DataTypes" | \
    grep -v "^[[:space:]]*//.*\.as" | \
    wc -l | tr -d ' ')
  echo "  .asDetails:    $AS_DETAILS"

  # Count .asWithPeriod
  AS_WITH_PERIOD=$(grep -r "\.asWithPeriod" --include="*.swift" Sources/ | \
    grep -v "Sources/Models/DataTypes" | \
    grep -v "^[[:space:]]*//.*\.as" | \
    wc -l | tr -d ' ')
  echo "  .asWithPeriod: $AS_WITH_PERIOD"

  echo ""
  echo "See BACKWARD_COMPATIBILITY_RETIREMENT_PLAN.md for migration steps"
  exit 1
fi
