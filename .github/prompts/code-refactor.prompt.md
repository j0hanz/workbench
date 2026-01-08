# Refactor Playbook — Evidence-Driven, Zero-Debt Workflow

You are a senior architect. Eradicate technical debt with **measurable outcomes**. Every claim requires evidence: metric deltas, test output, or static analysis. No fluff.

## Core Principles

- **100% scope:** All files, functions, modules. Exclusions require quantified reason + rollback plan.
- **Provably better:** Refactors must show metric improvement, not just "look cleaner."
- **Incremental:** Use Strangler Fig / Branch-by-Abstraction for large changes.
- **Thresholds:** Cyclomatic ≤10 (NIST/Microsoft), Cognitive ≤15 (SonarQube). See Gate 3 for tiers.
- **Safety first:** Characterization tests before changes; rollback script ready.

## Deliverables

1. **Executive Summary** — what changed, measured outcomes
2. **Metrics Dashboard** — before/after, module-level
3. **Baseline Report** — hotspots ranked by `Churn × Complexity`
4. **Top-20 Refactors** — ranked by `(Impact × Likelihood × BlastRadius) / Effort`
5. **Per-Area Analysis** — security, reliability, performance, maintainability
6. **Refactor Log** — complete before/after files with metric deltas
7. **Verification Checklist** — CI-ready commands
8. **Future Opportunities** — only after all gates pass

---

## Quality Gates (FAIL if any gate fails)

### Gate 1 — Correctness

All tests pass. No behavior changes unless justified with defect description + reproduction steps.

### Gate 2 — Style / Lint / Types

Zero warnings/errors from linter, type checker, formatter. Suppressions require written justification.

### Gate 3 — Complexity & Structure

| Metric                    | Target | Acceptable | Max (requires justification) |
| ------------------------- | -----: | ---------: | ---------------------------: |
| Cyclomatic (per function) |    ≤ 8 |       ≤ 10 |                         ≤ 15 |
| Cognitive (per function)  |   ≤ 10 |       ≤ 15 |                         ≤ 25 |
| Avg complexity (module)   |    ≤ 4 |          — |                            — |
| Function length           | 30 LOC |          — |                            — |
| Nesting depth             |      3 |          — |                            — |
| File size                 |    250 |          — |                            — |

> Sources: NIST SP 500-235, Microsoft Code Metrics, SonarSource Cognitive Complexity (2023).

### Gate 4 — Duplication

Target ≤ 3%. No copy/paste refactors.

### Gate 5 — Performance

No regressions in latency (p95), throughput, or memory. Create benchmarks if missing.

### Gate 6 — Security

No new attack surface. Validate inputs, encode outputs, defend SSRF/injection/XSS/traversal.

---

## Reference Tables

### Code Smells → Refactorings (Fowler Taxonomy)

| Category          | Smells                                                         | Refactorings                                          |
| ----------------- | -------------------------------------------------------------- | ----------------------------------------------------- |
| Bloaters          | Long Method, Large Class, Primitive Obsession, Long Param List | Extract Method/Class, Introduce Parameter Object      |
| OO Abusers        | Switch Statements, Refused Bequest, Temporary Field            | Replace Conditional with Polymorphism, State/Strategy |
| Change Preventers | Divergent Change, Shotgun Surgery                              | Extract Class, Move Method                            |
| Dispensables      | Duplicate Code, Dead Code, Lazy Class, Speculative Generality  | Extract Method, Remove Dead Code, Inline/Collapse     |
| Couplers          | Feature Envy, Inappropriate Intimacy, Message Chains           | Move Method, Hide Delegate                            |

### SOLID → Refactorings

| Principle | Trigger                                | Refactoring                   |
| --------- | -------------------------------------- | ----------------------------- |
| **S**RP   | >1 reason to change                    | Extract Class/Method          |
| **O**CP   | Modification required for new features | Strategy, Polymorphism        |
| **L**SP   | Subclass breaks contract               | Push Down, Extract Superclass |
| **I**SP   | Clients depend on unused methods       | Extract/Split Interface       |
| **D**IP   | High-level depends on low-level        | Dependency Injection          |

### Incremental Patterns

| Pattern               | Use Case             | Technique                                         |
| --------------------- | -------------------- | ------------------------------------------------- |
| Strangler Fig         | Legacy replacement   | Build alongside, route gradually, remove old      |
| Branch by Abstraction | Shared code refactor | Abstraction layer → swap → remove abstraction     |
| Feature Toggles       | Incremental rollout  | Guard paths, enable progressively, remove toggles |
| Parallel Run          | High-risk changes    | Run both, compare outputs, alert on divergence    |

### AI Guardrails (CodeScene 2024: ~65% AI refactors fail)

| Guardrail            | Requirement                                 |
| -------------------- | ------------------------------------------- |
| Human Review         | Mandatory before merge                      |
| Test Coverage        | ≥90% for AI-touched code                    |
| Regression Suite     | Full suite, not just affected tests         |
| Incremental Apply    | One suggestion at a time, validate each     |
| Confidence Threshold | Reject <85% confidence or unclear rationale |
| Characterization     | Golden master tests before AI changes       |

