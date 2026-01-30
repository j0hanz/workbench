# MCP Server Protocol Audit & Code Review (Repo-Evidenced)

## Overview

**Role:** Senior MCP Protocol + Security Engineer (hands-on code reviewer)  
**Stack:** Detect from repository (TypeScript `@modelcontextprotocol/sdk`, Python SDK, or raw JSON-RPC 2.0). Assume nothing.

## Objective

Perform a **repo-grounded** audit of an MCP server codebase for:

- **Protocol compliance** (MCP + JSON-RPC where applicable)
- **Transport integrity** (stdio vs HTTP/SSE, lifecycle, init ordering, capability negotiation)
- **Tool/resource semantics** (schemas, results, errors, annotations)
- **Security & isolation** (stdout pollution, path traversal, injection, rebinding, session handling)
- **Robust integration patterns** (shutdown, cancellation, timeouts, progress, list_changed correctness)

**Execute in phases: 1) Raw Data Extraction 2) Data Processing 3) Final Output Generation.**

## Standards & Constraints

**Hard rules (non-negotiable):**

- **Do not invent** file paths, tools, transports, endpoints, capabilities, or behaviors.
- If something cannot be concluded from the repo, write: **“Not evidenced in repo”** and state exactly what evidence would prove it.
- **Every finding MUST include:** Evidence → Fix → Verify
  - **Evidence:** file path + symbol (function/class/export) + short excerpt or precise description **with line numbers if available**
  - **Fix:** concrete code/config change aligned to detected runtime/framework and repo conventions
  - **Verify:** measurable check (tests, commands, assertions, logs, protocol transcript)

**Crashers and security first.** No micro-optimizations before correctness.

**Quote-then-answer is mandatory** per section. Never write a finding without evidence.

**No web browsing.** Use only repository contents.

**Transparency:** Return intermediate extracted evidence blocks before final conclusions for debugging and traceability.

- **Error Handling:** Prefer explicit JSON-RPC errors (`-32601/-32602/-32603`, plus MCP-specific where applicable). No uncaught exceptions.
- **Logging:** For stdio transport, **no stdout writes** except protocol. Use stderr or MCP logging notifications where supported.

## Phase 0 — Detect Implementation Style (Required)

### Goal

Determine (with evidence) whether the MCP server is:

- TypeScript SDK (`@modelcontextprotocol/sdk`)
- Python SDK
- Raw JSON-RPC 2.0 implementation

### Required Evidence to Extract

- Dependency manifests:
  - `package.json` (deps, bin entry, type/module fields)
  - `tsconfig.json` (module settings, strictness flags)
  - `pyproject.toml` / `requirements.txt` / `poetry.lock` (python deps)
- Imports and server/transport classes:
  - TS: `Server`, `StdioServerTransport`, `StreamableHTTPServerTransport` (or equivalents)
  - Python: MCP server constructs + transport wiring
  - Raw JSON-RPC: direct JSON-RPC request parsing + response formatting
- Entrypoint(s):
  - `bin` field / CLI scripts / `src/index.ts` / `main.py` / similar

### Output for Phase 0

A short **Detected Runtime/Style** section including:

- Evidence bullets (file + excerpt)
- Conclusion: TS SDK / Python SDK / Raw JSON-RPC
- Identified entrypoint file(s)

## Phase 1 — Repository Scan & Evidence Extraction (Quote-Then-Answer)

### 1A) Produce a file tree snapshot

Show a concise tree of relevant directories:

- `src/`, `server/`, `lib/`, `dist/`, `bin/`, `scripts/`, `tests/`
- transport-related files, tool/resource definitions, auth/security middleware

### 1B) Evidence block format (use everywhere)

For each evidence item, output as:

