# Brownfield Integration Feature

Enable Ralphy to be used in existing JavaScript/TypeScript projects (brownfield) via npm package, analyzing project context and applying changes.

## Workflow

1. `ralphy --init` - Analyze project, generate `memory.md`
2. `npx ralphy "task"` - Read `memory.md`, create worktree, execute task, apply changes

## Tasks

### Phase 1: Project Analysis (`ralphy --init`)

- [x] Detect project root (find package.json/tsconfig.json)
- [x] Parse package.json for dependencies, scripts, type
- [x] Parse tsconfig.json for paths, compiler options
- [x] Scan src/ directory structure
- [x] Detect test framework (Jest/Vitest)
- [x] Detect linting/config files (.eslintrc, prettierrc)
- [x] Analyze existing code patterns
- [x] Generate `memory.md` with project context
- [x] Handle edge cases (monorepos, nested projects)

### Phase 2: CLI Integration

- [x] Add `--init` flag to CLI
- [x] Add `memory.md` to .gitignore if not already
- [x] Validate `memory.md` exists before running tasks
- [x] Create worktree outside project root (temp directory)
- [x] Clone/copy project to worktree with memory.md
- [x] Apply Ralphy execution in worktree
- [x] Copy changes back to original project
- [x] Clean up worktree after completion

### Phase 3: Memory Context Usage

- [x] Load memory.md at task start
- [x] Parse memory.md for conventions (language, framework, patterns)
- [x] Include context in prompt generation
- [x] Reference conventions when applying changes
- [x] Fallback to default patterns if context missing
- [x] Add --memory flag for custom memory file path

### Phase 4: NPM Package

- [x] Create `package.json` for npm distribution
- [x] Set up build script (esbuild/rollup)
- [x] Export CLI entrypoint
- [x] Support `npx ralphy` invocation
- [x] Add bin field to package.json
- [ ] Publish to npm registry

### Phase 5: Testing

- [x] Test with Express project
- [x] Test with Next.js project
- [x] Test with plain Node.js project
- [x] Test with monorepo structure
- [x] Verify changes apply correctly
- [x] Test --memory flag with custom file

### Phase 5: Testing

- [ ] Test with Express project
- [ ] Test with Next.js project
- [ ] Test with plain Node.js project
- [ ] Test with monorepo structure
- [ ] Verify changes apply correctly
