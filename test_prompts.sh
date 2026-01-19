#!/usr/bin/env bash

# ============================================
# Tests for Agent Prompt Files
# ============================================

set -euo pipefail

TESTS_PASSED=0
TESTS_FAILED=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="${SCRIPT_DIR}/prompts"

# ============================================
# TEST UTILITIES
# ============================================

assert_file_exists() {
  local filepath="$1"
  local msg="${2:-File should exist: $filepath}"

  if [[ -f "$filepath" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] $msg"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  [FAIL] $msg"
    echo "         File does not exist: $filepath"
    return 1
  fi
}

assert_file_contains() {
  local filepath="$1"
  local pattern="$2"
  local msg="${3:-File should contain pattern}"

  if grep -q "$pattern" "$filepath" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] $msg"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  [FAIL] $msg"
    echo "         Pattern not found: '$pattern'"
    return 1
  fi
}

assert_file_not_empty() {
  local filepath="$1"
  local msg="${2:-File should not be empty}"

  if [[ -s "$filepath" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] $msg"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  [FAIL] $msg"
    echo "         File is empty: $filepath"
    return 1
  fi
}

# ============================================
# RESEARCH PROMPT TESTS
# ============================================

test_research_prompt_exists() {
  echo "Test: research.txt exists"
  assert_file_exists "${PROMPTS_DIR}/research.txt" "research.txt exists"
}

test_research_prompt_not_empty() {
  echo "Test: research.txt is not empty"
  assert_file_not_empty "${PROMPTS_DIR}/research.txt" "research.txt has content"
}

test_research_prompt_has_task_placeholders() {
  echo "Test: research.txt has required placeholders"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "{{TASK_FILE}}" "Has TASK_FILE placeholder"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "{{TASK_NAME}}" "Has TASK_NAME placeholder"
}

test_research_prompt_has_context7_instructions() {
  echo "Test: research.txt has Context7 MCP instructions"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "Context7" "Mentions Context7"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "resolve-library-id" "Has resolve-library-id example"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "query-docs" "Has query-docs example"
}

test_research_prompt_has_codebase_exploration() {
  echo "Test: research.txt has codebase exploration instructions"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "Explore" "Has exploration instructions"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "patterns" "Mentions patterns"
}

test_research_prompt_has_output_requirements() {
  echo "Test: research.txt has output requirements"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "Research.*Status.*Complete" "Has status update instruction"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "Next Agent.*implement" "Has next agent instruction"
}

test_research_prompt_no_implementation() {
  echo "Test: research.txt prohibits implementation"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "DO NOT.*implementation" "Prohibits implementation code"
}

# ============================================
# IMPLEMENT PROMPT TESTS
# ============================================

test_implement_prompt_exists() {
  echo "Test: implement.txt exists"
  assert_file_exists "${PROMPTS_DIR}/implement.txt" "implement.txt exists"
}

test_implement_prompt_not_empty() {
  echo "Test: implement.txt is not empty"
  assert_file_not_empty "${PROMPTS_DIR}/implement.txt" "implement.txt has content"
}

test_implement_prompt_has_task_placeholders() {
  echo "Test: implement.txt has required placeholders"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "{{TASK_FILE}}" "Has TASK_FILE placeholder"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "{{TASK_NAME}}" "Has TASK_NAME placeholder"
}

test_implement_prompt_has_reasoning_requirements() {
  echo "Test: implement.txt requires reasoning documentation"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "reasoning" "Mentions reasoning"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "Alternatives considered" "Requires alternatives documentation"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "Why this approach" "Requires explanation of choice"
}

test_implement_prompt_has_output_requirements() {
  echo "Test: implement.txt has output requirements"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "Implementation.*Status.*Complete" "Has status update instruction"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "Next Agent.*test-typecheck" "Has next agent instruction"
}

test_implement_prompt_reads_research() {
  echo "Test: implement.txt instructs to read research first"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "Research" "References Research section"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "Read.*Research" "Instructs to read research first"
}

test_implement_prompt_has_failure_handling() {
  echo "Test: implement.txt has failure handling"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "5.*attempts" "Has 5 attempt limit reference"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "Needs-Human" "Has Needs-Human reference"
}

# ============================================
# SEQUENTIAL PROMPT TESTS
# ============================================

test_sequential_prompt_exists() {
  echo "Test: sequential.txt exists"
  assert_file_exists "${PROMPTS_DIR}/sequential.txt" "sequential.txt exists"
}

test_sequential_prompt_has_placeholders() {
  echo "Test: sequential.txt has required placeholders"
  assert_file_contains "${PROMPTS_DIR}/sequential.txt" "{{PRD_FILE}}" "Has PRD_FILE placeholder"
  assert_file_contains "${PROMPTS_DIR}/sequential.txt" "{{TESTS_STEPS}}" "Has TESTS_STEPS placeholder"
  assert_file_contains "${PROMPTS_DIR}/sequential.txt" "{{COMMIT_STEP}}" "Has COMMIT_STEP placeholder"
}

# ============================================
# PARALLEL PROMPT TESTS
# ============================================

test_parallel_prompt_exists() {
  echo "Test: parallel.txt exists"
  assert_file_exists "${PROMPTS_DIR}/parallel.txt" "parallel.txt exists"
}

test_parallel_prompt_has_task_placeholder() {
  echo "Test: parallel.txt has task placeholder"
  assert_file_contains "${PROMPTS_DIR}/parallel.txt" "{{TASK_NAME}}" "Has TASK_NAME placeholder"
}

# ============================================
# RUN ALL TESTS
# ============================================

echo "============================================"
echo "Running Agent Prompt Tests"
echo "============================================"
echo ""

# Research prompt tests
test_research_prompt_exists
test_research_prompt_not_empty
test_research_prompt_has_task_placeholders
test_research_prompt_has_context7_instructions
test_research_prompt_has_codebase_exploration
test_research_prompt_has_output_requirements
test_research_prompt_no_implementation

# Implement prompt tests
test_implement_prompt_exists
test_implement_prompt_not_empty
test_implement_prompt_has_task_placeholders
test_implement_prompt_has_reasoning_requirements
test_implement_prompt_has_output_requirements
test_implement_prompt_reads_research
test_implement_prompt_has_failure_handling

# Sequential prompt tests
test_sequential_prompt_exists
test_sequential_prompt_has_placeholders

# Parallel prompt tests
test_parallel_prompt_exists
test_parallel_prompt_has_task_placeholder

echo ""
echo "============================================"
echo "Test Results"
echo "============================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo "All tests passed!"
  exit 0
else
  echo "Some tests failed!"
  exit 1
fi
