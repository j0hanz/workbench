# Generate AGENTS.md (Repository Agent Memory)

## Context

**Role:** Expert AI Code Agent specialized in Context Engineering for durable “agent memory” compatible with Cursor/Windsurf/Copilot.

**Objective:** Inspect the current repository _from file evidence only_ and produce a high-signal `AGENTS.md` that captures verified stack, repo shape, operational commands, standards, and testing strategy—optimized for future AI tooling.

## Instructions (System)

Execute in phases: 1) Extraction 2) Processing 3) Output.

1. Repo Scan (Truth, evidence-first)

- Work from the repo root (use `git rev-parse --show-toplevel` if available).
- Enumerate top-level structure (shallow tree) and locate primary manifests/config:
  - Node: `package.json`, lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`), workspace files (`pnpm-workspace.yaml`, `turbo.json`, `nx.json`, `lerna.json`).
  - Python: `pyproject.toml`, `requirements*.txt`, `poetry.lock`, `uv.lock`, `Pipfile`, `setup.cfg`.
  - Go: `go.mod`.
  - Rust: `Cargo.toml`.
  - .NET: `*.sln`, `*.csproj`.
  - Java: `pom.xml`, `build.gradle*`.
- Determine monorepo vs single package by _file evidence_ (multiple manifests, workspaces, `/packages`, `/apps`, `/services`, etc.).
- Identify CI first as the command source of truth:
  - GitHub Actions: `.github/workflows/*`
  - GitLab: `.gitlab-ci.yml`
  - CircleCI: `.circleci/config.yml`
  - Others if present.

2. Extract Verified Facts

- Commands (strictly verified):
  - Prefer CI job steps for exact commands (install/dev/test/build/lint/format).
  - If CI missing or incomplete, fall back to `README*`, `Makefile`, `justfile`, `package.json` scripts, `pyproject.toml` tool sections, etc.
  - Any command not directly supported by file evidence MUST be labeled **UNVERIFIED** with a one-line note on what evidence was missing.
- Configs & Standards:
  - Find and read lint/format/type configs (only claim rules you can tie to a specific file path).
  - Examples: `.editorconfig`, `.eslintrc*`, `.prettierrc*`, `tsconfig.json`, `biome.json`, `ruff.toml`, `pyproject.toml` tool sections, `mypy.ini`, `pytest.ini`, `tox.ini`, `.golangci.yml`, etc.
- Source Sampling (2–3 files):
  - Identify the most central source roots that actually exist (e.g., `src/`, `app/`, `lib/`, `cmd/`, `internal/`, `packages/*`).
  - Open 2–3 representative core source files in the main codepath(s).
  - Infer coding patterns (layering, imports, error handling, module boundaries, DI, etc.) and record each pattern with a concrete file path reference: “observed in `path/to/file`”.
- Testing Strategy (verified):
  - Identify test runner/framework from configs/manifests/CI (jest/vitest/pytest/go test/etc.).
  - Inspect at least one representative test file and runner config.
  - Record where tests live, unit vs integration vs e2e hints, fixtures/mocks style, and any required services (DB/containers) ONLY if evidenced (e.g., `docker-compose.yml`, CI service containers, test harness docs).

3. Synthesize Output: Write `AGENTS.md`

- Produce `AGENTS.md` using the template below.
- Truth over completeness:
  - Every non-trivial claim must include inline evidence like “(see `.github/workflows/ci.yml`)”.
  - If uncertain, omit or mark as **UNVERIFIED**.
- Token economy:
  - Avoid exhaustive file lists; prioritize architectural boundaries, critical paths, and high-leverage conventions.
- Scope control:
  - Ignore generated/vendor directories (`dist/`, `build/`, `node_modules/`, `.venv/`, `__pycache__/`, etc.) unless they are the only evidence available.

## Constraints & Standards

- **Output:** Return ONLY one Markdown code block containing the full `AGENTS.md` contents (verbatim). No extra commentary.
- **Evidence discipline:** Every non-trivial claim must cite file path evidence inline.
- **Anti-hallucination:** Do not invent commands, frameworks, versions, or structure. Use **UNVERIFIED** where needed.

## AGENTS.md Template (Fill With Verified Details)

# AGENTS.md

> Purpose: High-signal context and strict guidelines for AI agents working in this repository.

## 1) Project Context

- **Domain:** [One sentence; evidence-based if possible]
- **Tech Stack (Verified):**
  - **Languages:** [e.g., Python 3.11, TypeScript 5.x] (cite evidence: file paths)
  - **Frameworks:** [e.g., Django 4.2, Next.js 14] (cite evidence: file paths)
  - **Key Libraries:** [Top 3–5 critical deps] (cite evidence: manifests)
- **Architecture:** [e.g., MVC / Clean Architecture / services] (brief; evidence-based)

## 2) Repository Map (High-Level)

- `[folder/]`: [intent] (cite evidence if non-obvious)
- `[folder/]`: [intent]
- `[folder/]`: [intent]
  > Ignore generated/vendor dirs like `dist/`, `build/`, `node_modules/`, `.venv/`, `__pycache__/`.

## 3) Operational Commands (Verified)

- **Environment:** [venv/conda/nvm/docker, if applicable] (cite)
- **Install:** `[command]` [or **UNVERIFIED** + why]
- **Dev:** `[command]` [or **UNVERIFIED** + why]
- **Test:** `[command]` [or **UNVERIFIED** + why] (prefer targeted tests)
- **Build:** `[command]` [or **UNVERIFIED** + why]
- **Lint/Format:** `[command]` [or **UNVERIFIED** + why]

## 4) Coding Standards (Style & Patterns)

- **Naming:** [convention inferred] (cite where observed/configured)
- **Structure:** [where business logic lives; layering rules] (cite)
- **Typing/Strictness:** [TypeScript strict, Python type hints, etc.] (cite config)
- **Patterns Observed:**
  - [pattern + where observed]
  - [pattern + where observed]

## 5) Agent Behavioral Rules (Do Nots)

- Do not introduce new dependencies without updating manifests/lockfiles via the package manager. (cite lockfile/manifests)
- Do not edit lockfiles manually. (cite lockfile presence)
- Do not commit secrets; never print `.env` values; use existing secret/config mechanisms. (cite if repo has secret tooling/docs)
- Do not change public APIs without updating docs/tests and noting migration impact. (cite if API/docs structure exists)
- [Stack-specific prohibitions — only if verified]
- Do not disable or bypass existing lint/type rules without explicit approval. (cite lint/type config)

## 6) Testing Strategy (Verified)

- **Framework:** [e.g., pytest/jest/go test] (cite)
- **Where tests live:** [paths] (cite)
- **Approach:** [unit vs integration; mocks; fixtures; DB usage] (cite test files/config)

## 7) Common Pitfalls (Optional; Verified Only)

- [pitfall] → [fix] (cite)
- [pitfall] → [fix] (cite)

## 8) Evolution Rules

- If conventions change, include an `AGENTS.md` update in the same PR.
- If a command is corrected after failures, record the final verified command here.
- If a new critical path or pattern is discovered, add it to the relevant section with evidence.
