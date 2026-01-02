---
description: 'Prompt for generating an AGENTS.md file for a repository'
---

# Create a high-quality AGENTS.md file

You are a code agent. Your task is to create a complete, accurate
`AGENTS.md` at the repository root that follows https://agents.md/ and
reflects THIS repository's reality.

## Prime directive

- Be specific and verifiable. Only include commands, paths, and rules
  you can confirm from repository files (package.json, README, docs, CI).
- Prefer facts over filler. Omit generic background and marketing copy.
- If information is missing or ambiguous, add a short "Open Questions /
  TODO" section instead of guessing.
- Keep it concise and actionable (1-2 pages). Use bullets and backticks
  for commands/paths.

## Inputs to inspect (minimum set)

1. package.json (scripts, engines, package manager)
2. README.md and docs/ (setup, architecture, workflows)
3. tsconfig/eslint/prettier configs (style + type/lint rules)
4. CI/workflows (required checks, test matrix)
5. Repository tree (top-level structure)

## Systematic workflow

Phase 1 — Scan

- Identify the stack, entry points, and main modules.
- Extract exact commands (install, dev, build, test, lint, type-check).
- Note generated vs. source directories.

Phase 2 — Map

- Build a concise repo map (key directories and what they contain).
- Identify sources of truth (schemas, configs, shared types).

Phase 3 — Synthesize

- Draft AGENTS.md with required sections below.
- Translate implicit rules into explicit, agent-friendly instructions.

Phase 4 — QA

- Ensure every command exists and matches actual scripts.
- Ensure paths are correct and section content is non-duplicative.
- Remove any guesswork or unverified claims.

## Required sections (use these headings)

- Project Overview
- Repo Map / Structure
- Setup & Environment
- Development Workflow
- Testing
- Code Style & Conventions
- Build / Release
- Security & Safety
- Pull Request / Commit Guidelines
- Troubleshooting

## Optional sections (include only if relevant)

- Monorepo / multi-package navigation
- Database / migrations
- Tooling details (lint/format/type-check)
- Observability / logging
- Agent Operating Rules (search before edit, avoid destructive commands,
  read docs before changing behavior) — include only if repo policies
  imply it

## Output format

Return a single Markdown code block containing the full AGENTS.md
content. Do not include extra commentary outside the code block.

## Template skeleton (fill with repo facts)

```markdown
# AGENTS.md

## Project Overview

- [What this repo does + primary tech stack]

## Repo Map / Structure

- `src/`: [purpose]
- `dist/`: [build output if present]
- [other key directories]

## Setup & Environment

- Install deps: `[command]`
- Env config: [file(s) + where documented]
- [any required services or versions]

## Development Workflow

- Dev mode: `[command]`
- Build: `[command]`
- Start/prod: `[command]`

## Testing

- All tests: `[command]`
- Watch mode: `[command]`
- Coverage: `[command]`
- Test locations/patterns: `[details]`

## Code Style & Conventions

- Language: [version]
- Lint: `[command]`
- Format: `[command]`
- Conventions: [naming, imports, file layout]

## Build / Release

- Build output: `[directory]`
- Release/versioning: [process or tags]

## Security & Safety

- [Constraints, safe defaults, secrets handling]

## Pull Request / Commit Guidelines

- Commit format: [convention]
- Required checks: `[commands]`

## Troubleshooting

- [Known issues + fixes]

## Open Questions / TODO

- [Only if needed]
```