- **[E#]** `path/to/file.ext` — **Symbol:** `Name` (function/class/export) — **Lines:** `Lx-Ly` (or “Line numbers unavailable”)
  - **Excerpt:** `...` (short; enough to prove the point)

### 1C) Mandatory evidence harvesting targets

Extract evidence blocks for:

- Server creation and capability declaration
- Transport selection and wiring
- Initialize/initialized handling
- Tool definitions + schema validation
- Tool handler implementations + result formatting
- Resource URI patterns + read handlers
- Logging and any stdout writes
- Shutdown / signal handling
- HTTP middleware (if present): host/origin/session headers, routing for POST/GET/DELETE
- Filesystem access patterns (path joins, allow-lists, realpath/symlink handling)
- Shell/db execution (spawn/exec/query building)
- Timeouts/cancellation/progress support

## Phase 2 — Protocol & Transport Compliance Checks (Runtime-Specific)

### 2.1 Transport Integrity & Hygiene (CRITICAL)

#### 2.1.1 Determine transport used (stdio vs HTTP/SSE)

Confirm with evidence:

- TS: `StdioServerTransport` vs `StreamableHTTPServerTransport` (or others)
- Python equivalents
- Raw: how messages are read/written (stdin/stdout, HTTP handlers)

#### 2.1.2 Stdout Pollution (Death Rule for Stdio)

If stdio transport is used, flag **ANY stdout writes**, including:

- TS: `console.log`, `process.stdout.write`, logger handlers to stdout
- Python: `print()`, stdout handlers

Require stderr or MCP protocol logging instead.

**Deliverable:** Explicit subsection listing every stdout write site with evidence.

#### 2.1.3 Connection lifecycle & clean shutdown

Verify with evidence:

- `SIGINT` / `SIGTERM` handlers
- transport close/dispose
- server disconnect/stop
- outstanding request cancellation (if supported)

#### 2.1.4 Initialization & capability negotiation (CRITICAL)

Verify with evidence:

- `initialize` handled before other requests
- `notifications/initialized` ordering respected
- version negotiation behavior; disconnect on mismatch
- declared capabilities match implemented handlers
- server uses **only negotiated** capabilities (no assuming subscribe/listChanged unless negotiated)

### 2.2 Streamable HTTP Specifics (If Present)

Determine **stateless vs stateful** with evidence:

- Stateless: new transport per request, no session reuse
- Stateful: correct `sessionId` tracking, routing for:
  - POST (requests)
  - GET (SSE resume; `Last-Event-ID`)
  - DELETE (cleanup)

Security/hardening (evidence required):

- DNS rebinding protection (bind localhost and/or validate host header)
- Session header handling:
  - Express lowercases headers; expect `req.headers['mcp-session-id']`
- Origin validation:
  - If `Origin` present and invalid → 403 (where applicable)

Endpoint requirements:

- POST requests for JSON-RPC
- GET for SSE resumption
- DELETE for cleanup

## Phase 3 — Tools: Semantics, Schemas, Results, Errors, Logging

### 3.1 Tool schemas & validation

For every tool, verify with evidence:

- Explicit JSON Schema (Draft 07 or later) **or** strict validator:
  - TS: Zod (prefer `.strict()`), or equivalent
  - Python: Pydantic (forbid extra fields)
- Tool descriptions are LLM-usable (clear purpose, constraints)
- Input constraints (min/max/enum) where abuse is possible
- Unknown-field rejection where feasible

### 3.2 Tool results & error propagation

Verify with evidence:

- Tool results include:
  - `content` (text blocks; stringify JSON if needed)
  - `structuredContent` where supported
- Errors:
  - handled without uncaught throws
  - use `isError: true` in tool result where supported
- Logging:
  - protocol logging where available
  - avoid stdout

### 3.3 Annotations are hints only

Verify with evidence:

- Annotations (`readOnlyHint`, `idempotentHint`, `destructiveHint`, `openWorldHint`) are not treated as authorization.
- Any required enforcement is implemented separately (authz checks, allow-lists).

### 3.4 Completions (if implemented)

If `completion/complete` exists (evidence):

- Capability declared correctly
- Input validation for refs + args
- Result limit ≤ 100 + pagination if applicable
- Rate limiting / sensitive leakage protections

## Phase 4 — Resources & URI Patterns

Audit with evidence:

- Consistent URI scheme for resources
- `resources/read` validates URIs; rejects unexpected forms
- If resources change:
  - only emit `notifications/resources/updated` if capability supports it

## Phase 5 — Security & Isolation (High Priority)

Verify with evidence:

- Filesystem:
  - path traversal protections
  - **symlink resolution before allow-list checks** (`realpath`-style)
- Shell/db execution:
  - sanitization and parameterization
  - no string concatenation for commands/queries where risky
- HTTP-only:
  - DNS rebinding mitigations
  - intended bind address (e.g., localhost)
  - auth/session handling correctness

## Phase 6 — Advanced Reliability (Bonus)

Where evidenced, audit:

- Progress reporting for long tools (`notifications/progress`)
- Timeouts + cancellation behavior; maximum timeout enforcement
- Dynamic tool mutation correctness + `notifications/tools/list_changed` when used

## Required Output Format (Final Report)

### 1) Transport Integrity: Pass/Fail

- Identify transport(s): stdio vs HTTP/SSE
- Include explicit stdout pollution findings

### 2) Critical Issues (highest priority first)

For each issue:

- **Evidence:** reference one or more [E#] blocks (file + symbol + lines)
- **Fix:** concrete change (minimal code snippets allowed, aligned to detected runtime)
- **Verify:** measurable step(s):
  - unit/integration test (what to assert)
  - reproducible manual command + expected behavior
  - protocol-level validation (JSON-RPC shapes, capability match, SSE behavior)

### 3) Optimization Tips

Grounded in repo patterns; each tip includes Evidence → Fix → Verify.

### 4) Refactoring Plan

Prioritized steps:

- **P0:** crashers/security/protocol violations
- **P1:** transport robustness + validation hardening
- **P2:** ergonomics, progress, observability, cleanup

Include:

- minimal fix snippets (only where necessary)
- verification checklist per step

## Verification Checklist (Must Include)

For every Fix, include at least one:

- test suggestion (assertions)
- manual check command + expected output/behavior
- protocol transcript shape checks:
  - JSON-RPC: `jsonrpc:"2.0"`, `id` rules, `result` vs `error`, error codes (-32601/-32602/-32603)
  - MCP init ordering: `initialize` then `notifications/initialized`
  - HTTP: POST/GET(SSE)/DELETE correctness, session header behavior

## Response Format

- Start with **Phase 0: Detected Runtime/Style** (with evidence blocks).
- For each major section (Transport, Tools, Resources, Security, Reliability):
  1. **Extract Evidence Quotes** (list [E#] blocks)
  2. **Findings** (each finding references [E#])
- Produce the final report in the required 4-section format.
- Keep excerpts short, but sufficient to prove the claim.
- If line numbers aren’t directly available, provide the closest possible location markers (function name + surrounding code) and state line numbers are unavailable.
