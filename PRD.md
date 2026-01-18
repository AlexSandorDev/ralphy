# Brownfield Integration Feature

Enable Ralphy to be used in existing JavaScript/TypeScript projects (brownfield) via npm package, analyzing project context and applying changes.

## Workflow

1. `ralphy --init` - Analyze project, generate `memory.md`
2. `npx ralphy "task"` - Read `memory.md`, create worktree, execute task, apply changes

## Tasks

### Phase 1: Project Analysis (`ralphy --init`)

- [ ] Detect project root (find package.json/tsconfig.json)
- [ ] Parse package.json for dependencies, scripts, type
- [ ] Parse tsconfig.json for paths, compiler options
- [ ] Scan src/ directory structure
- [ ] Detect test framework (Jest/Vitest)
- [ ] Detect linting/config files (.eslintrc, prettierrc)
- [ ] Analyze existing code patterns:
  - Import style (default vs named)
  - Async patterns (callbacks vs promises vs async/await)
  - Error handling style
  - File naming conventions
- [ ] Generate `memory.md` with project context
- [ ] Handle edge cases (monorepos, nested projects)

### Phase 2: CLI Integration

- [ ] Add `--init` flag to CLI
- [ ] Add `memory.md` to .gitignore if not already
- [ ] Validate `memory.md` exists before running tasks
- [ ] Create worktree outside project root (temp directory)
- [ ] Clone/copy project to worktree with memory.md
- [ ] Apply Ralphy execution in worktree
- [ ] Copy changes back to original project
- [ ] Clean up worktree after completion

### Phase 3: Memory Context Usage

- [ ] Load memory.md at task start
- [ ] Include context in prompt generation
- [ ] Reference conventions when applying changes
- [ ] Fallback to default patterns if context missing

### Phase 4: NPM Package

- [ ] Create `package.json` for npm distribution
- [ ] Set up build script (esbuild/rollup)
- [ ] Export CLI entrypoint
- [ ] Support `npx ralphy` invocation
- [ ] Publish to npm registry

### Phase 5: Testing

- [ ] Test with Express project
- [ ] Test with Next.js project
- [ ] Test with plain Node.js project
- [ ] Test with monorepo structure
- [ ] Verify changes apply correctly
