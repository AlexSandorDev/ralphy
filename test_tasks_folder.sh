#!/usr/bin/env bash

# ============================================
# Tests for Tasks Folder Management Functions
# ============================================

set -euo pipefail

# Test utilities
TESTS_PASSED=0
TESTS_FAILED=0
TEST_TMP_DIR=""
TASKS_DIR=""
VERBOSE=false

# ============================================
# COPY OF TASKS FOLDER MANAGEMENT FUNCTIONS
# (To avoid sourcing the entire ralphy.sh file)
# ============================================

log_debug() {
  if [[ "$VERBOSE" == true ]]; then
    echo "[DEBUG] $*"
  fi
}

log_info() {
  echo "[INFO] $*"
}

# Initialize tasks folder if it doesn't exist
init_tasks_folder() {
  if [[ ! -d "$TASKS_DIR" ]]; then
    mkdir -p "$TASKS_DIR"
    log_debug "Created tasks folder: $TASKS_DIR"
  fi
}

# Generate the next task number (e.g., 001, 002, etc.)
get_next_task_number() {
  local max_num=0

  if [[ -d "$TASKS_DIR" ]]; then
    for file in "$TASKS_DIR"/*.md; do
      [[ -f "$file" ]] || continue
      local basename
      basename=$(basename "$file")
      # Extract number from filenames like "001-task-name.md" or "[Needs-Human] 001-task-name.md"
      local num
      num=$(echo "$basename" | grep -oE '[0-9]{3}' | head -1)
      if [[ -n "$num" ]] && [[ "$num" -gt "$max_num" ]]; then
        max_num=$num
      fi
    done
  fi

  printf "%03d" $((max_num + 1))
}

# Slugify task name for filename (lowercase, dashes, max 50 chars)
slugify_task_name() {
  local name="$1"
  echo "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g' | cut -c1-50
}

# Create a new task file
# Usage: create_task_file "Task description"
# Returns: path to the created task file
create_task_file() {
  local task_name="$1"
  local depends_on="${2:-}"  # Optional: task number this depends on

  init_tasks_folder

  local task_num
  task_num=$(get_next_task_number)
  local slug
  slug=$(slugify_task_name "$task_name")
  local filename="${task_num}-${slug}.md"
  local filepath="${TASKS_DIR}/${filename}"

  local status="In Progress"
  local next_agent="research"

  # If depends on another task, check if it's complete
  if [[ -n "$depends_on" ]]; then
    local dep_status
    dep_status=$(get_task_status "$depends_on")
    if [[ "$dep_status" != "Complete" ]]; then
      status="Waiting on Task ${depends_on}"
      filename="[Waiting on Task ${depends_on}] ${filename}"
      filepath="${TASKS_DIR}/${filename}"
    fi
  fi

  # Create the task file with template
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

# Get task file path by task number (handles status prefixes)
# Usage: get_task_file "001"
get_task_file() {
  local task_num="$1"

  if [[ ! -d "$TASKS_DIR" ]]; then
    return 1
  fi

  # Find file matching the task number (may have status prefix)
  for file in "$TASKS_DIR"/*"${task_num}"-*.md; do
    [[ -f "$file" ]] && echo "$file" && return 0
  done

  return 1
}

# Parse a task file and extract field value
# Usage: parse_task_field "filepath" "field_name"
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

# Get the status of a task by its number
get_task_status() {
  local task_num="$1"
  local filepath
  filepath=$(get_task_file "$task_num") || return 1
  parse_task_field "$filepath" "status"
}

# Update a field in a task file
# Usage: update_task_field "filepath" "field_name" "new_value"
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
# Usage: update_subtask_status "filepath" "subtask_name" "status" "attempts"
update_subtask_status() {
  local filepath="$1"
  local subtask="$2"
  local status="$3"
  local attempts="$4"

  [[ -f "$filepath" ]] || return 1

  # Escape special characters in subtask name for sed
  local escaped_subtask
  escaped_subtask=$(printf '%s\n' "$subtask" | sed 's/[[\.*^$/]/\\&/g')

  # Update the subtask line
  sed -i.bak "s/^### ${escaped_subtask} — Status:.*$/### ${subtask} — Status: ${status} | Attempts: ${attempts}\/5/" "$filepath"
  rm -f "${filepath}.bak"
}

# Rename task file with status prefix
# Usage: rename_task_with_status "filepath" "new_status_prefix"
# Example: rename_task_with_status "tasks/001-foo.md" "[Needs-Human]"
rename_task_with_status() {
  local filepath="$1"
  local prefix="$2"  # e.g., "[Needs-Human]" or "[Waiting on Task 001]" or "" to remove

  [[ -f "$filepath" ]] || return 1

  local dir
  dir=$(dirname "$filepath")
  local basename
  basename=$(basename "$filepath")

  # Remove any existing status prefix
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

# List all task files (sorted by number)
list_task_files() {
  [[ -d "$TASKS_DIR" ]] || return 0

  # List and sort by the numeric portion
  find "$TASKS_DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort -t'/' -k2 -V
}

# Get the next task file that needs work (not Complete, not Needs-Human, not Waiting)
get_next_pending_task_file() {
  local file status

  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    status=$(parse_task_field "$file" "status")

    # Skip completed tasks
    [[ "$status" == "Complete" ]] && continue

    # Skip tasks that need human intervention
    [[ "$status" == "Needs-Human" ]] && continue

    # Skip waiting tasks (check both status field and filename prefix)
    [[ "$status" == Waiting* ]] && continue
    [[ "$(basename "$file")" == "[Waiting"* ]] && continue

    echo "$file"
    return 0
  done < <(list_task_files)

  return 1
}

# Count tasks by status
count_tasks_by_status() {
  local target_status="$1"
  local count=0
  local file status

  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    status=$(parse_task_field "$file" "status")

    if [[ "$target_status" == "pending" ]]; then
      # Count non-complete tasks
      [[ "$status" != "Complete" ]] && ((count++))
    elif [[ "$target_status" == "complete" ]]; then
      [[ "$status" == "Complete" ]] && ((count++))
    elif [[ "$target_status" == "needs-human" ]]; then
      [[ "$status" == "Needs-Human" ]] && ((count++))
    elif [[ "$target_status" == "waiting" ]]; then
      [[ "$status" == Waiting* ]] && ((count++))
    fi
  done < <(list_task_files)

  echo "$count"
}

# Enforce 150-line limit on task file by truncating old content
enforce_task_line_limit() {
  local filepath="$1"
  local max_lines="${2:-150}"

  [[ -f "$filepath" ]] || return 1

  local line_count
  line_count=$(wc -l < "$filepath")

  if [[ "$line_count" -gt "$max_lines" ]]; then
    # Keep the header (first 6 lines with Status/Next Agent) and trim content sections
    local header
    header=$(head -6 "$filepath")

    # Get the last (max_lines - 6) lines of content
    local content
    content=$(tail -n +7 "$filepath" | tail -n $((max_lines - 6)))

    # Rewrite file
    echo "$header" > "$filepath"
    echo "$content" >> "$filepath"

    log_debug "Truncated task file to $max_lines lines: $filepath"
  fi
}

# Check if any tasks are waiting on a given task number
check_waiting_tasks() {
  local completed_task_num="$1"

  [[ -d "$TASKS_DIR" ]] || return 0

  for file in "$TASKS_DIR"/\[Waiting\ on\ Task\ "${completed_task_num}"\]*.md; do
    [[ -f "$file" ]] || continue

    # Remove the waiting prefix and update status
    local new_filepath
    new_filepath=$(rename_task_with_status "$file" "")
    update_task_field "$new_filepath" "status" "In Progress"
    log_info "Unblocked task: $(basename "$new_filepath")"
  done
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

assert_dir_exists() {
  local dirpath="$1"
  local msg="${2:-Directory should exist: $dirpath}"

  if [[ -d "$dirpath" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] $msg"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  [FAIL] $msg"
    echo "         Directory does not exist: $dirpath"
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

# ============================================
# TESTS
# ============================================

test_init_tasks_folder() {
  echo "Test: init_tasks_folder"
  setup

  [[ ! -d "$TASKS_DIR" ]] || { echo "  [FAIL] Tasks dir should not exist initially"; TESTS_FAILED=$((TESTS_FAILED + 1)); teardown; return 1; }

  init_tasks_folder

  assert_dir_exists "$TASKS_DIR" "Tasks folder created"

  init_tasks_folder
  assert_dir_exists "$TASKS_DIR" "Tasks folder still exists after second init"

  teardown
}

test_get_next_task_number() {
  echo "Test: get_next_task_number"
  setup

  local num
  num=$(get_next_task_number)
  assert_eq "001" "$num" "First task number should be 001"

  mkdir -p "$TASKS_DIR"
  touch "$TASKS_DIR/001-first-task.md"
  touch "$TASKS_DIR/002-second-task.md"

  num=$(get_next_task_number)
  assert_eq "003" "$num" "Next number after 002 should be 003"

  touch "$TASKS_DIR/[Needs-Human] 005-blocked-task.md"

  num=$(get_next_task_number)
  assert_eq "006" "$num" "Should handle status prefixes correctly"

  teardown
}

test_slugify_task_name() {
  echo "Test: slugify_task_name"
  setup

  local slug

  slug=$(slugify_task_name "Hello World")
  assert_eq "hello-world" "$slug" "Basic slugification"

  slug=$(slugify_task_name "Add user authentication!")
  assert_eq "add-user-authentication" "$slug" "Remove special chars"

  slug=$(slugify_task_name "  Multiple   Spaces  ")
  assert_eq "multiple-spaces" "$slug" "Handle multiple spaces"

  slug=$(slugify_task_name "UPPERCASE lowercase MixedCase")
  assert_eq "uppercase-lowercase-mixedcase" "$slug" "Handle case conversion"

  teardown
}

test_create_task_file() {
  echo "Test: create_task_file"
  setup

  local filepath
  filepath=$(create_task_file "Implement user login")

  assert_file_exists "$filepath" "Task file created"
  assert_contains "$filepath" "001-implement-user-login.md" "Filename format correct"

  local content
  content=$(cat "$filepath")
  assert_contains "$content" "# Task 001: Implement user login" "Title correct"
  assert_contains "$content" "## Status: In Progress" "Status correct"
  assert_contains "$content" "## Next Agent: research" "Next agent correct"
  assert_contains "$content" "### Research — Status: Pending | Attempts: 0/5" "Research section exists"
  assert_contains "$content" "### Implementation — Status: Pending | Attempts: 0/5" "Implementation section exists"
  assert_contains "$content" "### Test: Type Check" "Type check section exists"
  assert_contains "$content" "### Test: Browser" "Browser test section exists"

  local filepath2
  filepath2=$(create_task_file "Add logout button")
  assert_contains "$filepath2" "002-add-logout-button.md" "Second task gets 002"

  teardown
}

test_create_task_file_with_dependency() {
  echo "Test: create_task_file with dependency"
  setup

  local filepath1
  filepath1=$(create_task_file "First task")
  update_task_field "$filepath1" "status" "Complete"

  local filepath2
  filepath2=$(create_task_file "Second task" "001")
  assert_contains "$filepath2" "002-second-task.md" "Not waiting when dep is complete"

  local filepath3
  filepath3=$(create_task_file "Third task")
  update_task_field "$filepath3" "status" "In Progress"

  local filepath4
  filepath4=$(create_task_file "Fourth task" "003")
  assert_contains "$filepath4" "[Waiting on Task 003]" "Waiting prefix when dep incomplete"

  teardown
}

test_get_task_file() {
  echo "Test: get_task_file"
  setup

  create_task_file "Test task"

  local found
  found=$(get_task_file "001")
  assert_contains "$found" "001-test-task.md" "Found task by number"

  mkdir -p "$TASKS_DIR"
  mv "$TASKS_DIR/001-test-task.md" "$TASKS_DIR/[Needs-Human] 001-test-task.md"

  found=$(get_task_file "001")
  assert_contains "$found" "001-test-task.md" "Found prefixed task by number"

  teardown
}

test_parse_task_field() {
  echo "Test: parse_task_field"
  setup

  local filepath
  filepath=$(create_task_file "Parse test task")

  local status
  status=$(parse_task_field "$filepath" "status")
  assert_eq "In Progress" "$status" "Parse status"

  local next_agent
  next_agent=$(parse_task_field "$filepath" "next_agent")
  assert_eq "research" "$next_agent" "Parse next_agent"

  local task_name
  task_name=$(parse_task_field "$filepath" "task_name")
  assert_eq "Parse test task" "$task_name" "Parse task_name"

  local task_num
  task_num=$(parse_task_field "$filepath" "task_number")
  assert_eq "001" "$task_num" "Parse task_number"

  teardown
}

test_update_task_field() {
  echo "Test: update_task_field"
  setup

  local filepath
  filepath=$(create_task_file "Update test")

  update_task_field "$filepath" "status" "Complete"
  local status
  status=$(parse_task_field "$filepath" "status")
  assert_eq "Complete" "$status" "Status updated"

  update_task_field "$filepath" "next_agent" "implement"
  local next_agent
  next_agent=$(parse_task_field "$filepath" "next_agent")
  assert_eq "implement" "$next_agent" "Next agent updated"

  teardown
}

test_update_subtask_status() {
  echo "Test: update_subtask_status"
  setup

  local filepath
  filepath=$(create_task_file "Subtask test")

  update_subtask_status "$filepath" "Research" "In Progress" "1"

  local content
  content=$(cat "$filepath")
  assert_contains "$content" "### Research — Status: In Progress | Attempts: 1/5" "Subtask status updated"

  update_subtask_status "$filepath" "Implementation" "Complete" "3"
  content=$(cat "$filepath")
  assert_contains "$content" "### Implementation — Status: Complete | Attempts: 3/5" "Implementation status updated"

  teardown
}

test_rename_task_with_status() {
  echo "Test: rename_task_with_status"
  setup

  local filepath
  filepath=$(create_task_file "Rename test")

  local new_path
  new_path=$(rename_task_with_status "$filepath" "[Needs-Human]")
  assert_contains "$new_path" "[Needs-Human] 001-rename-test.md" "Needs-Human prefix added"
  assert_file_exists "$new_path" "Renamed file exists"

  new_path=$(rename_task_with_status "$new_path" "[Waiting on Task 002]")
  assert_contains "$new_path" "[Waiting on Task 002] 001-rename-test.md" "Prefix changed"

  new_path=$(rename_task_with_status "$new_path" "")
  assert_contains "$new_path" "001-rename-test.md" "Prefix removed"
  [[ "$new_path" != *"["* ]] || { echo "  [FAIL] Should not have brackets"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

  teardown
}

test_list_task_files() {
  echo "Test: list_task_files"
  setup

  local files
  files=$(list_task_files)
  assert_eq "" "$files" "No files initially"

  create_task_file "First"
  create_task_file "Second"
  create_task_file "Third"

  files=$(list_task_files | wc -l | tr -d ' ')
  assert_eq "3" "$files" "Lists all 3 files"

  teardown
}

test_get_next_pending_task_file() {
  echo "Test: get_next_pending_task_file"
  setup

  local next
  next=$(get_next_pending_task_file 2>/dev/null || echo "NONE")
  assert_eq "NONE" "$next" "No pending tasks initially"

  local task1
  task1=$(create_task_file "Complete task")
  update_task_field "$task1" "status" "Complete"

  local task2
  task2=$(create_task_file "Needs human task")
  update_task_field "$task2" "status" "Needs-Human"

  local task3
  task3=$(create_task_file "In progress task")

  next=$(get_next_pending_task_file)
  assert_contains "$next" "003-in-progress-task.md" "Gets first non-complete, non-human task"

  teardown
}

test_count_tasks_by_status() {
  echo "Test: count_tasks_by_status"
  setup

  local task1
  task1=$(create_task_file "Task 1")
  update_task_field "$task1" "status" "Complete"

  local task2
  task2=$(create_task_file "Task 2")
  update_task_field "$task2" "status" "Complete"

  local task3
  task3=$(create_task_file "Task 3")
  update_task_field "$task3" "status" "In Progress"

  local task4
  task4=$(create_task_file "Task 4")
  update_task_field "$task4" "status" "Needs-Human"

  local task5
  task5=$(create_task_file "Task 5")
  update_task_field "$task5" "status" "Waiting on Task 001"

  local count
  count=$(count_tasks_by_status "complete")
  assert_eq "2" "$count" "2 complete tasks"

  count=$(count_tasks_by_status "pending")
  assert_eq "3" "$count" "3 pending tasks (non-complete)"

  count=$(count_tasks_by_status "needs-human")
  assert_eq "1" "$count" "1 needs-human task"

  count=$(count_tasks_by_status "waiting")
  assert_eq "1" "$count" "1 waiting task"

  teardown
}

test_enforce_task_line_limit() {
  echo "Test: enforce_task_line_limit"
  setup

  local filepath
  filepath=$(create_task_file "Line limit test")

  for i in {1..200}; do
    echo "Line $i of content" >> "$filepath"
  done

  local line_count
  line_count=$(wc -l < "$filepath")
  [[ "$line_count" -gt 150 ]] || { echo "  [FAIL] Should have more than 150 lines"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

  enforce_task_line_limit "$filepath" 150

  line_count=$(wc -l < "$filepath")
  if [[ "$line_count" -le 150 ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] Line limit enforced"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  [FAIL] Should be <= 150 lines, got $line_count"
  fi

  local content
  content=$(cat "$filepath")
  assert_contains "$content" "# Task 001: Line limit test" "Header preserved after truncation"

  teardown
}

test_check_waiting_tasks() {
  echo "Test: check_waiting_tasks"
  setup

  local task1
  task1=$(create_task_file "First task")

  local task2
  task2=$(create_task_file "Second task" "001")

  assert_contains "$(basename "$task2")" "[Waiting on Task 001]" "Task 2 is waiting on Task 001"

  update_task_field "$task1" "status" "Complete"

  check_waiting_tasks "001"

  local unblocked_file
  unblocked_file=$(get_task_file "002")
  if [[ "$(basename "$unblocked_file")" != "[Waiting"* ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] Waiting prefix removed"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  [FAIL] Should not have waiting prefix"
  fi

  local status
  status=$(parse_task_field "$unblocked_file" "status")
  assert_eq "In Progress" "$status" "Status changed to In Progress"

  teardown
}

# ============================================
# RUN ALL TESTS
# ============================================

echo "============================================"
echo "Running Tasks Folder Management Tests"
echo "============================================"
echo ""

test_init_tasks_folder
test_get_next_task_number
test_slugify_task_name
test_create_task_file
test_create_task_file_with_dependency
test_get_task_file
test_parse_task_field
test_update_task_field
test_update_subtask_status
test_rename_task_with_status
test_list_task_files
test_get_next_pending_task_file
test_count_tasks_by_status
test_enforce_task_line_limit
test_check_waiting_tasks

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
