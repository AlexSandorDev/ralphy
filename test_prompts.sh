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

test_research_prompt_has_next_agent_rules() {
  echo "Test: research.txt has explicit Next Agent rules"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "Next Agent field rules" "Has Next Agent field rules section"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "On SUCCESS.*implement" "Has success next agent rule"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "On FAILURE.*research" "Has failure next agent rule"
  assert_file_contains "${PROMPTS_DIR}/research.txt" "On BLOCKED.*Needs-Human" "Has blocked scenario rule"
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

test_implement_prompt_has_next_agent_rules() {
  echo "Test: implement.txt has explicit Next Agent rules"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "Next Agent field rules" "Has Next Agent field rules section"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "On SUCCESS.*test-typecheck" "Has success next agent rule"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "On FAILURE.*research" "Has failure next agent rule"
  assert_file_contains "${PROMPTS_DIR}/implement.txt" "On BLOCKED.*Needs-Human" "Has blocked scenario rule"
}

# ============================================
# TEST-TYPECHECK PROMPT TESTS
# ============================================

test_typecheck_prompt_exists() {
  echo "Test: test-typecheck.txt exists"
  assert_file_exists "${PROMPTS_DIR}/test-typecheck.txt" "test-typecheck.txt exists"
}

test_typecheck_prompt_not_empty() {
  echo "Test: test-typecheck.txt is not empty"
  assert_file_not_empty "${PROMPTS_DIR}/test-typecheck.txt" "test-typecheck.txt has content"
}

test_typecheck_prompt_has_task_placeholders() {
  echo "Test: test-typecheck.txt has required placeholders"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "{{TASK_FILE}}" "Has TASK_FILE placeholder"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "{{TASK_NAME}}" "Has TASK_NAME placeholder"
}

test_typecheck_prompt_has_tsc_command() {
  echo "Test: test-typecheck.txt has tsc command"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "tsc --noEmit" "Has tsc --noEmit command"
}

test_typecheck_prompt_has_output_requirements() {
  echo "Test: test-typecheck.txt has output requirements"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "Type Check.*Status.*Complete" "Has status update instruction"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "Next Agent.*test-terminal" "Has next agent instruction"
}

test_typecheck_prompt_has_failure_handling() {
  echo "Test: test-typecheck.txt has failure handling"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "5 attempts" "Has 5 attempt limit reference"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "Needs-Human" "Has Needs-Human reference"
}

test_typecheck_prompt_has_auto_detect() {
  echo "Test: test-typecheck.txt has auto-detect instructions"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "package.json" "Mentions package.json for command detection"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "typecheck" "Has typecheck script name"
}

test_typecheck_prompt_references_implementation() {
  echo "Test: test-typecheck.txt references implementation section"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "Implementation" "References Implementation section"
}

test_typecheck_prompt_has_next_agent_rules() {
  echo "Test: test-typecheck.txt has explicit Next Agent rules"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "Next Agent field rules" "Has Next Agent field rules section"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "On SUCCESS.*test-terminal" "Has success next agent rule"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "On FAILURE.*implement" "Has failure next agent rule"
  assert_file_contains "${PROMPTS_DIR}/test-typecheck.txt" "On BLOCKED.*Needs-Human" "Has blocked scenario rule"
}

# ============================================
# TEST-TERMINAL PROMPT TESTS
# ============================================

test_terminal_prompt_exists() {
  echo "Test: test-terminal.txt exists"
  assert_file_exists "${PROMPTS_DIR}/test-terminal.txt" "test-terminal.txt exists"
}

test_terminal_prompt_not_empty() {
  echo "Test: test-terminal.txt is not empty"
  assert_file_not_empty "${PROMPTS_DIR}/test-terminal.txt" "test-terminal.txt has content"
}

test_terminal_prompt_has_task_placeholders() {
  echo "Test: test-terminal.txt has required placeholders"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "{{TASK_FILE}}" "Has TASK_FILE placeholder"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "{{TASK_NAME}}" "Has TASK_NAME placeholder"
}

test_terminal_prompt_has_dev_server_command() {
  echo "Test: test-terminal.txt has dev server instructions"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "dev server" "Has dev server instructions"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "npm run dev" "Has npm run dev command"
}

test_terminal_prompt_has_output_requirements() {
  echo "Test: test-terminal.txt has output requirements"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "Terminal Errors.*Status.*Complete" "Has status update instruction"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "Next Agent.*test-browser" "Has next agent instruction"
}

test_terminal_prompt_has_failure_handling() {
  echo "Test: test-terminal.txt has failure handling"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "5 attempts" "Has 5 attempt limit reference"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "Needs-Human" "Has Needs-Human reference"
}

test_terminal_prompt_has_auto_detect() {
  echo "Test: test-terminal.txt has auto-detect instructions"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "package.json" "Mentions package.json for command detection"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "dev.*start.*serve" "Has common dev script names"
}

test_terminal_prompt_references_implementation() {
  echo "Test: test-terminal.txt references implementation section"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "Implementation" "References Implementation section"
}

test_terminal_prompt_has_error_types() {
  echo "Test: test-terminal.txt mentions error types to check"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "Compile error" "Mentions compile errors"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "runtime" "Mentions runtime errors"
}

test_terminal_prompt_has_next_agent_rules() {
  echo "Test: test-terminal.txt has explicit Next Agent rules"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "Next Agent field rules" "Has Next Agent field rules section"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "On SUCCESS.*test-browser" "Has success next agent rule"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "On FAILURE.*implement" "Has failure next agent rule"
  assert_file_contains "${PROMPTS_DIR}/test-terminal.txt" "On BLOCKED.*Needs-Human" "Has blocked scenario rule"
}

# ============================================
# TEST-BROWSER PROMPT TESTS
# ============================================

test_browser_prompt_exists() {
  echo "Test: test-browser.txt exists"
  assert_file_exists "${PROMPTS_DIR}/test-browser.txt" "test-browser.txt exists"
}

test_browser_prompt_not_empty() {
  echo "Test: test-browser.txt is not empty"
  assert_file_not_empty "${PROMPTS_DIR}/test-browser.txt" "test-browser.txt has content"
}

test_browser_prompt_has_task_placeholders() {
  echo "Test: test-browser.txt has required placeholders"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "{{TASK_FILE}}" "Has TASK_FILE placeholder"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "{{TASK_NAME}}" "Has TASK_NAME placeholder"
}

test_browser_prompt_has_chrome_instructions() {
  echo "Test: test-browser.txt has browser automation instructions"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "browser automation" "Has browser automation instructions"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "\-\-chrome" "Has --chrome reference"
}

test_browser_prompt_has_dev_server_instructions() {
  echo "Test: test-browser.txt has dev server instructions"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "dev server" "Has dev server instructions"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "Start.*dev server" "Has start dev server instruction"
}

test_browser_prompt_has_output_requirements() {
  echo "Test: test-browser.txt has output requirements"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "Browser.*Status.*Complete" "Has status update instruction"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "Next Agent.*test-automated" "Has next agent instruction"
}

test_browser_prompt_has_failure_handling() {
  echo "Test: test-browser.txt has failure handling"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "5 attempts" "Has 5 attempt limit reference"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "Needs-Human" "Has Needs-Human reference"
}

test_browser_prompt_has_console_check() {
  echo "Test: test-browser.txt has console check instructions"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "console" "Mentions console"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "console error" "Has console error checking"
}

test_browser_prompt_references_implementation() {
  echo "Test: test-browser.txt references implementation section"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "Implementation" "References Implementation section"
}

test_browser_prompt_has_auto_detect() {
  echo "Test: test-browser.txt has auto-detect instructions"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "package.json" "Mentions package.json for command detection"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "dev.*start.*serve" "Has common dev script names"
}

test_browser_prompt_starts_own_server() {
  echo "Test: test-browser.txt emphasizes starting own server"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "Start Your Own Dev Server" "Has own server instructions"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "You own this server" "Emphasizes owning server instance"
}

test_browser_prompt_has_next_agent_rules() {
  echo "Test: test-browser.txt has explicit Next Agent rules"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "Next Agent field rules" "Has Next Agent field rules section"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "On SUCCESS.*test-automated" "Has success next agent rule"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "On FAILURE.*implement" "Has failure next agent rule"
  assert_file_contains "${PROMPTS_DIR}/test-browser.txt" "On BLOCKED.*Needs-Human" "Has blocked scenario rule"
}

# ============================================
# TEST-AUTOMATED PROMPT TESTS
# ============================================

test_automated_prompt_exists() {
  echo "Test: test-automated.txt exists"
  assert_file_exists "${PROMPTS_DIR}/test-automated.txt" "test-automated.txt exists"
}

test_automated_prompt_not_empty() {
  echo "Test: test-automated.txt is not empty"
  assert_file_not_empty "${PROMPTS_DIR}/test-automated.txt" "test-automated.txt has content"
}

test_automated_prompt_has_task_placeholders() {
  echo "Test: test-automated.txt has required placeholders"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "{{TASK_FILE}}" "Has TASK_FILE placeholder"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "{{TASK_NAME}}" "Has TASK_NAME placeholder"
}

test_automated_prompt_has_playwright_instructions() {
  echo "Test: test-automated.txt has Playwright instructions"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "Playwright" "Mentions Playwright"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "npx playwright test" "Has playwright test command"
}

test_automated_prompt_has_write_tests_instructions() {
  echo "Test: test-automated.txt has write tests instructions"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "Write Playwright Tests" "Has write tests section"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "test file" "Mentions test files"
}

test_automated_prompt_has_output_requirements() {
  echo "Test: test-automated.txt has output requirements"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "Automated.*Status.*Complete" "Has status update instruction"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "task Status.*Complete" "Has task complete instruction"
}

test_automated_prompt_has_failure_handling() {
  echo "Test: test-automated.txt has failure handling"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "5 attempts" "Has 5 attempt limit reference"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "Needs-Human" "Has Needs-Human reference"
}

test_automated_prompt_references_implementation() {
  echo "Test: test-automated.txt references implementation section"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "Implementation" "References Implementation section"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "Research" "References Research section"
}

test_automated_prompt_has_auto_detect() {
  echo "Test: test-automated.txt has auto-detect instructions"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "package.json" "Mentions package.json for command detection"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "test:e2e" "Has test:e2e script name"
}

test_automated_prompt_has_test_patterns() {
  echo "Test: test-automated.txt has test writing patterns"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "test.describe" "Has describe pattern"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "expect" "Has expect assertion"
}

test_automated_prompt_covers_scenarios() {
  echo "Test: test-automated.txt covers test scenarios"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "happy path" "Mentions happy path testing"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "edge cases" "Mentions edge case testing"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "error" "Mentions error scenario testing"
}

test_automated_prompt_final_step() {
  echo "Test: test-automated.txt marks task as complete"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "Next Agent.*none" "Has next agent none instruction"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "Status.*Complete" "Indicates task completion"
}

test_automated_prompt_has_next_agent_rules() {
  echo "Test: test-automated.txt has explicit Next Agent rules"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "Next Agent field rules" "Has Next Agent field rules section"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "On SUCCESS.*none.*Status.*Complete" "Has success next agent rule"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "On FAILURE.*implement" "Has failure next agent rule"
  assert_file_contains "${PROMPTS_DIR}/test-automated.txt" "On BLOCKED.*Needs-Human" "Has blocked scenario rule"
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
test_research_prompt_has_next_agent_rules

# Implement prompt tests
test_implement_prompt_exists
test_implement_prompt_not_empty
test_implement_prompt_has_task_placeholders
test_implement_prompt_has_reasoning_requirements
test_implement_prompt_has_output_requirements
test_implement_prompt_reads_research
test_implement_prompt_has_failure_handling
test_implement_prompt_has_next_agent_rules

# Test-typecheck prompt tests
test_typecheck_prompt_exists
test_typecheck_prompt_not_empty
test_typecheck_prompt_has_task_placeholders
test_typecheck_prompt_has_tsc_command
test_typecheck_prompt_has_output_requirements
test_typecheck_prompt_has_failure_handling
test_typecheck_prompt_has_auto_detect
test_typecheck_prompt_references_implementation
test_typecheck_prompt_has_next_agent_rules

# Test-terminal prompt tests
test_terminal_prompt_exists
test_terminal_prompt_not_empty
test_terminal_prompt_has_task_placeholders
test_terminal_prompt_has_dev_server_command
test_terminal_prompt_has_output_requirements
test_terminal_prompt_has_failure_handling
test_terminal_prompt_has_auto_detect
test_terminal_prompt_references_implementation
test_terminal_prompt_has_error_types
test_terminal_prompt_has_next_agent_rules

# Test-browser prompt tests
test_browser_prompt_exists
test_browser_prompt_not_empty
test_browser_prompt_has_task_placeholders
test_browser_prompt_has_chrome_instructions
test_browser_prompt_has_dev_server_instructions
test_browser_prompt_has_output_requirements
test_browser_prompt_has_failure_handling
test_browser_prompt_has_console_check
test_browser_prompt_references_implementation
test_browser_prompt_has_auto_detect
test_browser_prompt_starts_own_server
test_browser_prompt_has_next_agent_rules

# Test-automated prompt tests
test_automated_prompt_exists
test_automated_prompt_not_empty
test_automated_prompt_has_task_placeholders
test_automated_prompt_has_playwright_instructions
test_automated_prompt_has_write_tests_instructions
test_automated_prompt_has_output_requirements
test_automated_prompt_has_failure_handling
test_automated_prompt_references_implementation
test_automated_prompt_has_auto_detect
test_automated_prompt_has_test_patterns
test_automated_prompt_covers_scenarios
test_automated_prompt_final_step
test_automated_prompt_has_next_agent_rules

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
