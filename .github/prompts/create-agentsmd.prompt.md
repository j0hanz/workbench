# Create AGENTS.md

You are an expert AI Code Agent specialized in Context Engineering. Analyze the current repository and generate a high-signal `AGENTS.md` that serves as durable “agent memory” and an instruction set for future AI tools (Cursor/Windsurf/Copilot).

## Prime Directives

1. Truth over completeness: include only commands/paths/patterns you can directly verify from the repo. If uncertain, omit or label as **UNVERIFIED**.
2. Stack-agnostic: do not assume any language/framework. Detect stack from file evidence.
3. Token economy: be concise; avoid exhaustive file lists. Focus on architectural boundaries and high-leverage guidance.
4. Evidence-first: prefer exact file references when stating conventions or commands.

## What To Inspect (Minimum)

- Manifest/deps: `package.json`, `requirements*.txt`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `Gemfile`, etc.
- Config/lint/format: `tsconfig.json`, `.eslintrc*`, `.prettierrc*`, `.editorconfig`, `ruff.toml`, `mypy.ini`, `pytest.ini`, etc.
- CI/CD: `.github/workflows/*`, `.gitlab-ci.yml`, `circleci/config.yml`, etc. (treat CI as the source of truth for build/test)
- Source sampling: read 2–3 core files in likely roots (`src/`, `app/`, `lib/`, `cmd/`, `internal/`, etc.) to infer style and patterns.
- Tests: inspect at least one representative test file to infer strategy.

## Required Workflow

### Phase 1: Diagnose

- Identify primary language(s) and frameworks with concrete evidence (file names).
- Identify package manager/build tool.
- Identify repo organization pattern (monorepo vs single package; feature vs layer vs service).

### Phase 2: Extract

- Commands: strictly verified **Install**, **Dev**, **Test**, **Build** (prefer CI commands).
- Standards: naming, structure, typing/strictness, formatting/linting rules inferred from configs + sampled code.
- Testing approach: unit/integration/e2e mix; mocking; where tests live.

### Phase 3: Synthesize

- Produce `AGENTS.md` using the template below.
- Add stack-specific “Do Not” rules only if supported by evidence (framework conventions, security constraints, etc.).
- Include a short “Common Pitfalls” section only if you can verify pitfalls from CI failures/docs/config.

## Output Rules

- Return **only** a single Markdown code block containing the full contents of `AGENTS.md`.
- Do not include explanations outside the code block.

## `AGENTS.md` Template (Fill With Verified Details)

```markdown
# AGENTS.md

> Purpose: High-signal context and strict guidelines for AI agents working in this repository.

## 1) Project Context

- **Domain:** [One sentence]
- **Tech Stack (Verified):**
  - **Languages:** [e.g., Python 3.11, TypeScript 5.x] (cite evidence)
  - **Frameworks:** [e.g., Django 4.2, Next.js 14] (cite evidence)
  - **Key Libraries:** [Top 3–5 critical deps] (cite evidence)
- **Architecture:** [e.g., MVC / Clean Architecture / services] (brief; evidence-based)

## 2) Repository Map (High-Level)

- `[folder/]`: [intent]
- `[folder/]`: [intent]
- `[folder/]`: [intent]
  > Ignore generated/vendor dirs like `dist/`, `build/`, `node_modules/`, `.venv/`, `__pycache__/`.

## 3) Operational Commands (Verified)

- **Environment:** [venv/conda/nvm/docker, if applicable]
- **Install:** `[command]` [or **UNVERIFIED**]
- **Dev:** `[command]` [or **UNVERIFIED**]
- **Test:** `[command]` [or **UNVERIFIED**] (prefer targeted tests)
- **Build:** `[command]` [or **UNVERIFIED**]
- **Lint/Format:** `[command]` (if present)

## 4) Coding Standards (Style & Patterns)

- **Naming:** [convention inferred]
- **Structure:** [where business logic lives; layering rules]
- **Typing/Strictness:** [TypeScript strict, Python type hints, etc.]
- **Patterns Observed:**
  - [pattern + where observed]
  - [pattern + where observed]

## 5) Agent Behavioral Rules (Do Nots)

- Do not introduce new dependencies without updating manifests/lockfiles via the package manager.
- Do not edit lockfiles manually.
- Do not commit secrets; never print `.env` values; use existing secret/config mechanisms.
- Do not change public APIs without updating docs/tests and noting migration impact.
- [Stack-specific prohibitions — only if verified]
- Do not disable or bypass existing ESLint/TypeScript rules without explicit approval.

## 6) Testing Strategy (Verified)

- **Framework:** [e.g., pytest/jest/go test]
- **Where tests live:** [paths]
- **Approach:** [unit vs integration; mocks; fixtures; DB usage]

## 7) Common Pitfalls (Optional; Verified Only)

- [pitfall] → [fix]
- [pitfall] → [fix]

## 8) Evolution Rules

- If conventions change, include an `AGENTS.md` update in the same PR.
- If a command is corrected after failures, record the final verified command here.
```
