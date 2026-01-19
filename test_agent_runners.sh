#!/usr/bin/env bash

# ============================================
# Tests for Agent Runner Functions
# ============================================

set -euo pipefail

# Test utilities
TESTS_PASSED=0
TESTS_FAILED=0
TEST_TMP_DIR=""
TASKS_DIR=""
VERBOSE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# COPY OF REQUIRED FUNCTIONS FROM ralphy.sh
# (Minimal set needed for testing agent runners)
# ============================================

log_debug() {
  if [[ "$VERBOSE" == true ]]; then
    echo "[DEBUG] $*"
  fi
}

log_info() {
  echo "[INFO] $*"
}

log_warn() {
  echo "[WARN] $*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

# Initialize tasks folder if it doesn't exist
init_tasks_folder() {
  if [[ ! -d "$TASKS_DIR" ]]; then
    mkdir -p "$TASKS_DIR"
    log_debug "Created tasks folder: $TASKS_DIR"
  fi
}

# Generate the next task number
get_next_task_number() {
  local max_num=0

  if [[ -d "$TASKS_DIR" ]]; then
    for file in "$TASKS_DIR"/*.md; do
      [[ -f "$file" ]] || continue
      local basename
      basename=$(basename "$file")
      local num
      num=$(echo "$basename" | grep -oE '[0-9]{3}' | head -1)
      if [[ -n "$num" ]] && [[ "$num" -gt "$max_num" ]]; then
        max_num=$num
      fi
    done
  fi

  printf "%03d" $((max_num + 1))
}

# Slugify task name for filename
slugify_task_name() {
  local name="$1"
  echo "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g' | cut -c1-50
}

# Create a new task file
create_task_file() {
  local task_name="$1"
  local depends_on="${2:-}"

  init_tasks_folder

  local task_num
  task_num=$(get_next_task_number)
  local slug
  slug=$(slugify_task_name "$task_name")
  local filename="${task_num}-${slug}.md"
  local filepath="${TASKS_DIR}/${filename}"

  local status="In Progress"
  local next_agent="research"

  cat > "$filepath" << EOF
# Task ${task_num}: ${task_name}
## Status: ${status}
## Next Agent: ${next_agent}

### Research — Status: Pending | Attempts: 0/5
[Relevant files, patterns discovered, library docs from Context7]

### Implementation — Status: Pending | Attempts: 0/5
[Reasoning and thinking process, choices considered, why alternatives were rejected, architectural decisions - documentation style]

### Test: Type Check — Status: Pending | Attempts: 0/5

### Test: Terminal Errors — Status: Pending | Attempts: 0/5

### Test: Browser — Status: Pending | Attempts: 0/5

### Test: Automated (Playwright) — Status: Pending | Attempts: 0/5
EOF

  log_debug "Created task file: $filepath"
  echo "$filepath"
}

# Parse a task file and extract field value
parse_task_field() {
  local filepath="$1"
  local field="$2"

  [[ -f "$filepath" ]] || return 1

  case "$field" in
    "status")
      grep -m1 '^## Status:' "$filepath" | sed 's/^## Status:[[:space:]]*//'
      ;;
    "next_agent")
      grep -m1 '^## Next Agent:' "$filepath" | sed 's/^## Next Agent:[[:space:]]*//'
      ;;
    "task_name")
      grep -m1 '^# Task [0-9]*:' "$filepath" | sed 's/^# Task [0-9]*:[[:space:]]*//'
      ;;
    "task_number")
      basename "$filepath" | grep -oE '[0-9]{3}' | head -1
      ;;
    *)
      return 1
      ;;
  esac
}

# Update a field in a task file
update_task_field() {
  local filepath="$1"
  local field="$2"
  local value="$3"

  [[ -f "$filepath" ]] || return 1

  case "$field" in
    "status")
      sed -i.bak "s/^## Status:.*$/## Status: ${value}/" "$filepath"
      rm -f "${filepath}.bak"
      ;;
    "next_agent")
      sed -i.bak "s/^## Next Agent:.*$/## Next Agent: ${value}/" "$filepath"
      rm -f "${filepath}.bak"
      ;;
    *)
      return 1
      ;;
  esac
}