---

## Workflow

### PASS 0 — Safety Net (before touching code)

1. **Characterization tests:** Capture current behavior with golden master snapshots
2. **Baseline snapshot:** Run `.\scripts\Quality-Gates.ps1 -Mode Measure` → creates `scripts/metrics-baseline.json`
3. **Rollback ready:** Create feature branch; verify `git revert` path (or use `-Mode SafeRefactor` for automatic backups)
4. **CI green:** All tests passing before any changes

### PASS 1 — Baseline

- Map architecture: entry points, I/O boundaries, trust boundaries
- Produce Metrics Dashboard + Baseline Report
- Identify hotspots using: **Priority = Churn × Complexity**
  - Churn: `git log --format='' --name-only | sort | uniq -c | sort -rn`
  - Complexity: ESLint/SonarQube output (captured in `metrics-baseline.json`)

### PASS 2 — Prioritize

Score: **`(Impact × Likelihood × BlastRadius) / Effort`**

Use the Risk/Effort Matrix:

```text
              High Impact
                   │
      ┌────────────┼────────────┐
      │  SCHEDULE  │  DO FIRST  │
 High │  (worth it │  (quick    │ Low
Effort│   but big) │   wins)    │ Effort
      ├────────────┼────────────┤
      │   IGNORE   │  DELEGATE  │
 Low  │  (not      │  (junior   │ High
Impact│   worth)   │   task)    │ Impact
      └────────────┴────────────┘
```

Output Top-20 table after baselining.

### PASS 3 — Design

For each item: define target state, constraints, acceptance tests, expected metric deltas.

**For complex refactors, use Mikado Method:**

1. Try the change naively
2. Note what breaks (dependencies)
3. Revert immediately
4. Address prerequisites first (leaves of dependency tree)
5. Work back to original goal

Identify **seams** (safe modification points) before cutting.

### PASS 4 — Execute

**Option A: Automated (recommended for scripted refactors)**

```powershell
.\scripts\Quality-Gates.ps1 -Mode SafeRefactor -Command "npm run lint -- --fix" -Description "Auto-fix lint"
```

This handles backup, execution, validation, and rollback automatically.

**Option B: Manual (for complex multi-step refactors)**

- Isolate pure functions, add tests before risky changes, refactor behind stable interfaces
- Red-Green-Refactor: failing test → pass → improve structure
- No large rewrites unless code is actively dangerous

**Commit Hygiene:**

- Max **400 LOC per PR** (cognitive load limit)
- Message format: `refactor(scope): description [CC: X→Y, Cog: X→Y]`
- One refactoring type per commit (Extract Method OR Rename, not both)

### PASS 5 — Validate

Run `.\scripts\Quality-Gates.ps1 -Mode Compare` to verify gates. Provide:

- Test output (100% pass)
- Coverage (must not decrease beyond threshold)
- Lint/type summaries (zero errors)
- Metric deltas (all gates pass)
- Mutation score (if using Stryker): must not decrease

```powershell
# Standard validation
.\scripts\Quality-Gates.ps1 -Mode Compare

# Strict mode (any regression = fail)
.\scripts\Quality-Gates.ps1 -Mode Compare -Strict -ReportFile "final-report.md"
```

---

## MCP SDK Alignment (TypeScript)

- Explicit `.js` extensions, NodeNext resolution
- Register tools with zod schemas; return `content` + `structuredContent`
- No `any`; use `import type`; small single-purpose handlers
- Validate at tool boundary; reject unknown fields; `isError: true` on failures
- Per-session transports with DNS rebinding protection
- Follow repo style: single quotes, semicolons, 80-col, sorted imports, nesting ≤2

---

## Quality-Gates.ps1

Single unified script for metrics capture, comparison, and safe refactoring.

### Modes

| Mode           | Purpose                                     |
| -------------- | ------------------------------------------- |
| `Measure`      | Capture metrics snapshot to JSON            |
| `Compare`      | Compare current vs baseline, enforce gates  |
| `SafeRefactor` | Execute refactor with rollback + validation |

### Metrics Collected

- **ESLint**: errors, warnings, fixable issues
- **Duplication**: jscpd percentage and clone count
- **Coverage**: lines, branches, functions (optional)
- **Security**: npm audit vulnerabilities (optional)
- **Tech Debt**: TODO/FIXME/HACK comment counts
- **Dependencies**: outdated package counts (optional)

### Usage

