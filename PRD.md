# PRD: Task-Aware Context System for Ralphy

## Overview

Replace shared `progress.txt` with individual task files in `tasks/` folder. Each task has 6 subtasks (Research → Implement → 4 Tests) run by specialized agents. Files track attempts, reasoning, and state—allowing human intervention without stopping the loop.

## Key Changes

| Current | New |
|---------|-----|
| Shared `progress.txt` | Per-task `tasks/001-task-name.md` |
| Freeform workflow | Enforced: Research → Implement → Test (x4) |
| 3 retries at task level | 5 attempts per subtask |
| Move on after failure | Mark `[Needs-Human]`, user can edit and resume |
| No dependencies | `[Waiting on Task X]` blocks dependent tasks |
| One generic prompt | 6 specialized agent prompts |
| Loop decides next step | Each agent outputs which agent runs next |

## Task File Format

```markdown
# Task 001: [Name]
## Status: In Progress | Needs-Human | Waiting on Task X | Complete
## Next Agent: research | implement | test-typecheck | test-terminal | test-browser | test-automated

### Research — Status: Complete | Attempts: 1/5
[Relevant files, patterns discovered, library docs from Context7]

### Implementation — Status: In Progress | Attempts: 2/5
[Reasoning and thinking process, choices considered, why alternatives were rejected, architectural decisions - documentation style]

### Test: Type Check — Status: Pending | Attempts: 0/5
### Test: Terminal Errors — Status: Pending | Attempts: 0/5
### Test: Browser — Status: Pending | Attempts: 0/5
### Test: Automated (Playwright) — Status: Pending | Attempts: 0/5
```

**Constraints**: Max 150 lines. Agent curates content, removes obsolete info.
**Human edits**: User can modify ANY part of the file to add/correct context.

## 6 Specialized Agents

1. **Research Agent** — Explore codebase + Context7 MCP for library docs
2. **Implementation Agent** — Write code; document reasoning, choices considered, why alternatives rejected
3. **Type Check Agent** — Run `tsc --noEmit` or detected typecheck command, fix errors
4. **Terminal Error Agent** — Start dev server, check for runtime/compile errors, fix them
5. **Browser Agent** — Start its own dev server, use app via `--chrome`, test actual functionality + check console
6. **Automated Test Agent** — Write Playwright tests for the feature, then run them

## Workflow

1. Loop reads task file, gets `Next Agent` field
2. Runs that specific agent
3. Agent does work, updates task file, sets `Next Agent` for what should run next
4. **All tests pass?** → Agent sets status to Complete
5. **Test fails?** → Agent sets `Next Agent` back to implement (or research)
6. **5 attempts on any subtask?** → Mark `[Needs-Human]`, purple warning, move to next task
7. **Dependent task blocked?** → Rename to `[Waiting on Task X] 002-name.md`

## Human Intervention

1. Purple warning: `⚠️ NEEDS HUMAN: Task 001 - Subtask: Browser (5/5 failed)`
2. User edits task file (any section), removes `[Needs-Human]` from filename
3. Agent picks up changes on next iteration, resumes from `Next Agent`

## Tasks

- [x] Create tasks/ folder management functions
- [x] Implement task file CRUD (create, parse, update, rename with status prefix)
- [x] Create prompts/research.txt with Context7 MCP instructions
- [x] Create prompts/implement.txt (document reasoning, not just changes)
- [x] Create prompts/test-typecheck.txt
- [ ] Create prompts/test-terminal.txt (start dev server, check errors)
- [ ] Create prompts/test-browser.txt (start server, test functionality via --chrome)
- [ ] Create prompts/test-automated.txt (write Playwright tests, then run)
- [ ] Implement 6 agent runner functions that read/update task files
- [ ] Each agent outputs Next Agent field for loop to follow
- [ ] Implement 5-attempt failure handling with [Needs-Human] marking
- [ ] Implement purple terminal warning for Needs-Human
- [ ] Implement dependency checking with [Waiting on Task X]
- [ ] Auto-detect commands (typecheck, dev server)
- [ ] Implement 150-line limit enforcement
- [ ] Modify main loop to read Next Agent and dispatch accordingly
- [ ] Test end-to-end workflow
