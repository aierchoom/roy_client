#!/usr/bin/env bash
# SecretRoy 一键回归测试脚本（Linux/macOS）
# 运行 analyze → style check → unit test (含 coverage) → integration test

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

UNIT_ONLY=false
INTEGRATION_ONLY=false
NO_COVERAGE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --unit-only) UNIT_ONLY=true; shift ;;
    --integration-only) INTEGRATION_ONLY=true; shift ;;
    --no-coverage) NO_COVERAGE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

RESULTS=()
OVERALL_PASS=true

run_stage() {
  local name="$1"
  shift
  echo "========================================"
  echo "$name"
  echo "========================================"
  local start end duration exit_code
  start=$(date +%s)
  exit_code=0
  "$@" || exit_code=$?
  end=$(date +%s)
  duration=$((end - start))
  if [[ $exit_code -eq 0 ]]; then
    RESULTS+=("$(printf "%-40s | PASS | %ds" "$name" "$duration")")
    echo "[PASS] $name (${duration}s)"
  else
    RESULTS+=("$(printf "%-40s | FAIL | %ds" "$name" "$duration")")
    echo "[FAIL] $name (${duration}s)"
    OVERALL_PASS=false
  fi
  echo ""
}

# ------------------------------------------------------------------------------
# Dart Analyze
# ------------------------------------------------------------------------------
stage_analyze() {
  flutter analyze lib test
}

# ------------------------------------------------------------------------------
# Style Token Check
# ------------------------------------------------------------------------------
stage_style() {
  if command -v python3 >/dev/null 2>&1; then
    python3 tool/check_style_tokens.py
  elif command -v python >/dev/null 2>&1; then
    python tool/check_style_tokens.py
  else
    echo "Python not found, skipping style token check."
  fi
}

# ------------------------------------------------------------------------------
# Unit Tests
# ------------------------------------------------------------------------------
stage_unit() {
  if [[ "$NO_COVERAGE" == true ]]; then
    flutter test
  else
    flutter test --coverage
  fi
}

# ------------------------------------------------------------------------------
# Integration Tests
# ------------------------------------------------------------------------------
stage_integration() {
  local test_dir="$REPO_ROOT/integration_test"
  if [[ ! -d "$test_dir" ]]; then
    echo "No integration_test directory found."
    return 0
  fi

  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$test_dir" -maxdepth 1 -name '*.dart' -print0 | sort -z)

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No integration test files found."
    return 0
  fi

  local all_passed=true
  for f in "${files[@]}"; do
    local basename
    basename=$(basename "$f")
    local test_dir_tmp
    test_dir_tmp=$(mktemp -d)
    export SECRETROY_TEST_DIR="$test_dir_tmp"
    export SECRETROY_TEST_DISABLE_NO_PASSWORD=1
    echo "Running: $basename"
    if flutter test "$f" --reporter expanded; then
      :
    else
      all_passed=false
    fi
    rm -rf "$test_dir_tmp"
  done

  if [[ "$all_passed" == false ]]; then
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Execute
# ------------------------------------------------------------------------------
if [[ "$UNIT_ONLY" == true ]]; then
  run_stage "Dart Analyze" stage_analyze
  run_stage "Style Token Check" stage_style
  run_stage "Unit Tests" stage_unit
elif [[ "$INTEGRATION_ONLY" == true ]]; then
  run_stage "Integration Tests" stage_integration
else
  run_stage "Dart Analyze" stage_analyze
  run_stage "Style Token Check" stage_style
  run_stage "Unit Tests" stage_unit
  run_stage "Integration Tests" stage_integration
fi

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo "========================================"
echo "Regression Summary"
echo "========================================"
for r in "${RESULTS[@]}"; do
  echo "$r"
done

if [[ "$OVERALL_PASS" == true ]]; then
  echo ""
  echo "All stages passed."
  exit 0
else
  echo ""
  echo "Some stages failed."
  exit 1
fi