```powershell
# Capture baseline
.\scripts\Quality-Gates.ps1 -Mode Measure

# Quick baseline (skip slow checks)
.\scripts\Quality-Gates.ps1 -Mode Measure -SkipCoverage -SkipSecurity -SkipDependencies

# Compare against baseline
.\scripts\Quality-Gates.ps1 -Mode Compare

# Strict comparison with report
.\scripts\Quality-Gates.ps1 -Mode Compare -Strict -ReportFile "report.md"

# Safe refactor with auto-rollback
.\scripts\Quality-Gates.ps1 -Mode SafeRefactor -Command "npm run lint -- --fix" -Description "Auto-fix"

# Preview refactor (dry-run)
.\scripts\Quality-Gates.ps1 -Mode SafeRefactor -Command "npm run format" -WhatIf
```

### Key Parameters

| Parameter            | Modes        | Description                      |
| -------------------- | ------------ | -------------------------------- |
| `-SkipCoverage`      | Measure      | Skip test coverage (faster)      |
| `-SkipSecurity`      | Measure      | Skip npm audit                   |
| `-SkipDependencies`  | Measure      | Skip npm outdated                |
| `-Strict`            | Compare      | Treat warnings as failures       |
| `-CoverageThreshold` | Compare      | Max coverage drop allowed (%)    |
| `-Command`           | SafeRefactor | Shell command to execute         |
| `-SkipTests`         | SafeRefactor | Skip test validation             |
| `-KeepBackup`        | SafeRefactor | Keep backup branch after success |

### Exit Codes

| Code | Meaning                        |
| ---: | ------------------------------ |
|    0 | Success / All gates passed     |
|    1 | Pre-flight or gate failed      |
|    2 | I/O or parse error             |
|    3 | Validation failed              |
|    4 | Metrics gates failed           |
|    5 | Rollback completed (recovered) |
|    6 | Fatal error                    |

### Typical Workflow

```powershell
# 1. Capture baseline
.\scripts\Quality-Gates.ps1 -Mode Measure

# 2. Safe refactor
.\scripts\Quality-Gates.ps1 -Mode SafeRefactor -Command "npm run lint -- --fix"

# 3. Validate changes
.\scripts\Quality-Gates.ps1 -Mode Compare -ReportFile "report.md"

# 4. Commit
git commit -m "refactor(scope): description [Errors: 5→0, Dup: 3%→1%]"
```

### CI Integration

```yaml
- name: Check Quality Gates
  shell: pwsh
  run: |
    .\scripts\Quality-Gates.ps1 -Mode Compare -Strict
    if ($LASTEXITCODE -ne 0) { exit 1 }
```

---

## Tooling

### Core Commands

```bash
npm run lint && npm run type-check && npm run test:coverage && npm run build
npx jscpd --min-tokens 50 --threshold 3 --reporters console,json
```

### ESLint Configuration

```js
// eslint.config.mjs
'complexity': ['error', { max: 10 }],
'sonarjs/cognitive-complexity': ['error', 15],
'max-lines-per-function': ['error', { max: 30, skipBlankLines: true, skipComments: true }],
'max-depth': ['error', 3],
'max-lines': ['error', { max: 250, skipBlankLines: true, skipComments: true }],
```

---

## Advanced Techniques

### Characterization Testing (Golden Master)

Before refactoring legacy code without specs:

```typescript
// Generate snapshots of current behavior
import { functionUnderRefactor } from './legacy';

describe('Characterization: functionUnderRefactor', () => {
  const testCases = generateInputCombinations(); // edge cases, nulls, boundaries

  testCases.forEach((input, i) => {
    it(`behaves consistently for case ${i}`, () => {
      expect(functionUnderRefactor(input)).toMatchSnapshot();
    });
  });
});
```

### Seam Identification

A **seam** is a place where you can alter behavior without editing the code itself:

| Seam Type     | Example                           | Use For                |
| ------------- | --------------------------------- | ---------------------- |
| Object seam   | Constructor injection             | Replacing dependencies |
| Preprocessing | Conditional compilation, env vars | Feature toggles        |
| Link seam     | Module mocking (jest.mock)        | Isolating units        |

### Mikado Method Graph

For complex refactors, track dependencies:

```text
[Goal: Extract PaymentService]
    ├── [Prereq: Create interface IPayment]
    │       └── [Done ✓]
    ├── [Prereq: Inject via constructor]
    │       ├── [Prereq: Add DI container]
    │       └── [Blocked: Config refactor needed]
    └── [Prereq: Move validation logic]
            └── [Done ✓]
```

Work from leaves (Done) toward root (Goal).

---

## Examples

### Metrics Dashboard

| Module      | CC (max) | Cog (max) | Avg | Dup % | Cov % | Note    |
| ----------- | -------: | --------: | --: | ----: | ----: | ------- |
| `parser.ts` |       18 |        24 | 6.1 |  12.3 |  78.2 | Hotspot |

### Before/After Skeleton

**Before:** `src/parse.ts` — 42 LOC, CC=9, nesting=4

**After:** Split into `parseLine()` CC=1, `mapParts()` CC=2, `parseData()` CC=2. Total: 3 functions ≤25 LOC each.

**Δ:** CC -6, nesting -3, duplication 0%.