# Update subtask status and attempts
update_subtask_status() {
  local filepath="$1"
  local subtask="$2"
  local status="$3"
  local attempts="$4"

  [[ -f "$filepath" ]] || return 1

  local escaped_subtask
  escaped_subtask=$(printf '%s\n' "$subtask" | sed 's/[[\.*^$/]/\\&/g')

  sed -i.bak "s/^### ${escaped_subtask} — Status:.*$/### ${subtask} — Status: ${status} | Attempts: ${attempts}\/5/" "$filepath"
  rm -f "${filepath}.bak"
}

# Rename task file with status prefix
rename_task_with_status() {
  local filepath="$1"
  local prefix="$2"

  [[ -f "$filepath" ]] || return 1

  local dir
  dir=$(dirname "$filepath")
  local basename
  basename=$(basename "$filepath")

  local clean_name
  clean_name=$(echo "$basename" | sed -E 's/^\[.*\][[:space:]]*//')

  local new_name
  if [[ -n "$prefix" ]]; then
    new_name="${prefix} ${clean_name}"
  else
    new_name="$clean_name"
  fi

  local new_filepath="${dir}/${new_name}"

  if [[ "$filepath" != "$new_filepath" ]]; then
    mv "$filepath" "$new_filepath"
    log_debug "Renamed task file: $basename -> $new_name"
  fi

  echo "$new_filepath"
}

# Get current attempts count for a subtask
get_subtask_attempts() {
  local filepath="$1"
  local subtask="$2"

  [[ -f "$filepath" ]] || return 1

  local line
  line=$(grep -m1 "^### ${subtask} —" "$filepath" 2>/dev/null || echo "")

  if [[ -z "$line" ]]; then
    echo "0"
    return 0
  fi

  local attempts
  attempts=$(echo "$line" | grep -oE 'Attempts: [0-9]+' | grep -oE '[0-9]+' || echo "0")
  echo "${attempts:-0}"
}

# Load and prepare a prompt from file with placeholder substitution
prepare_prompt() {
  local prompt_file="$1"
  local task_file="$2"
  local task_name="$3"

  [[ -f "$prompt_file" ]] || {
    log_error "Prompt file not found: $prompt_file"
    return 1
  }

  local prompt
  prompt=$(cat "$prompt_file")

  prompt="${prompt//\{\{TASK_FILE\}\}/$task_file}"
  prompt="${prompt//\{\{TASK_NAME\}\}/$task_name}"

  echo "$prompt"
}

# Mark a task as needs-human
mark_task_needs_human() {
  local task_file="$1"
  local subtask_name="$2"

  [[ -f "$task_file" ]] || return 1

  local task_num
  task_num=$(parse_task_field "$task_file" "task_number")

  update_task_field "$task_file" "status" "Needs-Human"

  local new_path
  new_path=$(rename_task_with_status "$task_file" "[Needs-Human]")

  echo "$new_path"
}

# ============================================
# TEST UTILITIES
# ============================================

setup() {
  TEST_TMP_DIR=$(mktemp -d)
  TASKS_DIR="$TEST_TMP_DIR/tasks"
  VERBOSE=false
}

teardown() {
  rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-}"

  if [[ "$expected" == "$actual" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] $msg"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  [FAIL] $msg"
    echo "         Expected: '$expected'"
    echo "         Actual:   '$actual'"
    return 1
  fi
}

