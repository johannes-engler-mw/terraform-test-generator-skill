#!/usr/bin/env bash
# verify_eval.sh — Quick programmatic verification of terraform-test-generator output
#
# Usage: ./verify_eval.sh <eval-number> <tests-directory>
# Example: ./verify_eval.sh 1 ./test-modules/eval-1-aws-vpc/tests/
#
# Convenience smoke-checker. The canonical, per-expectation grader is
# grade_run.py — it does content-based classification and full dispatch.
# This script checks only OBJECTIVE quality criteria (no naming/doc
# conventions): anti-patterns, functional mocking, invented CLI flags,
# positional test-file arguments in docs, and the execution check.

# No -e: this is a check-runner — individual greps are expected to "fail" (no match),
# every check records its own pass/fail, and the exit code is set explicitly at the end.
set -uo pipefail

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
    PASS=$((PASS+1))
  else
    echo "  ❌ FAIL: $description"
    [[ -n "$detail" ]] && echo "         → $detail"
    FAIL=$((FAIL+1))
  fi
}

warn() {
  local description="$1"
  echo "  ⚠️  WARN: $description"
  WARN=$((WARN+1))
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

# ─── File Structure ──────────────────────────────────────
echo "📁 File Structure"

TF_FILES=$(find "$TESTS_DIR" -name "*.tftest.hcl" 2>/dev/null | wc -l)
if [[ $TF_FILES -gt 0 ]]; then
  check "Test files exist (*.tftest.hcl, any naming)" "pass"
else
  check "Test files exist (*.tftest.hcl, any naming)" "fail" "No .tftest.hcl files found"
  exit 1
fi

# ─── Eval-Specific Checks (content-based) ────────────────
echo ""
echo "📋 Eval-Specific Checks"

if [[ "$EVAL_NUM" == "3" ]]; then
  # Eval 3: module has no validation blocks and no data sources — lean output expected
  EF_HITS=$(grep -rl 'expect_failures' "$TESTS_DIR" --include="*.tftest.hcl" 2>/dev/null | wc -l)
  if [[ $EF_HITS -eq 0 ]]; then
    check "No validation tests (module has no validation blocks)" "pass"
  else
    check "No validation tests (module has no validation blocks)" "fail" "expect_failures found in $EF_HITS files"
  fi

  DS_MOCKS=$(grep -rlE 'override_data|mock_data' "$TESTS_DIR" --include="*.tftest.hcl" 2>/dev/null | wc -l)
  if [[ $DS_MOCKS -eq 0 ]]; then
    check "No data-source mocking (module has no data sources)" "pass"
  else
    check "No data-source mocking (module has no data sources)" "fail" "override_data/mock_data found in $DS_MOCKS files"
  fi
fi

# ─── Anti-Pattern Checks ─────────────────────────────────
echo ""
echo "🔍 Anti-Pattern Detection"

# Check: No computed attributes with command = plan
PLAN_COMPUTED=0
for f in "$TESTS_DIR"/*.tftest.hcl; do
  [[ -f "$f" ]] || continue
  if awk '/command\s*=\s*plan/,/^}/' "$f" | grep -qE 'condition.*\.(id|arn|self_link)\b'; then
    PLAN_COMPUTED=1
    warn "Possible computed attribute in plan block: $f"
  fi
done
if [[ $PLAN_COMPUTED -eq 0 ]]; then
  check "No computed attributes (.id/.arn/.self_link) tested with command = plan" "pass"
else
  check "No computed attributes (.id/.arn/.self_link) tested with command = plan" "fail" "Found computed attrs in plan blocks"
fi

# Check: No [0] on set-type attributes (security group ingress/egress)
SET_INDEX=$(grep -rl '\.\(ingress\|egress\)\[0\]' "$TESTS_DIR"/*.tftest.hcl 2>/dev/null | wc -l)
if [[ $SET_INDEX -eq 0 ]]; then
  check "No [0] indexing on set-type attributes (ingress/egress)" "pass"
else
  check "No [0] indexing on set-type attributes (ingress/egress)" "fail" "Found [0] indexing in $SET_INDEX files"
fi

# Check: No top-level locals blocks in test files (terraform init rejects them)
LOCALS_HITS=$(grep -rlE '^locals\s*\{' "$TESTS_DIR"/*.tftest.hcl 2>/dev/null | wc -l)
if [[ $LOCALS_HITS -eq 0 ]]; then
  check "No top-level locals {} blocks in .tftest.hcl files" "pass"
else
  check "No top-level locals {} blocks in .tftest.hcl files" "fail" "locals blocks found in $LOCALS_HITS files — init will reject the suite"
fi

# ─── Mocking (functional) ────────────────────────────────
echo ""
echo "🔒 Mock Provider (functional)"

# At least one mock_provider must exist in the non-integration test files.
# Aliased vs unaliased and override_data vs mock_data are both acceptable —
# the execution check proves whether the mocking actually works.
MOCKED=$(grep -rl 'mock_provider' "$TESTS_DIR" --include="*.tftest.hcl" 2>/dev/null | wc -l)
if [[ $MOCKED -gt 0 ]]; then
  check "mock_provider defined (any alias form)" "pass"
else
  check "mock_provider defined (any alias form)" "fail" "No mock_provider anywhere — unit tests would need real credentials"
fi

# ─── Documentation Correctness (conditional) ─────────────
echo ""
echo "📄 Documentation Correctness"

MD_FILES=$(find "$TESTS_DIR" -name "*.md" 2>/dev/null)
if [[ -z "$MD_FILES" ]]; then
  warn "No docs generated — positional-args/-cleanup checks skipped (docs are not required)"
else
  # Positional file args are silently ignored by terraform/tofu (whole suite runs).
  # Exclude lines that quote the wrong form to warn against it.
  POSITIONAL=$(grep -hE '(terraform|tofu) test +[^-][^ ]*\.tftest\.hcl' $MD_FILES 2>/dev/null \
    | grep -ivE 'never|not |wrong|❌|avoid|instead' | head -3)
  if [[ -z "$POSITIONAL" ]]; then
    check "No positional test-file arguments in documented commands" "pass"
  else
    check "No positional test-file arguments in documented commands" "fail" "$POSITIONAL"
  fi

  # -cleanup does not exist in either tool. Prose saying "there is no -cleanup flag" is fine.
  CLEANUP=$(grep -hE '(terraform|tofu) test.*-cleanup' $MD_FILES 2>/dev/null \
    | grep -ivE 'no |not |never|does not|doesn.t|❌' | head -3)
  if [[ -z "$CLEANUP" ]]; then
    check "No -cleanup flag emitted in documented commands" "pass"
  else
    check "No -cleanup flag emitted in documented commands" "fail" "$CLEANUP"
  fi
fi

# ─── Execution Check ─────────────────────────────────────
# The strongest signal: generated non-integration tests must actually pass
# `terraform test` against the module. Grep checks can't catch parse errors,
# unknown-value failures under plan, or missing mocks — execution does.
# A file counts as integration if it is named integration_* OR contains a
# command = apply run without any mock_provider/override_* (real-provider apply).
echo ""
echo "🚀 Execution Check"

MODULE_DIR=$(cd "$(dirname "$TESTS_DIR")" && pwd)
TESTS_BASENAME=$(basename "$TESTS_DIR")

if ! command -v terraform >/dev/null 2>&1; then
  warn "terraform not found on PATH — skipping execution check"
else
  FILTERS=()
  for f in "$TESTS_DIR"/*.tftest.hcl; do
    [[ -f "$f" ]] || continue
    BASE=$(basename "$f")
    [[ "$BASE" == integration_* ]] && continue
    if grep -qE 'command\s*=\s*apply' "$f" && ! grep -qE 'mock_provider|override_(data|module|resource)' "$f"; then
      continue  # real-provider apply — never execute in grading
    fi
    FILTERS+=("-filter=$TESTS_BASENAME/$BASE")
  done

  if [[ ${#FILTERS[@]} -eq 0 ]]; then
    warn "No non-integration test files found — skipping execution check"
  else
    EXEC_LOG=$(mktemp)
    if (cd "$MODULE_DIR" && terraform init -backend=false -input=false >/dev/null 2>&1 \
        && terraform test "${FILTERS[@]}" >"$EXEC_LOG" 2>&1); then
      SUMMARY=$(grep -Eo '[0-9]+ passed, [0-9]+ failed' "$EXEC_LOG" | tail -1)
      check "Non-integration tests execute green (${SUMMARY:-passed})" "pass"
    else
      check "Non-integration tests execute green" "fail" "terraform test failed — last lines:"
      tail -15 "$EXEC_LOG" | sed 's/^/         │ /'
    fi
    rm -f "$EXEC_LOG"
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
