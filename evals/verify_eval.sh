#!/usr/bin/env bash
# verify_eval.sh — Programmatic verification of terraform-test-generator skill output
#
# Usage: ./verify_eval.sh <eval-number> <tests-directory>
# Example: ./verify_eval.sh 1 ./test-modules/eval-1-aws-vpc/tests/
#
# Checks common expectations that can be verified via file inspection.
# Returns exit code 0 if all checks pass, 1 if any fail.

set -euo pipefail

EVAL_NUM="${1:?Usage: $0 <eval-number> <tests-directory>}"
TESTS_DIR="${2:?Usage: $0 <eval-number> <tests-directory>}"

PASS=0
FAIL=0
WARN=0

check() {
  local description="$1"
  local result="$2"  # "pass" or "fail"
  local detail="${3:-}"

  if [[ "$result" == "pass" ]]; then
    echo "  ✅ PASS: $description"
    ((PASS++))
  else
    echo "  ❌ FAIL: $description"
    [[ -n "$detail" ]] && echo "         → $detail"
    ((FAIL++))
  fi
}

warn() {
  local description="$1"
  echo "  ⚠️  WARN: $description"
  ((WARN++))
}

echo "═══════════════════════════════════════════════════════"
echo " Terraform Test Generator — Eval $EVAL_NUM Verification"
echo " Tests directory: $TESTS_DIR"
echo "═══════════════════════════════════════════════════════"
echo ""

if [[ ! -d "$TESTS_DIR" ]]; then
  echo "ERROR: Tests directory not found: $TESTS_DIR"
  exit 1
fi

# ─── File Structure Checks ───────────────────────────────
echo "📁 File Structure"

# Check unit tests exist
UNIT_FILES=$(find "$TESTS_DIR" -name "unit_*.tftest.hcl" 2>/dev/null | wc -l)
if [[ $UNIT_FILES -gt 0 ]]; then
  check "Unit test files exist (unit_*.tftest.hcl)" "pass"
else
  check "Unit test files exist (unit_*.tftest.hcl)" "fail" "No unit test files found"
fi

# Check integration tests exist
INT_FILES=$(find "$TESTS_DIR" -name "integration_*.tftest.hcl" 2>/dev/null | wc -l)
if [[ $INT_FILES -gt 0 ]]; then
  check "Integration test files exist" "pass"
else
  check "Integration test files exist" "fail" "No integration test files found"
fi

# Check compliance tests exist
COMP_FILES=$(find "$TESTS_DIR" -name "compliance_*.tftest.hcl" 2>/dev/null | wc -l)
if [[ $COMP_FILES -gt 0 ]]; then
  check "Compliance test files exist" "pass"
else
  check "Compliance test files exist" "fail" "No compliance test files found"
fi

# Check README exists
if [[ -f "$TESTS_DIR/README.md" ]]; then
  check "README.md exists" "pass"
else
  check "README.md exists" "fail"
fi

# Check COVERAGE exists
if [[ -f "$TESTS_DIR/COVERAGE.md" ]]; then
  check "COVERAGE.md exists" "pass"
else
  check "COVERAGE.md exists" "fail"
fi

# ─── Eval-Specific File Checks ───────────────────────────
echo ""
echo "📋 Eval-Specific Checks"

if [[ "$EVAL_NUM" == "1" ]]; then
  # Eval 1: Should have validation and mock tests
  MOCK_FILES=$(find "$TESTS_DIR" -name "mock_*.tftest.hcl" -o -name "mock_*.tfmock.hcl" 2>/dev/null | wc -l)
  if [[ $MOCK_FILES -gt 0 ]]; then
    check "Mock test files exist (eval 1 has data sources)" "pass"
  else
    check "Mock test files exist (eval 1 has data sources)" "fail"
  fi

  VAL_FILES=$(find "$TESTS_DIR" -name "validation_*.tftest.hcl" 2>/dev/null | wc -l)
  if [[ $VAL_FILES -gt 0 ]]; then
    check "Validation test files exist (eval 1 has validations)" "pass"
  else
    check "Validation test files exist (eval 1 has validations)" "fail"
  fi