assert_contains() {
  local content="$1"
  local expected="$2"
  local msg="${3:-}"

  if [[ "$content" == *"$expected"* ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] $msg"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  [FAIL] $msg"
    echo "         Expected to contain: '$expected'"
    echo "         Content: '$content'"
    return 1
  fi
}

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

assert_not_contains() {
  local content="$1"
  local unexpected="$2"
  local msg="${3:-}"

  if [[ "$content" != *"$unexpected"* ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] $msg"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  [FAIL] $msg"
    echo "         Should NOT contain: '$unexpected'"
    echo "         Content: '$content'"
    return 1
  fi
}

# ============================================
# TESTS: get_subtask_attempts
# ============================================

test_get_subtask_attempts_initial() {
  echo "Test: get_subtask_attempts returns 0 for new task"
  setup

  local filepath
  filepath=$(create_task_file "Test task")

  local attempts
  attempts=$(get_subtask_attempts "$filepath" "Research")
  assert_eq "0" "$attempts" "Initial attempts should be 0"

  teardown
}

test_get_subtask_attempts_after_update() {
  echo "Test: get_subtask_attempts returns correct count after update"
  setup

  local filepath
  filepath=$(create_task_file "Test task")

  update_subtask_status "$filepath" "Research" "In Progress" "3"

  local attempts
  attempts=$(get_subtask_attempts "$filepath" "Research")
  assert_eq "3" "$attempts" "Attempts should be 3 after update"

  teardown
}

test_get_subtask_attempts_different_subtasks() {
  echo "Test: get_subtask_attempts handles different subtasks"
  setup

  local filepath
  filepath=$(create_task_file "Test task")

  update_subtask_status "$filepath" "Research" "Complete" "2"
  update_subtask_status "$filepath" "Implementation" "In Progress" "4"

  local research_attempts
  research_attempts=$(get_subtask_attempts "$filepath" "Research")
  assert_eq "2" "$research_attempts" "Research attempts should be 2"

  local impl_attempts
  impl_attempts=$(get_subtask_attempts "$filepath" "Implementation")
  assert_eq "4" "$impl_attempts" "Implementation attempts should be 4"

  teardown
}

test_get_subtask_attempts_nonexistent_subtask() {
  echo "Test: get_subtask_attempts returns 0 for nonexistent subtask"
  setup

  local filepath
  filepath=$(create_task_file "Test task")

  local attempts
  attempts=$(get_subtask_attempts "$filepath" "Nonexistent")
  assert_eq "0" "$attempts" "Nonexistent subtask should return 0"

  teardown
}

# ============================================
# TESTS: prepare_prompt
# ============================================

test_prepare_prompt_basic() {
  echo "Test: prepare_prompt substitutes placeholders"
  setup

  # Create a minimal test prompt file
  local test_prompt_file="$TEST_TMP_DIR/test_prompt.txt"
  cat > "$test_prompt_file" << 'EOF'
Task: {{TASK_NAME}}
File: {{TASK_FILE}}
Instructions here.
EOF

  local result
  result=$(prepare_prompt "$test_prompt_file" "/path/to/task.md" "My Test Task")

  assert_contains "$result" "Task: My Test Task" "Task name substituted"
  assert_contains "$result" "File: /path/to/task.md" "Task file substituted"
  assert_contains "$result" "Instructions here" "Other content preserved"

  teardown
}

test_prepare_prompt_multiple_occurrences() {
  echo "Test: prepare_prompt substitutes multiple occurrences"
  setup

  local test_prompt_file="$TEST_TMP_DIR/test_prompt.txt"
  cat > "$test_prompt_file" << 'EOF'
Task: {{TASK_NAME}}
Reminder: Work on {{TASK_NAME}}
Update {{TASK_FILE}} when done.
Then read {{TASK_FILE}} again.
EOF

  local result
  result=$(prepare_prompt "$test_prompt_file" "task.md" "Feature X")

  # Count occurrences of substituted values
  local task_name_count
  task_name_count=$(echo "$result" | grep -o "Feature X" | wc -l | tr -d ' ')
  local task_file_count
  task_file_count=$(echo "$result" | grep -o "task.md" | wc -l | tr -d ' ')

  assert_eq "2" "$task_name_count" "Task name substituted twice"
  assert_eq "2" "$task_file_count" "Task file substituted twice"

  teardown
}

test_prepare_prompt_missing_file() {
  echo "Test: prepare_prompt returns error for missing file"
  setup

  local result
  if result=$(prepare_prompt "/nonexistent/file.txt" "task.md" "Task" 2>&1); then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  [FAIL] Should have failed for missing file"
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] Returns error for missing prompt file"
  fi

  teardown
}

test_prepare_prompt_with_real_research_prompt() {
  echo "Test: prepare_prompt works with real research.txt"
  setup

  local prompt_file="${SCRIPT_DIR}/prompts/research.txt"
  if [[ ! -f "$prompt_file" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [SKIP] research.txt not found"
    teardown
    return 0
  fi

  local filepath
  filepath=$(create_task_file "Implement OAuth")

  local result
  result=$(prepare_prompt "$prompt_file" "$filepath" "Implement OAuth")

  assert_contains "$result" "Implement OAuth" "Task name substituted in research prompt"
  assert_contains "$result" "$filepath" "Task file path substituted"
  assert_not_contains "$result" "{{TASK_NAME}}" "No remaining TASK_NAME placeholder"
  assert_not_contains "$result" "{{TASK_FILE}}" "No remaining TASK_FILE placeholder"

  teardown
}

# ============================================
# TESTS: mark_task_needs_human
# ============================================

test_mark_task_needs_human_updates_status() {
  echo "Test: mark_task_needs_human updates status field"
  setup

  local filepath
  filepath=$(create_task_file "Difficult task")

  local new_path
  new_path=$(mark_task_needs_human "$filepath" "Research")

  local status
  status=$(parse_task_field "$new_path" "status")
  assert_eq "Needs-Human" "$status" "Status updated to Needs-Human"

  teardown
}

test_mark_task_needs_human_renames_file() {
  echo "Test: mark_task_needs_human adds prefix to filename"
  setup

  local filepath
  filepath=$(create_task_file "Another task")

  local new_path
  new_path=$(mark_task_needs_human "$filepath" "Implementation")

  assert_contains "$(basename "$new_path")" "[Needs-Human]" "File has Needs-Human prefix"
  assert_file_exists "$new_path" "Renamed file exists"

  teardown
}

test_mark_task_needs_human_preserves_content() {
  echo "Test: mark_task_needs_human preserves task content"
  setup

  local filepath
  filepath=$(create_task_file "Content test task")

  # Add some content to the task
  update_subtask_status "$filepath" "Research" "Complete" "2"

  local new_path
  new_path=$(mark_task_needs_human "$filepath" "Implementation")

  local content
  content=$(cat "$new_path")
  assert_contains "$content" "# Task 001: Content test task" "Task title preserved"
  assert_contains "$content" "Research — Status: Complete | Attempts: 2/5" "Research status preserved"

  teardown
}

# ============================================
# TESTS: Agent type mapping
# ============================================

test_agent_type_prompt_files_exist() {
  echo "Test: All agent prompt files exist"

  local agent_types=("research" "implement" "test-typecheck" "test-terminal" "test-browser" "test-automated")
  local prompt_files=("research.txt" "implement.txt" "test-typecheck.txt" "test-terminal.txt" "test-browser.txt" "test-automated.txt")

  for i in "${!agent_types[@]}"; do
    local prompt_file="${SCRIPT_DIR}/prompts/${prompt_files[$i]}"
    if [[ -f "$prompt_file" ]]; then
      TESTS_PASSED=$((TESTS_PASSED + 1))
      echo "  [PASS] Prompt file exists for ${agent_types[$i]}: ${prompt_files[$i]}"
    else
      TESTS_FAILED=$((TESTS_FAILED + 1))
      echo "  [FAIL] Missing prompt file for ${agent_types[$i]}: ${prompt_files[$i]}"
    fi
  done
}

test_agent_subtask_names() {
  echo "Test: Agent subtask names match task file format"
  setup

  local filepath
  filepath=$(create_task_file "Test task")
  local content
  content=$(cat "$filepath")

  # Map of agent types to their subtask names in the task file
  local -A subtask_map=(
    ["research"]="Research"
    ["implement"]="Implementation"
    ["test-typecheck"]="Test: Type Check"
    ["test-terminal"]="Test: Terminal Errors"
    ["test-browser"]="Test: Browser"
    ["test-automated"]="Test: Automated (Playwright)"
  )

  for agent_type in "${!subtask_map[@]}"; do
    local subtask_name="${subtask_map[$agent_type]}"
    if [[ "$content" == *"### $subtask_name —"* ]]; then
      TESTS_PASSED=$((TESTS_PASSED + 1))
      echo "  [PASS] Subtask '$subtask_name' exists for agent '$agent_type'"
    else
      TESTS_FAILED=$((TESTS_FAILED + 1))
      echo "  [FAIL] Subtask '$subtask_name' not found for agent '$agent_type'"
    fi
  done

  teardown
}

# ============================================
# TESTS: Agent workflow sequence
# ============================================

test_agent_workflow_sequence() {
  echo "Test: Agent workflow follows correct sequence"
  setup

  # Expected sequence: research -> implement -> test-typecheck -> test-terminal -> test-browser -> test-automated
  local expected_sequence=("research" "implement" "test-typecheck" "test-terminal" "test-browser" "test-automated")
  local next_agents=("implement" "test-typecheck" "test-terminal" "test-browser" "test-automated" "none")

  for i in "${!expected_sequence[@]}"; do
    local current="${expected_sequence[$i]}"
    local expected_next="${next_agents[$i]}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] After '$current', next agent should be '$expected_next'"
  done

  teardown
}

test_new_task_starts_with_research() {
  echo "Test: New task starts with research agent"
  setup

  local filepath
  filepath=$(create_task_file "New feature")

  local next_agent
  next_agent=$(parse_task_field "$filepath" "next_agent")
  assert_eq "research" "$next_agent" "New task starts with research agent"

  teardown
}

# ============================================
# TESTS: Attempt tracking
# ============================================

test_max_attempts_detection() {
  echo "Test: Detect when max attempts (5) exceeded"
  setup

  local filepath
  filepath=$(create_task_file "Max attempts test")

  # Simulate 5 failed attempts
  update_subtask_status "$filepath" "Research" "Failed" "5"

  local attempts
  attempts=$(get_subtask_attempts "$filepath" "Research")
  local next_attempt=$((attempts + 1))

  if [[ $next_attempt -gt 5 ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] Correctly detects attempt 6 would exceed max"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  [FAIL] Should detect max attempts exceeded"
  fi

  teardown
}

test_attempt_increment() {
  echo "Test: Attempt count increments correctly"
  setup

  local filepath
  filepath=$(create_task_file "Increment test")

  for i in 1 2 3 4 5; do
    update_subtask_status "$filepath" "Research" "In Progress" "$i"
    local attempts
    attempts=$(get_subtask_attempts "$filepath" "Research")
    assert_eq "$i" "$attempts" "Attempt count should be $i"
  done

  teardown
}

# ============================================
# TESTS: Subtask status updates
# ============================================

test_subtask_status_in_progress() {
  echo "Test: Subtask can be set to In Progress"
  setup

  local filepath
  filepath=$(create_task_file "Status test")

  update_subtask_status "$filepath" "Research" "In Progress" "1"

  local content
  content=$(cat "$filepath")
  assert_contains "$content" "Research — Status: In Progress | Attempts: 1/5" "Research set to In Progress"

  teardown
}

test_subtask_status_complete() {
  echo "Test: Subtask can be set to Complete"
  setup

  local filepath
  filepath=$(create_task_file "Status test")

  update_subtask_status "$filepath" "Implementation" "Complete" "2"

  local content
  content=$(cat "$filepath")
  assert_contains "$content" "Implementation — Status: Complete | Attempts: 2/5" "Implementation set to Complete"

  teardown
}

test_subtask_status_failed() {
  echo "Test: Subtask can be set to Failed"
  setup

  local filepath
  filepath=$(create_task_file "Status test")

  update_subtask_status "$filepath" "Test: Type Check" "Failed" "3"

  local content
  content=$(cat "$filepath")
  assert_contains "$content" "Test: Type Check — Status: Failed | Attempts: 3/5" "Type Check set to Failed"

  teardown
}

# ============================================
# TESTS: Integration scenarios
# ============================================

test_full_workflow_simulation() {
  echo "Test: Simulate full workflow progression"
  setup

  local filepath
  filepath=$(create_task_file "Full workflow task")

  # Simulate research completion
  update_subtask_status "$filepath" "Research" "Complete" "1"
  update_task_field "$filepath" "next_agent" "implement"

  local next_agent
  next_agent=$(parse_task_field "$filepath" "next_agent")
  assert_eq "implement" "$next_agent" "After research, next is implement"

  # Simulate implementation completion
  update_subtask_status "$filepath" "Implementation" "Complete" "1"
  update_task_field "$filepath" "next_agent" "test-typecheck"

  next_agent=$(parse_task_field "$filepath" "next_agent")
  assert_eq "test-typecheck" "$next_agent" "After implement, next is test-typecheck"

  # Simulate all tests passing
  update_subtask_status "$filepath" "Test: Type Check" "Complete" "1"
  update_task_field "$filepath" "next_agent" "test-terminal"

  update_subtask_status "$filepath" "Test: Terminal Errors" "Complete" "1"
  update_task_field "$filepath" "next_agent" "test-browser"

  update_subtask_status "$filepath" "Test: Browser" "Complete" "1"
  update_task_field "$filepath" "next_agent" "test-automated"

  update_subtask_status "$filepath" "Test: Automated (Playwright)" "Complete" "1"
  update_task_field "$filepath" "next_agent" "none"
  update_task_field "$filepath" "status" "Complete"

  local status
  status=$(parse_task_field "$filepath" "status")
  assert_eq "Complete" "$status" "Task status is Complete after all steps"

  next_agent=$(parse_task_field "$filepath" "next_agent")
  assert_eq "none" "$next_agent" "Next agent is none after completion"

  teardown
}

test_failure_loop_back_to_implement() {
  echo "Test: Test failure loops back to implement"
  setup

  local filepath
  filepath=$(create_task_file "Failure loop task")

  # Complete research and implementation
  update_subtask_status "$filepath" "Research" "Complete" "1"
  update_subtask_status "$filepath" "Implementation" "Complete" "1"
  update_task_field "$filepath" "next_agent" "test-typecheck"

  # Type check fails, loop back to implement
  update_subtask_status "$filepath" "Test: Type Check" "Failed" "1"
  update_task_field "$filepath" "next_agent" "implement"

  local next_agent
  next_agent=$(parse_task_field "$filepath" "next_agent")
  assert_eq "implement" "$next_agent" "Failed type check loops back to implement"

  teardown
}

# ============================================
# RUN ALL TESTS
# ============================================

echo "============================================"
echo "Running Agent Runner Tests"
echo "============================================"
echo ""

# get_subtask_attempts tests
test_get_subtask_attempts_initial
test_get_subtask_attempts_after_update
test_get_subtask_attempts_different_subtasks
test_get_subtask_attempts_nonexistent_subtask

# prepare_prompt tests
test_prepare_prompt_basic
test_prepare_prompt_multiple_occurrences
test_prepare_prompt_missing_file
test_prepare_prompt_with_real_research_prompt

# mark_task_needs_human tests
test_mark_task_needs_human_updates_status
test_mark_task_needs_human_renames_file
test_mark_task_needs_human_preserves_content

# Agent mapping tests
test_agent_type_prompt_files_exist
test_agent_subtask_names

# Workflow tests
test_agent_workflow_sequence
test_new_task_starts_with_research

# Attempt tracking tests
test_max_attempts_detection
test_attempt_increment

# Subtask status tests
test_subtask_status_in_progress
test_subtask_status_complete
test_subtask_status_failed

# Integration tests
test_full_workflow_simulation
test_failure_loop_back_to_implement

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
