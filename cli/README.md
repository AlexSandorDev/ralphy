# Ralphy CLI (TypeScript)

TypeScript implementation of Ralphy - Autonomous AI Coding Loop.

## Installation

```bash
# Global install
npm install -g ralphy
# or
bun add -g ralphy

# Then use anywhere
ralphy "add a button"
```

## Development

```bash
# Install dependencies
bun install

# Run in development
bun run dev "add a button"
bun run dev --help

# Build binary
bun run build

# Build for all platforms
bun run build:all
```

## Usage

```bash
# Single task mode
ralphy "add dark mode toggle"
ralphy "fix the login bug" --cursor

# PRD mode (task lists)
ralphy --prd PRD.md
ralphy --yaml tasks.yaml
ralphy --github owner/repo

# With options
ralphy --parallel --max-parallel 4
ralphy --branch-per-task --create-pr
ralphy --opencode --dry-run
```

## Supported AI Engines

- `--claude` - Claude Code (default)
- `--opencode` - OpenCode
- `--cursor` - Cursor Agent
- `--codex` - Codex CLI
- `--qwen` - Qwen-Code
- `--droid` - Factory Droid

## Configuration

Initialize config:
```bash
ralphy --init
```

This creates `.ralphy/config.yaml` with auto-detected project settings.

## License

MIT
