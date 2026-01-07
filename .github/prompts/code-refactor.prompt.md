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
2. **Baseline snapshot:** Run `Measure-Baseline.ps1` → store `metrics-baseline.json`
3. **Rollback ready:** Create feature branch; verify `git revert` path
4. **CI green:** All tests passing before any changes

### PASS 1 — Baseline

- Map architecture: entry points, I/O boundaries, trust boundaries
- Produce Metrics Dashboard + Baseline Report
- Identify hotspots using: **Priority = Churn × Complexity**
  - Churn: `git log --format='' --name-only | sort | uniq -c | sort -rn`
  - Complexity: ESLint/SonarQube output

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

- Isolate pure functions, add tests before risky changes, refactor behind stable interfaces
- Red-Green-Refactor: failing test → pass → improve structure
- No large rewrites unless code is actively dangerous

**Commit Hygiene:**

- Max **400 LOC per PR** (cognitive load limit)
- Message format: `refactor(scope): description [CC: X→Y, Cog: X→Y]`
- One refactoring type per commit (Extract Method OR Rename, not both)

### PASS 5 — Validate

Run `Compare-Metrics.ps1` to verify gates. Provide:

- Test output (100% pass)
- Coverage (must not decrease)
- Lint/type summaries (zero errors)
- Metric deltas (all gates pass)
- Mutation score (if using Stryker): must not decrease

---

## MCP SDK Alignment (TypeScript)

- Explicit `.js` extensions, NodeNext resolution
- Register tools with zod schemas; return `content` + `structuredContent`
- No `any`; use `import type`; small single-purpose handlers
- Validate at tool boundary; reject unknown fields; `isError: true` on failures
- Per-session transports with DNS rebinding protection
- Follow repo style: single quotes, semicolons, 80-col, sorted imports, nesting ≤2

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

## PowerShell Automation

### Measure-Baseline.ps1

```powershell
<#
.SYNOPSIS
    Captures baseline metrics for refactoring comparison.
.OUTPUTS
    metrics-baseline.json in project root
#>
param([string]$OutFile = "metrics-baseline.json")

$metrics = @{
    timestamp = Get-Date -Format "o"
    commit    = git rev-parse HEAD
    complexity = @{}
    duplication = $null
    coverage = $null
}

# ESLint complexity (requires eslint-plugin-sonarjs)
$eslintOutput = npm run lint -- --format json 2>$null | ConvertFrom-Json
$metrics.complexity.errors = ($eslintOutput | ForEach-Object { $_.errorCount } | Measure-Object -Sum).Sum

# jscpd duplication
$jscpdOutput = npx jscpd --min-tokens 50 --reporters json --output .jscpd 2>$null
if (Test-Path ".jscpd/jscpd-report.json") {
    $dup = Get-Content ".jscpd/jscpd-report.json" | ConvertFrom-Json
    $metrics.duplication = $dup.statistics.total.percentage
}

# Coverage (if exists)
if (Test-Path "coverage/coverage-summary.json") {
    $cov = Get-Content "coverage/coverage-summary.json" | ConvertFrom-Json
    $metrics.coverage = $cov.total.lines.pct
}

$metrics | ConvertTo-Json -Depth 5 | Set-Content $OutFile
Write-Host "✓ Baseline saved to $OutFile" -ForegroundColor Green
```

### Compare-Metrics.ps1

```powershell
<#
.SYNOPSIS
    Compares current metrics against baseline. Fails if gates violated.
#>
param(
    [string]$Baseline = "metrics-baseline.json",
    [switch]$Strict
)

if (-not (Test-Path $Baseline)) {
    Write-Error "Baseline not found: $Baseline. Run Measure-Baseline.ps1 first."
    exit 1
}

$before = Get-Content $Baseline | ConvertFrom-Json

# Capture current
& "$PSScriptRoot/Measure-Baseline.ps1" -OutFile "metrics-current.json"
$after = Get-Content "metrics-current.json" | ConvertFrom-Json

$failed = $false

# Gate checks
if ($after.complexity.errors -gt $before.complexity.errors) {
    Write-Host "✗ Complexity errors increased: $($before.complexity.errors) → $($after.complexity.errors)" -ForegroundColor Red
    $failed = $true
}

if ($after.duplication -gt $before.duplication) {
    Write-Host "✗ Duplication increased: $($before.duplication)% → $($after.duplication)%" -ForegroundColor Red
    $failed = $true
}

if ($after.coverage -lt $before.coverage) {
    Write-Host "✗ Coverage decreased: $($before.coverage)% → $($after.coverage)%" -ForegroundColor Red
    $failed = $true
}

if ($failed) {
    Write-Host "`n⛔ GATE FAILED — Refactor does not meet quality standards" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✓ All gates passed" -ForegroundColor Green
    Write-Host "  Complexity: $($before.complexity.errors) → $($after.complexity.errors)"
    Write-Host "  Duplication: $($before.duplication)% → $($after.duplication)%"
    Write-Host "  Coverage: $($before.coverage)% → $($after.coverage)%"
}
```

### Invoke-SafeRefactor.ps1

```powershell
<#
.SYNOPSIS
    Wrapper for safe refactoring: test → change → test → revert if failed.
.EXAMPLE
    Invoke-SafeRefactor.ps1 -ScriptBlock { npm run lint:fix }
#>
param(
    [scriptblock]$ScriptBlock,
    [string]$CommitMessage = "refactor: automated change"
)

# Pre-flight
Write-Host "🔍 Running pre-refactor tests..." -ForegroundColor Cyan
npm run test --silent
if ($LASTEXITCODE -ne 0) {
    Write-Error "Pre-refactor tests failed. Fix tests before refactoring."
    exit 1
}

# Snapshot
git stash push -m "safe-refactor-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

try {
    # Apply change
    Write-Host "🔧 Applying refactor..." -ForegroundColor Cyan
    & $ScriptBlock

    # Post-flight
    Write-Host "🔍 Running post-refactor tests..." -ForegroundColor Cyan
    npm run test --silent
    if ($LASTEXITCODE -ne 0) {
        throw "Post-refactor tests failed"
    }

    # Verify metrics
    & "$PSScriptRoot/Compare-Metrics.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "Metrics gates failed"
    }

    Write-Host "✓ Refactor successful" -ForegroundColor Green
    git stash drop

} catch {
    Write-Host "⛔ Refactor failed: $_" -ForegroundColor Red
    Write-Host "↩ Reverting changes..." -ForegroundColor Yellow
    git checkout .
    git stash pop
    exit 1
}
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