elif [[ "$EVAL_NUM" == "2" ]]; then
  # Eval 2: Should have validation tests (has validation blocks)
  VAL_FILES=$(find "$TESTS_DIR" -name "validation_*.tftest.hcl" 2>/dev/null | wc -l)
  if [[ $VAL_FILES -gt 0 ]]; then
    check "Validation test files exist (eval 2 has validations)" "pass"
  else
    check "Validation test files exist (eval 2 has validations)" "fail"
  fi

elif [[ "$EVAL_NUM" == "3" ]]; then
  # Eval 3: Should NOT have validation or mock tests
  VAL_FILES=$(find "$TESTS_DIR" -name "validation_*.tftest.hcl" 2>/dev/null | wc -l)
  if [[ $VAL_FILES -eq 0 ]]; then
    check "No validation test files (eval 3 has no validations)" "pass"
  else
    check "No validation test files (eval 3 has no validations)" "fail" "Found $VAL_FILES validation files"
  fi

  MOCK_FILES=$(find "$TESTS_DIR" -name "mock_*.tftest.hcl" -o -name "mock_*.tfmock.hcl" 2>/dev/null | wc -l)
  if [[ $MOCK_FILES -eq 0 ]]; then
    check "No mock test files (eval 3 has no data sources)" "pass"
  else
    check "No mock test files (eval 3 has no data sources)" "fail" "Found $MOCK_FILES mock files"
  fi
fi

# ─── Anti-Pattern Checks ─────────────────────────────────
echo ""
echo "🔍 Anti-Pattern Detection"

