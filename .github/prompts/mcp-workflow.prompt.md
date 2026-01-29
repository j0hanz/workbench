# MCP Server Protocol Audit & Code Review

## Context

**Role:** Expert Model Context Protocol (MCP) Systems Engineer + Security Reviewer  
**Stack:** Detect from repository (TypeScript MCP SDK `@modelcontextprotocol/sdk`, Python SDK, or raw JSON-RPC 2.0)  
**Complexity:** Chained System (Prompt Chaining + Quote-then-Answer)

## Objective

Audit the provided MCP server codebase for **protocol compliance**, **transport integrity**, **security**, and **robust integration patterns**, grounded strictly in repository evidence.

### Execution Strategy (Chained Phases)

Execute in phases:

1. **Repository Scan & Evidence Extraction** (quote-then-answer)
2. **Protocol & Transport Compliance Checks** (runtime-specific)
3. **Tool/Resource Semantics & Security Review**
4. **Produce Final Report** with actionable fixes and verification steps

## Ground Rules

- **Do not invent** file paths, tools, transports, endpoints, or capabilities.
- **Every finding MUST include:** Evidence → Fix → Verify
  - **Evidence:** file path + symbol/function/class name + a short excerpt or precise description (line numbers if available)
  - **Fix:** concrete change, aligned to detected runtime/framework and repo conventions
  - **Verify:** measurable check (tests, reproducible steps, assertions, logs, etc.)
- Prioritize **crashers and security** first. Avoid micro-optimizations before correctness.
- If repository lacks information needed to conclude something, state: **“Not evidenced in repo”** and explain what would prove it.

## Phase 0: Detect Implementation Style (Required)

Determine with evidence whether the server is:

- TypeScript SDK (`@modelcontextprotocol/sdk`)
- Python SDK
- Raw JSON-RPC 2.0

### Deliverable for Phase 0

- A short section: **Detected Runtime/Style** with evidence:
  - package.json dependencies / pyproject/requirements / imports
  - server/transport classes used
  - entrypoint location(s)

## Phase 1: SDK vs Raw JSON-RPC Audit

### 1.1 If TypeScript SDK v1.x (`@modelcontextprotocol/sdk`)

Verify with evidence:

- Server creation and **capabilities declaration** match implemented handlers
- CLI entrypoint has shebang as first line if distributed as CLI: `#!/usr/bin/env node`
- NodeNext import hygiene: local imports use `.js` extensions in emitted code paths
- Prefer named exports; avoid default exports unless repo convention explicitly uses them
- Use type-only imports where applicable (`import type { ... }`)
- `tsconfig.json` strictness:
  - `strict`
  - `noUncheckedIndexedAccess`
  - `verbatimModuleSyntax`
  - `isolatedModules`
  - Provide rationale for any deviations found in repo

### 1.2 If Raw JSON-RPC 2.0

Validate with evidence:

- Request shape: `jsonrpc:"2.0"`, `id` for requests, no `id` for notifications
- Response shape: matching `id`, either `result` OR `error` (never both)
- Error codes:
  - `-32601` method not found
  - `-32602` invalid params
  - `-32603` internal error
- Proper `initialize` / `initialized` ordering and capability negotiation

## Phase 2: Transport Integrity & Hygiene (CRITICAL)

### 2.1 Stdout Pollution (Death Rule for Stdio)

If using stdio transport:

- Flag **ANY stdout writes**:
  - TS: `console.log`, `process.stdout.write`, unstructured logger writing to stdout
  - Python: `print()`, stdout handlers
- Require stderr or protocol logging instead:
  - TS: `console.error` or MCP logging messages
  - Python: stderr logging or MCP logger
    If HTTP transport:
- Still flag unstructured logs; prefer protocol logging where supported

### 2.2 Connection Lifecycle

- Confirm transport used:
  - `StdioServerTransport` vs `StreamableHTTPServerTransport` or other
- Verify clean shutdown:
  - `SIGINT`/`SIGTERM` handlers
  - transport close
  - server disconnect

### 2.3 Initialization & Capability Negotiation (CRITICAL)

Verify:

- `initialize` handled first; `notifications/initialized` ordering respected
- Version negotiation; disconnect on mismatch
- Declared capabilities match actual implementation (including `listChanged`, `subscribe`)
- Session uses **ONLY negotiated** capabilities

### 2.4 Streamable HTTP Specifics (If Present)

Determine stateless vs stateful (with evidence):

- Stateless recommended: new transport per request, no session reuse
- Stateful: correct `sessionId` + routing for POST/GET (SSE resume)/DELETE cleanup

Security/hardening:

- DNS rebinding protection (e.g., bind localhost / host header validation)
- Session header handling (Express lowercases): `req.headers['mcp-session-id']`
- Origin validation: if `Origin` present and invalid → 403 (where applicable)
- Endpoint requirements: POST requests, GET SSE resumption (`Last-Event-ID`), DELETE cleanup

## Phase 3: Tools — Definitions, Schemas, Results

### 3.1 Tool Schemas & Validation

For every tool:

- Explicit JSON Schema (Draft 07) OR typed validator (Zod/Pydantic) with strict unknown-field rejection where possible
- Descriptions that help an LLM choose correctly
- Input constraints: min/max/enum where abuse is possible

### 3.2 Tool Results & Error Propagation

Verify:

- Tools return:
  - `content` (text block; include JSON string when returning structured data)
  - `structuredContent` (typed object) for newer clients
- Errors:
  - return `isError: true` in result (where supported)
  - avoid uncaught throws
- Logging:
  - use protocol logging when available
  - avoid stdout

### 3.3 Annotations Semantics (Hints Only)

- Treat annotations (`readOnlyHint`, `idempotentHint`, `destructiveHint`, `openWorldHint`) as guidance, not authorization
- Verify enforcement is implemented separately if needed

### 3.4 Completions (If Implemented)

If `completion/complete` exists:

- Capability declared correctly
- Input validation for refs + arguments
- Result limits (<=100) + pagination fields when applicable
- Rate limiting / sensitive leakage protections

## Phase 4: Resources & URI Patterns

Audit:

- Consistent URI scheme for resources
- `ReadResource` validates URI patterns (reject unexpected forms)
- If resources change, verify `notifications/resources/updated` only if supported by capabilities

## Phase 5: Security & Isolation

Verify:

- Path traversal protections for filesystem access
- Symlink resolution **prior** to allow-list checks (`realpath`-style)
- Sanitization before shell/db execution (injection risk)
- HTTP-only: DNS rebinding mitigations + intended localhost binding

## Phase 6: Advanced Reliability (Bonus)

- Progress reporting for long-running tools (`notifications/progress`) where applicable
- Timeouts and cancellation behavior; maximum timeout enforcement
- Dynamic tool mutation correctness + `notifications/tools/list_changed` if used

---

## Quote-then-Answer Workflow (MANDATORY)

For each section (Transport, Tools, Resources, Security, Reliability):

1. **Extract Evidence Quotes**
   - Bullet list of evidence blocks, each containing:
     - File path
     - Symbol (function/class/export)
     - Short excerpt or precise description (line numbers if available)
2. **Findings**
   - Each finding MUST reference one of the evidence blocks by file+symbol.

Never write a finding without evidence.

---

## Required Output Format

Produce a report with these sections:

1. **Transport Integrity:** Pass/Fail
   - Differentiate stdio vs HTTP
   - Include stdout pollution findings explicitly

2. **Critical Issues:**
   - Protocol violations / security risks / client crashers
   - Highest priority first
   - Each finding: Evidence → Fix → Verify

3. **Optimization Tips:**
   - Logging/progress/ergonomics improvements grounded in repo patterns
   - Each tip: Evidence → Fix → Verify

4. **Refactoring Plan:**
   - Prioritized steps (P0/P1/P2)
   - Minimal code snippets ONLY for fixes matching detected runtime/framework and repo conventions
   - Include verification checklist per step

---

## Verification Requirements (Measurable)

For each Fix, include at least one:

- A unit/integration test suggestion (what to assert)
- A reproducible manual check (exact command, expected behavior)
- A protocol-level validation (e.g., JSON-RPC shape, capability match, SSE behavior)

---

## Inputs You Will Receive

- The full repository contents (file tree + code).
- You must rely only on those files for evidence.
