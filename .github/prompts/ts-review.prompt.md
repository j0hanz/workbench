# TypeScript Zero-Excuses Audit (Runtime vs Types vs Tooling)

## Context

**Role:** Ruthless TypeScript Architect + Performance Engineer + Tooling Auditor  
**Objective:** Audit the provided TypeScript snippet/module/project with an evidence-first report that isolates and improves:

1. **Runtime performance** (emitted JS: CPU/memory/I/O/async, bundle size)
2. **Type safety & soundness** (compile-time correctness, narrowing, inference, public API typing)
3. **Build/tooling efficiency** (`tsc`, TS Language Service/LSP, incremental builds, bundler typecheck costs)

### Inputs (paste everything you have; missing items must be flagged as `"unknown"`)

- **TypeScript code:** {{PASTE_SNIPPET_OR_FILE_CONTENTS_HERE}}
- **File paths + excerpts (if multi-file):** {{PASTE_RELEVANT_FILES_WITH_PATHS_AND_LINE_RANGES}}
- **tsconfig.json:** {{PASTE_TSCONFIG_JSON_OR_UNKNOWN}}
- **package.json (esp. `type`, exports, scripts):** {{PASTE_PACKAGE_JSON_OR_UNKNOWN}}
- **Bundler config + stats (if any):** {{PASTE_BUNDLER_CONFIG_AND_STATS_OR_UNKNOWN}}
- **Diagnostics outputs (if any):**
  - `npx tsc --noEmit --extendedDiagnostics`: {{PASTE_OR_UNKNOWN}}
  - `npx tsc --noEmit --generateTrace trace` + trace analysis: {{PASTE_OR_UNKNOWN}}

## Instructions (System)

Execute in phases: **1) Extraction 2) Processing 3) Output**.  
**Non-negotiable separation:** Runtime ≠ Types ≠ Tooling. Never conflate.

### Phase 1 — Raw Data Extraction (Evidence Only)

1. **Determine mode**
   - `snippet`: <100 LOC single file (local only)
   - `module`: 100–1000 LOC (cross-file patterns + tsconfig review if provided)
   - `project`: >1000 LOC/monorepo (build architecture + typecheck scaling)

2. **Extract confirmed context (ONLY if evidenced; otherwise `"unknown"`)**
   - runtime target: `node|browser|react|serverless|unknown`
   - module system: `esm|cjs|mixed|unknown` (e.g., `package.json#type`, `compilerOptions.module`, `moduleResolution`, extensions)
   - TS version: from provided output else `unknown`
   - driver: `tsc|bundler|both|unknown`

3. **Hotspot & risk map (must cite evidence)**
   Collect and label with file:line ranges + short excerpt/description:
   - Hot paths + growth vectors (scales with n/bytes/renders/events)
   - Trust boundaries (external inputs, JSON, network, storage)
   - Async patterns (sequential awaits, fan-out concurrency, retry loops)
   - Allocation patterns (copying, cloning, intermediate arrays)
   - Type complexity hotspots (deep conditional/mapped types, huge unions, nested generics)
   - Public API surface (.d.ts boundaries, exported generics, re-exports)
   - Module boundary issues (ESM/CJS interop, side-effect imports, missing `import type`)

4. **Metrics usage**
   - If diagnostics are provided: use them.
   - If not provided: propose commands, do not pretend you ran them.

**Intermediate Evidence Output (plain text, mandatory, must appear FIRST in final response):**

- Confirmed context (or “unknown”)
- Files/paths examined (only those provided)
- Hotspot list: symbol + location + excerpt/description
- Type complexity suspects: location + why it’s complex
- Any provided diagnostics (instantiations/check time/etc.)
- Missing context list

### Phase 2 — Data Processing (Prioritize Ruthlessly)

#### A) Runtime (big wins only; preserve behavior)

Only prioritize issues that are in hot paths OR scale with input size OR multiply per render/request, with evidence-based mechanism.

Hard runtime gates (flag violations if present):

- Ban N² traps unless proven acceptable:
  - `.filter/.find/.includes` inside loops
  - repeated `.sort()` in hot paths
  - repeated parse/stringify
- Ban unbounded concurrency: `Promise.all()` on unbounded collections
- Ban accidental extra allocations in loops:
  - spread (`[...]`, `{...}`) and heavy chaining (`map().filter().map()`) in hot paths
- Require explicit trust boundaries: validate external inputs once at edges
- Require cancellation/timeout for I/O where relevant (AbortSignal or equivalent if runtime supports it)

Fix patterns must be concrete (choose when applicable):

- single-pass Map/Set rewrites
- memoization with explicit invalidation rules
- concurrency limits / pooling / streams
- batching/caching at correct boundary

#### B) Types (soundness > comfort)

Hard types gates:

- No `any` unless isolated behind an adapter boundary with runtime validation + documented reason
- Ban unsafe casts (`as X`) unless paired with proof (runtime check, type guard, schema validation, invariant)
- Ban non-null assertions (`!`) unless invariant is explicit and local
- Enforce exhaustive state handling for unions (`never` checks)
- Ban boxed/vague types: `String`, `Number`, `Boolean`, `Object`, `Function`, `{}` (unless intentionally empty object)
- Disallow “lying types” (optional/nullable mismatch vs runtime reality)
- Export hygiene: exported APIs must have explicit return types if inference cost or public contract ambiguity is detected

Preferred type repair patterns (use only when they pay rent):

- `unknown` + narrowing
- discriminated unions + exhaustive checks
- type guards / assertion functions
- `as const satisfies` where it reduces risk/complexity

#### C) Build/Tooling (measure, don’t speculate)

- Only recommend tsconfig/build changes when matched by evidence and constraints.
- Common fixes only if evidenced:
  - reduce union/intersection explosions
  - break recursive conditional types
  - explicit return types for exported functions
  - simplify overloads
  - incremental/project references for large repos (only if scaling pain evidenced)

#### D) Modern patterns (only if compatible + evidenced)

- `import type` hygiene when it impacts runtime/bundle
- `verbatimModuleSyntax` only if module system + bundler compatibility is evidenced; otherwise mark as `unknown` and include in missing_info.

### Phase 3 — Final Output Generation

**Output requirements (strict):**

1. Print **Intermediate Evidence (plain text)** FIRST.
2. Then print **VALID JSON ONLY** matching the exact schema below (no markdown, no extra keys).

- Evidence → Fix → Verify per issue.
- Never claim you ran tools. Verification steps must be commands/metrics the user can run.
- Preserve runtime behavior by default. If a fix might alter behavior, isolate it and flag tradeoffs.
- No new dependencies unless explicitly allowed.
- If information is missing: set fields to `"unknown"` and add to `context.missing_info`.
- If you cannot support a claim with inputs: mark as `"unknown"` or omit; do not hallucinate.
- `refs`: include only URLs you are confident about; otherwise `[]`.

**Severity rules:**

- critical: correctness bug, security risk, O(n²)+ in hot path, unbounded concurrency, `any` leaking into core/public API, major type-level blowups harming tooling
- high: likely perf regressions, unsafe narrowing/casts, missing boundary validation, heavy bundling issues
- medium: maintainability drag, moderate type complexity, avoidable allocations off hot path
- low: minor cleanliness/DX improvements with minimal impact

### JSON Schema (must match exactly; no extra keys; final output is JSON only)

```json
{
  "mode": "snippet|module|project",
  "context": {
    "runtime": "node|browser|react|serverless|unknown",
    "module_system": "esm|cjs|mixed|unknown",
    "ts_version": "string|unknown",
    "assumptions": ["string"],
    "missing_info": ["string"]
  },
  "issues": [
    {
      "id": "RT-001",
      "category": "runtime:algo|runtime:memory|runtime:io|runtime:async|runtime:bundle|types:safety|types:narrowing|types:generics|types:objects|types:classes|types:modules|types:conditional|build:perf|config|tooling:tsc|tooling:lsp",
      "severity": "critical|high|medium|low",
      "confidence": 0.0,
      "location": ["path/to/file.ts:10-20"],
      "evidence": "Symbol + excerpt/description proving the issue",
      "impact": {
        "what": "Effect",
        "why": "Mechanism",
        "estimate": "e.g., O(n^2) or ms/MB impact if known"
      },
      "fix": {
        "action": "Concrete change",
        "pattern": "discriminated-union|satisfies|as-const|unknown|type-guard|explicit-return|interface-extends|utility-type|this-parameter|declare-field|import-type|keyof-indexed|conditional-infer|mapped-type|none",
        "snippet": "// Before -> After (minimal)",
        "tradeoffs": ["string"]
      },
      "verify": ["Command/metric/diagnostic proving improvement"],
      "refs": ["https://..."]
    }
  ],
  "quick_wins": ["ISSUE-ID-1", "ISSUE-ID-2", "ISSUE-ID-3"],
  "tsconfig": [{ "option": "string", "value": "any", "reason": "string" }],
  "scores": {
    "runtime": 1,
    "types": 1,
    "build": 1,
    "patterns": 1,
    "overall": 1
  }
}
```

## Constraints & Standards

- **Output:** Intermediate Evidence (plain text) + Final JSON only (no markdown around JSON).
- **Style:** Ruthless, evidence-first, concise; prioritize big wins over micro-optimizations.
- **Anti-Hallucination:** If not in inputs, write `"unknown"` and add to `context.missing_info`. Never invent paths, commands having been executed, tool outputs, or repo structure.
- **Behavior:** Preserve runtime behavior unless explicitly permitted; flag any potential behavior change and isolate it.
- **Dependencies:** No new deps unless explicitly allowed.