# Check: No computed attributes with command = plan
# Look for plan blocks that assert on .id or .arn
PLAN_COMPUTED=0
for f in "$TESTS_DIR"/*.tftest.hcl; do
  [[ -f "$f" ]] || continue
  # Extract plan blocks and check for .id/.arn in conditions
  if awk '/command\s*=\s*plan/,/^}/' "$f" | grep -qE 'condition.*\.(id|arn|self_link)\b'; then
    PLAN_COMPUTED=1
    warn "Possible computed attribute in plan block: $f"
  fi
done
if [[ $PLAN_COMPUTED -eq 0 ]]; then
  check "No computed attributes (.id/.arn) tested with command = plan" "pass"
else
  check "No computed attributes (.id/.arn) tested with command = plan" "fail" "Found computed attrs in plan blocks"
fi

# Check: No [0] on set-type attributes (security group ingress/egress)
SET_INDEX=$(grep -rl '\.\(ingress\|egress\)\[0\]' "$TESTS_DIR"/*.tftest.hcl 2>/dev/null | wc -l)
if [[ $SET_INDEX -eq 0 ]]; then
  check "No [0] indexing on set-type attributes (ingress/egress)" "pass"
else
  check "No [0] indexing on set-type attributes (ingress/egress)" "fail" "Found [0] indexing in $SET_INDEX files"
fi

# Check: All assert conditions on single line
MULTILINE=0
for f in "$TESTS_DIR"/*.tftest.hcl; do
  [[ -f "$f" ]] || continue
  # Check if condition spans multiple lines (condition = ... without closing on same line followed by continuation)
  if awk '/condition\s*=/ { line=$0; if (!/error_message/ && !/}/) { getline next; if (next !~ /error_message/ && next !~ /^[[:space:]]*}/) print FILENAME": multi-line condition" } }' "$f" | grep -q .; then
    MULTILINE=1
  fi
done
if [[ $MULTILINE -eq 0 ]]; then
  check "All assert conditions appear to be single-line" "pass"
else
  check "All assert conditions appear to be single-line" "fail"
fi

# ─── Mock Provider Checks ────────────────────────────────
echo ""
echo "🔒 Mock Provider Checks"

# Check unit tests have mock_provider defined
for f in "$TESTS_DIR"/unit_*.tftest.hcl; do
  [[ -f "$f" ]] || continue
  BASENAME=$(basename "$f")
  if grep -q 'mock_provider' "$f"; then
    check "mock_provider defined in $BASENAME" "pass"
  else
    check "mock_provider defined in $BASENAME" "fail"
  fi

  # Check providers = { ... } in run blocks
  if grep -q 'providers\s*=' "$f"; then
    check "providers block referenced in $BASENAME" "pass"
  else
    check "providers block referenced in $BASENAME" "fail" "Run blocks must reference mock provider"
  fi
done

# ─── Data Source Mocking (Eval 1 and 2) ───────────────────
echo ""
echo "📊 Data Source Mocking"

if [[ "$EVAL_NUM" == "1" ]]; then
  # Check aws_availability_zones is mocked
  AZ_MOCK=$(grep -rl 'aws_availability_zones' "$TESTS_DIR"/unit_*.tftest.hcl "$TESTS_DIR"/mock_*.tftest.hcl "$TESTS_DIR"/mock_*.tfmock.hcl 2>/dev/null | wc -l)
  if [[ $AZ_MOCK -gt 0 ]]; then
    check "data.aws_availability_zones.available is mocked" "pass"
  else
    check "data.aws_availability_zones.available is mocked" "fail"
  fi

  # Check aws_ami is mocked
  AMI_MOCK=$(grep -rl 'aws_ami' "$TESTS_DIR"/unit_*.tftest.hcl "$TESTS_DIR"/mock_*.tftest.hcl "$TESTS_DIR"/mock_*.tfmock.hcl 2>/dev/null | wc -l)
  if [[ $AMI_MOCK -gt 0 ]]; then
    check "data.aws_ami.al2023 is mocked" "pass"
  else
    check "data.aws_ami.al2023 is mocked" "fail"
  fi

elif [[ "$EVAL_NUM" == "2" ]]; then
  # Check azurerm_client_config is mocked
  CC_MOCK=$(grep -rl 'azurerm_client_config' "$TESTS_DIR"/*.tftest.hcl "$TESTS_DIR"/*.tfmock.hcl 2>/dev/null | wc -l)
  if [[ $CC_MOCK -gt 0 ]]; then
    check "data.azurerm_client_config.current is mocked" "pass"
  else
    check "data.azurerm_client_config.current is mocked" "fail"
  fi

  # Check UUID format in mocks
  UUID_VALID=$(grep -rE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$TESTS_DIR"/*.tftest.hcl "$TESTS_DIR"/*.tfmock.hcl 2>/dev/null | wc -l)
  if [[ $UUID_VALID -gt 0 ]]; then
    check "Azure mock values use valid UUID format" "pass"
  else
    check "Azure mock values use valid UUID format" "fail"
  fi
fi

# ─── README Content Checks ───────────────────────────────
echo ""
echo "📄 README Content"

if [[ -f "$TESTS_DIR/README.md" ]]; then
  # Check no -filter with wildcards
  if grep -q '\-filter.*\*' "$TESTS_DIR/README.md"; then
    check "README does NOT use -filter with wildcards" "fail" "Found -filter with wildcards"
  else
    check "README does NOT use -filter with wildcards" "pass"
  fi

  # Check cost warnings
  if grep -qi 'cost\|real resource\|billing' "$TESTS_DIR/README.md"; then
    check "README includes cost/safety warnings" "pass"
  else
    check "README includes cost/safety warnings" "fail"
  fi

  # Check tofu test mentioned
  if grep -q 'tofu test' "$TESTS_DIR/README.md"; then
    check "README shows tofu test commands" "pass"
  else
    check "README shows tofu test commands" "fail"
  fi
fi

# ─── Variable Completeness Check ─────────────────────────
echo ""
echo "📝 Variable Completeness"

# Check that test-safe values are used (eval 1)
if [[ "$EVAL_NUM" == "1" ]]; then
  if grep -rl 'environment.*=.*"test"' "$TESTS_DIR"/*.tftest.hcl 2>/dev/null | head -1 | grep -q .; then
    check "Test-safe environment value used (test)" "pass"
  else
    warn "Could not verify test-safe environment value"
  fi
fi

# ─── Summary ─────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo " Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "═══════════════════════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
  exit 1
else
  exit 0
fi
