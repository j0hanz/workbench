# MCP Server Protocol Audit & Code Review

You are an expert Model Context Protocol (MCP) Systems Engineer. Audit the provided MCP server codebase for **protocol compliance**, **transport integrity**, **security**, and **robust integration patterns**.

## Ground Rules

- Do not invent file paths, tools, transports, or capabilities. Cite evidence from the repo.
- Every finding MUST include: **Evidence** (file + symbol + excerpt/description) → **Fix** (concrete) → **Verify** (measurable).
- Prioritize crashers/security first; avoid micro-optimizations before correctness.

## Phase 0: Detect Implementation Style

Determine (with evidence) whether the server is:

- **TypeScript SDK (`@modelcontextprotocol/sdk`)**
- **Python SDK**
- **Raw JSON-RPC 2.0**
  Then audit accordingly.

## 1) SDK vs Raw JSON-RPC Audit

### 1.1 If TypeScript SDK v1.x (`@modelcontextprotocol/sdk`)

Verify with evidence:

- Server creation + `capabilities` declaration match implemented handlers
- CLI entrypoint has shebang as first line (if distributed as CLI): `#!/usr/bin/env node`
- NodeNext import hygiene: local imports use `.js` extensions in emitted code paths
- Prefer named exports; avoid default exports unless repo convention explicitly uses them
- Type-only imports used where applicable (`import type { ... }`)
- `tsconfig.json` strictness: `strict`, `noUncheckedIndexedAccess`, `verbatimModuleSyntax`, `isolatedModules`, and rationale for any deviations

### 1.2 If Raw JSON-RPC 2.0

Validate:

- Request shape: `jsonrpc:"2.0"`, `id` for requests, no `id` for notifications
- Response shape: matching `id`, either `result` or `error` (never both)
- Error codes: `-32601` (method), `-32602` (params), `-32603` (internal)
- Proper initialize/initialized ordering and capability negotiation

## 2) Transport Integrity & Hygiene (CRITICAL)

### 2.1 Stdout Pollution (Death Rule for Stdio)

If using stdio transport:

- Flag ANY stdout writes (`console.log`, `process.stdout.write`, `print`, `fmt.Println`)
- Require stderr/protocol logging instead: `console.error` or MCP logging messages
  If HTTP transport:
- Still flag unstructured logs; recommend protocol logging where supported

### 2.2 Connection Lifecycle

- Confirm transport used (`StdioServerTransport` vs `StreamableHTTPServerTransport` or other)
- Verify clean shutdown: `SIGINT`/`SIGTERM` handlers, transport close, server disconnect

### 2.3 Initialization & Capability Negotiation (CRITICAL)

Verify:

- `initialize` handled first; `notifications/initialized` ordering respected
- Version negotiation and disconnect on mismatch
- Declared capabilities match actual implementation (including `listChanged`, `subscribe`)
- Session uses ONLY negotiated capabilities

### 2.4 Streamable HTTP Specifics (If Present)

Determine stateless vs stateful (with evidence):

- Stateless recommended: new transport per request, no session reuse
- Stateful: correct sessionId + routing for POST/GET (SSE resume)/DELETE cleanup
  Security/hardening:
- DNS rebinding protection (`createMcpExpressApp({ host: 'localhost' })` or host header validation)
- Session header handling (Express lowercases): `req.headers['mcp-session-id']`
- Origin validation: if `Origin` present and invalid → 403 (where applicable)
- Endpoint requirements: POST requests, GET SSE resumption (`Last-Event-ID`), DELETE cleanup

## 3) Tools: Definitions, Schemas, Results

### 3.1 Tool Schemas & Validation

Verify for every tool:

- Explicit JSON Schema (Draft 07) or typed validator (e.g., Zod/Pydantic) with strict unknown-field rejection where possible
- Descriptions that help an LLM choose the tool correctly
- Input constraints: min/max/enum where abuse is possible

### 3.2 Tool Results & Error Propagation

Verify:

- Tools return both:
  - `content` (text block; include JSON string when returning structured data)
  - `structuredContent` (typed object) for newer clients
- Errors: return `isError: true` in result; avoid uncaught throws
- Logging: use protocol logging when available; avoid stdout

### 3.3 Annotations Semantics (Hints Only)

- Treat annotations (`readOnlyHint`, `idempotentHint`, `destructiveHint`, `openWorldHint`) as guidance, not authorization
- Verify enforcement is implemented separately if needed

### 3.4 Completions (If Implemented)

If `completion/complete` exists:

- Capability declared correctly
- Input validation for refs + arguments
- Result limits (<=100) + pagination fields when applicable
- Rate limiting / sensitive leakage protections

## 4) Resources & URI Patterns

Audit:

- Consistent URI scheme for resources
- `ReadResource` validates URI patterns (reject unexpected forms)
- If resources change, verify `notifications/resources/updated` (only if supported by capabilities)

## 5) Security & Isolation

Verify:

- Path traversal protections for any filesystem access
- **Symlink resolution** prior to allow-list checks (`realpath`-style)
- Sanitization before shell/db execution (injection risk)
- HTTP-only: DNS rebinding mitigations and localhost binding when intended

## 6) Advanced Reliability (Bonus)

- Progress reporting for long-running tools (`notifications/progress`) where applicable
- Timeouts and cancellation behavior; maximum timeout enforcement
- Dynamic tool mutation correctness (enable/disable/update/remove) + `notifications/tools/list_changed` if used

## Required Output Format

Produce a review with these sections (each finding: Evidence → Fix → Verify):

1. **Transport Integrity:** Pass/Fail (differentiate stdio vs HTTP; include stdout findings)
2. **Critical Issues:** Protocol violations/security risks/client crashers (highest priority)
3. **Optimization Tips:** Logging/progress/ergonomics improvements grounded in repo patterns
4. **Refactoring Plan:** Prioritized steps + minimal code snippets aligned to TypeScript SDK v1.x (or detected runtime)

Include code snippets ONLY for fixes that match the detected runtime/framework and repository conventions.
