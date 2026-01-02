# MCP TypeScript Server Review (MCP Spec 2025-11-25 current + TS SDK v1.x)

> **Target**: Find real, reproducible defects: protocol violations, security gaps, reliability failures.
>
> **Assumption**: Server is written in TypeScript and uses `@modelcontextprotocol/sdk` v1.x (high-level `McpServer`) or low-level request handlers.

## Required Output Contract

No praise. No hedging. Every finding MUST include:

`evidence` -> `impact` -> `fix` -> `verification`.

If you can't produce a reliable reproduction/verification step, do not report it.

---

## References (use as ground truth)

- [Spec versioning (current revision)](https://modelcontextprotocol.io/specification/versioning)
- [Spec index (latest)](https://modelcontextprotocol.io/specification/latest)
- [Base protocol overview (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic)
- [Key changes (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/key-changes)
- [Key changes (2025-06-18)](https://modelcontextprotocol.io/specification/2025-06-18/key-changes)
- [Lifecycle (2025-06-18)](https://modelcontextprotocol.io/specification/2025-06-18/basic/lifecycle)
- [Transports (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)
- [Tools (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
- [Resources (2025-03-26)](https://modelcontextprotocol.io/specification/2025-03-26/server/resources)
- [Prompts (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/server/prompts)
- [Sampling (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/client/sampling)
- [Elicitation (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/client/elicitation)
- [Tasks (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/tasks)
- [Roots (2025-06-18)](https://modelcontextprotocol.io/specification/2025-06-18/client/roots)
- [Completion (2025-03-26)](https://modelcontextprotocol.io/specification/2025-03-26/server/utilities/completion)
- [Logging (2024-11-05)](https://modelcontextprotocol.io/specification/2024-11-05/server/utilities/logging)
- [Progress (2024-11-05)](https://modelcontextprotocol.io/specification/2024-11-05/basic/utilities/progress)
- [Cancellation (2025-06-18)](https://modelcontextprotocol.io/specification/2025-06-18/basic/utilities/cancellation)
- [Authorization (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization)
- [Security best practices (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices)
- [TypeScript SDK repo + docs](https://github.com/modelcontextprotocol/typescript-sdk)
- [MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector)
- [CVE-2025-66414 advisory (SDK HTTP servers)](https://github.com/advisories/GHSA-w48q-cv73-mx4w)

Note: Some utility pages are last updated in 2024-11-05 or 2025-03-26; always confirm the current revision via the versioning page.

---

## Phase 1: Classify the Server

Scan `package.json`, the entry file(s), and transport setup.

Tip: SDK guidance prefers Streamable HTTP for remote servers, stdio for local servers, and HTTP+SSE only for legacy clients.

Fill in:

| Aspect           | Options                                                                                                              |
| ---------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Transport**    | `stdio` / `streamable-http` / `sse` (legacy) / `hybrid`                                                              |
| **SDK Surface**  | `high` (`McpServer.registerTool/registerResource/registerPrompt`) / `low` (`Server.setRequestHandler`) / `framework` |
| **Capabilities** | `tools` / `resources` / `prompts` / `logging` / `sampling` / `elicitation` / `completion` / `roots` / `tasks`        |
| **Risk Profile** | `R0` read-only / `R1` bounded local I/O / `R2` mutations/network / `R3` exec/credentials/PII                         |

Also record:

- Node runtime range (`engines.node`), TS target/module, and SDK version.
- Protocol revision negotiated during `initialize` (current is 2025-11-25).
- For Streamable HTTP: how `MCP-Protocol-Version` is handled (accept list, default, rejection).
- Whether the server is intended for local use only or exposed remotely; note auth mode if remote.

---

## Phase 2: Critical Defects (Stop Here)

Any item below is an automatic fail.

| #   | Defect                                         | Detection                                                                                                   | Impact                                            | Required Fix                                                                                                  |
| --- | ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 1   | **STDIO pollution**                            | Any stdout writes outside JSON-RPC (e.g. `console.log`, `process.stdout.write`, noisy child process output) | Client can't parse responses                      | Route logs to stderr (`console.error`) or MCP logging; ensure spawned processes don't write to stdout channel |
| 2   | **`outputSchema` without `structuredContent`** | Tool defines `outputSchema` but sometimes returns only `content`                                            | SDK/client rejects tool result                    | Always return `structuredContent` that conforms to schema                                                     |
| 3   | **Error path breaks schema**                   | Tool with `outputSchema` returns `{ isError: true }` but omits schema-conforming `structuredContent`        | Tool can't report errors (SDK may throw `-32602`) | Ensure error results still include schema-conforming `structuredContent` (use an envelope schema)             |
| 4   | **Silent errors**                              | catch blocks swallow errors or return success-ish content                                                   | Hidden failures; agent misled                     | Always return `isError: true` and a structured error payload                                                  |
| 5   | **Missing shutdown**                           | No `SIGINT`/`SIGTERM` cleanup and transport close                                                           | Zombie server / corrupted state                   | Implement idempotent shutdown that closes server/transport                                                    |
| 6   | **Root/path escape**                           | File access without canonicalization + allowlist                                                            | Arbitrary file read/write                         | Resolve + realpath + verify against allowed roots                                                             |
| 7   | **Unbounded I/O**                              | `fetch`, DB ops, fs ops, `spawn` without timeouts                                                           | Hangs indefinitely                                | Time-limit all external calls (`AbortSignal.timeout(...)` / driver timeouts / kill timers)                    |
| 8   | **HTTP DNS rebinding exposure**                | Streamable HTTP/SSE server on localhost without Host allowlist validation (or SDK < 1.24.0)                 | Browser can attack local server                   | Use `createMcpExpressApp()` or `hostHeaderValidation(...)` and upgrade to a fixed SDK version                 |
| 9   | **Origin/Host not validated**                  | HTTP server accepts arbitrary `Host`/`Origin`                                                               | DNS rebinding / cross-site abuse                  | Enforce allowlists; reject invalid requests (typically 403)                                                   |
| 10  | **Unsupported protocol version accepted**      | Ignores `MCP-Protocol-Version` / `initialize.protocolVersion` and proceeds                                  | Undefined behavior, incompatibilities, security   | Enforce version negotiation; reject unsupported versions with 400 or JSON-RPC error                           |

### Fast scans

Prefer ripgrep (`rg`) if available; otherwise `grep`.

```sh
rg "console\\.log|process\\.stdout\\.write" src
rg "createMcpExpressApp\(|hostHeaderValidation\(|StreamableHTTP" src
rg "MCP-Protocol-Version|Mcp-Session-Id" src
rg "registerTool\(|outputSchema|structuredContent" src
rg "notifications/(tools|resources|prompts)/list_changed|resources/subscribe" src
rg "completion/complete|prompts/get|resources/templates/list" src
rg "catch \(|catch\(" src
rg "fetch\(|spawn\(|exec\(|readFile\(|writeFile\(" src
```

---

## Phase 3: Review Checklist

Work through in order. Skip sections that don't apply.

### 3.1 Transport Integrity

#### STDIO

- No `console.log` (stdout). No other stdout writes. No libraries writing banners to stdout.
- If running via package managers, ensure the wrapper doesn't print to stdout (e.g., `npm` output can contaminate the channel).
- STDIO is line-delimited JSON-RPC: one JSON object per line and nothing else on stdout.
- Use UTF-8 encoding for transport payloads.
- JSON-RPC batching is only supported in 2025-03-26; it is removed in 2025-06-18+. Reject array payloads when running newer revisions.
- Enforce lifecycle: `initialize` must be first; do not accept non-init requests before it, and do not cancel `initialize`.
- After `initialize`, wait for `notifications/initialized` before sending any requests to the client.
- Logging must go to stderr (`console.error`) or MCP logging capability.
- JSON-RPC IDs must be strings or numbers (not `null`) and unique for in-flight requests.

Bad:

```ts
console.log('Starting...');
```

Allowed:

```ts
console.error('Starting...');
server.server.sendLoggingMessage({ level: 'info', data: 'Starting...' });
```

#### Streamable HTTP

- Prefer the SDK's safe helpers:
  - `createMcpExpressApp()` (DNS rebinding protection defaults for localhost)
  - or `hostHeaderValidation([...allowedHosts])`
- Single endpoint must support both `POST` and `GET` for Streamable HTTP.
- `MCP-Protocol-Version` header is required; reject unsupported versions (400). If missing, default to 2025-03-26.
- `Accept` handling:
  - `POST` must accept `application/json` and optionally `text/event-stream`.
  - `GET` must accept `text/event-stream`.
- `POST` must use `Content-Type: application/json`.
- Response rules:
  - For JSON-RPC **requests**, respond with JSON or start SSE.
  - For **responses/notifications**, return 202 with no body.
- Bind `localhost` / `127.0.0.1` by default for local servers.
- If binding to `0.0.0.0` or exposing remotely: require authentication and explicit allowlists.
- Validate `Origin` (if present) against an allowlist and reject if invalid (403).
- **Proxy Awareness**: If running behind a proxy, ensure `HTTP_PROXY` env vars don't cause `undici`/`fetch` to attempt `CONNECT` tunnels for plain HTTP.

Session correctness (stateful mode):

- If using a session ID generator, you MUST route all subsequent `POST`, `GET`, and `DELETE` requests for that session to the same transport instance.
- Sessions are identified by the `Mcp-Session-Id` header; reject missing/unknown session IDs where required.
- You MUST implement `DELETE` to close server-side session state (or return 405 if not supported).
- You MUST close transports on connection close (e.g., `res.on('close', ...)`).
- For invalid or terminated session IDs, return 404.

Common defect patterns:

- Creating a new `StreamableHTTPServerTransport` per request (breaks sessions).
- Supporting `POST` only (clients may rely on `GET`/`DELETE` for streaming/session lifecycle).
- **SSE Noise**: `StreamableHTTPClientTransport` may log connection failures noisily; ensure error handling suppresses expected disconnects.

#### SSE (legacy)

- Only support if required for backwards compatibility; prefer Streamable HTTP.
- Apply the same host/origin protections.

---

### 3.2 Tool Definitions (Schema + Output)

For each tool:

- `inputSchema` MUST be a valid JSON Schema object (not `null`), and defaults to JSON Schema 2020-12 if no `$schema` is set.
- For tools with no parameters, use `{ "type": "object", "additionalProperties": false }` (recommended) or `{ "type": "object" }`.
- Follow tool name guidance: 1-128 chars, case-sensitive, ASCII letters/digits/underscore/hyphen/dot, no spaces; unique within the server.
- Validate and bound risky inputs; reject unknown fields where possible.
- No `z.any()` in mutation/network tools; prefer `z.unknown()` only when unavoidable and then validate internally.
- Add size limits: `.max(...)` on strings/arrays; `.int().min().max()` on numbers.

**Output schema rule**:

- If `outputSchema` is declared, the tool MUST return `structuredContent` every time.
- For backwards compatibility, include a JSON string in `content` (a TextContent block) that matches `structuredContent`.
- If `tools.listChanged` is true in capabilities, send `notifications/tools/list_changed` when the list changes.
- If returning resource links or embedded resources, ensure the resources capability is implemented; resource links may not appear in `resources/list`.
- Tool annotations are hints only; do not use them for access control or security decisions.
- `_meta` is reserved; avoid custom keys (especially `mcp.` prefixed keys).

**Error rule (critical)**:

- If a tool has an `outputSchema`, errors must still provide schema-conforming `structuredContent`.
- Do not rely on throwing exceptions for user-facing tool errors; return `isError: true` with a structured error payload.
- Input validation failures should be reported as tool execution errors (not protocol errors).

Recommended output envelope pattern:

```ts
// outputSchema should validate this envelope
type Envelope<T> =
  | { ok: true; result: T }
  | { ok: false; error: { code: string; message: string } };
```

Handler pattern:

```ts
try {
  const structured = { ok: true, result };
  return {
    content: [{ type: 'text', text: JSON.stringify(structured) }],
    structuredContent: structured,
  };
} catch (err) {
  const structured = {
    ok: false,
    error: { code: 'E_FAILED', message: getErrorMessage(err) },
  };
  return {
    content: [{ type: 'text', text: JSON.stringify(structured) }],
    structuredContent: structured,
    isError: true,
  };
}
```

---

### 3.3 Resources & URI Templates

- `resources/list` must support pagination; return `nextCursor` when needed.
- `resources/read` returns a `contents` array with text or base64 `blob`, plus `mimeType` and `uri`.
- If `resources.listChanged` is true, send `notifications/resources/list_changed` when the list changes.
- If `resources.subscribe` is true, implement `resources/subscribe` and send `notifications/resources/updated`.
- `resources/templates/list` should be implemented when you expose URI templates; use `completion/complete` for template variables.
- Resource reads MUST be bounded (size limits, paging, and timeouts).
- Set correct `mimeType` for all content.
- If resources read from disk: apply the same roots/realpath validation as tools.
- **URI Template Strictness**: RFC 6570 matching is strict.
  - Missing optional params may cause "Resource not found".
  - **Fix**: Define templates precisely matching client usage, or register multiple templates for variations.

---

### 3.4 Prompts (Injection-Safe)

- `prompts/list` must support pagination; return `nextCursor` when needed.
- If `prompts.listChanged` is true, send `notifications/prompts/list_changed` when the list changes.
- `prompts/get` returns messages; content can be text, image, audio, or embedded resources.
- Image/audio content must include `mimeType` and base64 data.
- Prompt argument completion should use `completion/complete`.
- All prompt args must be schema-validated and size-limited.
- Wrap user-provided text in explicit delimiters:

```text
<user_input>
...user text...
</user_input>
```

- Sanitize before display/logging (strip control chars; remove RTL overrides).
- Never place raw user input into "system" instructions.

---

### 3.5 Completion (Optional)

- If `completion` capability is declared, implement `completion/complete`.
- Use completions for prompt argument values and resource template variables.
- Limit completion results (spec suggests max 100) and validate query inputs.
- Treat completions as hints; never trust them for security decisions.

---

### 3.6 Sampling & Elicitation (Only If Supported)

- Only call sampling if the client declares the capability.
- Only send tool-enabled sampling requests if the client declares `sampling.tools`.
- `includeContext: "thisServer"` and `"allServers"` are soft-deprecated; avoid unless the client declares `sampling.context`.
- Sampling is human-in-the-loop; expect user review/approval.
- Apply hard limits:
  - `maxDepth` (3-5)
  - per-call timeout
  - max tokens / max output size
- Elicitation:
  - Use `form` mode only for non-sensitive inputs.
  - Use `url` mode for sensitive flows (API keys, OAuth, payments).
- For `url` mode, bind requests to user identity and protect against tampering.

---

### 3.7 Tasks (If Supported)

- Only expose tasks if the client declares the `tasks` capability.
- Implement `tasks/list` with pagination and stable identifiers.
- Implement `tasks/cancel` and move tasks to a terminal cancelled state.
- Use task updates to report progress for long-running work; keep status transitions consistent.

---

### 3.8 Security

Authorization (HTTP only):

- If exposed over HTTP, follow the MCP authorization spec (OAuth 2.1); do not invent ad-hoc token schemes.
- Validate access tokens (audience/resource), and never pass client tokens through to upstream APIs.
- Use HTTPS for auth flows and enforce exact redirect URIs/PKCE.
- STDIO servers should rely on local OS/process boundaries rather than HTTP auth.

Filesystem access requirements:

- Canonicalize: `path.resolve` + `fs.realpath` (or equivalent) before allowlist checks.
- Validate against the client-provided allowed roots (or an explicit server allowlist).
- Deny traversal and symlink escapes.
- Do not leak full paths or secrets in error messages.

Roots:

- If `roots` capability is used, honor the client-provided roots and update when `notifications/roots/list_changed` arrives.

Network/SSRF requirements:

- If the tool accepts URLs, restrict schemes (`https:`), restrict hosts (allowlist), and cap redirects.
- Time-limit all network calls.

Session IDs:

- Treat session IDs as opaque routing tokens, not authentication.
- Use cryptographically random session IDs and avoid logging them.

---

### 3.9 Async Safety & Reliability

- All external I/O must have timeouts:
  - `fetch(url, { signal: AbortSignal.timeout(10_000) })`
  - `fs.promises.readFile(..., { signal: AbortSignal.timeout(5_000) })` (Node 20+)
  - DB driver timeouts or `Promise.race` with a hard timer
  - `spawn` kill timers
- Concurrency controls for expensive operations (limit parallel DB/file ops).
- Idempotency:
  - Mark read-only tools as retry-safe.
  - For mutation tools: ensure retries don't double-apply (use IDs or compare-and-swap patterns).
- Cancellation:
  - Respect `notifications/cancelled` for in-flight requests.
  - Never cancel `initialize`; treat cancellation for unknown IDs as no-op.
- Progress:
  - Use progress notifications for long-running work; keep `progressToken` stable.
  - Reset timeouts on progress only if you enforce a hard overall cap.

---

### 3.10 Cleanup / Process Lifecycle

- Implement idempotent shutdown (`SIGINT`, `SIGTERM`).
- Close transports and persistent resources (DB connections, file handles).
- Handle `unhandledRejection` and `uncaughtException` by logging to stderr and exiting non-zero.
- **Zombie Prevention**: If possible, monitor parent process PID and exit if it dies (orphaned server).

---

### 3.11 TypeScript & Build Configuration

- Use the v1.x docs/branch for `@modelcontextprotocol/sdk`; the `main` branch is v2 pre-alpha.
- Install the `zod` peer dependency (v3.25+ or v4); import from `zod/v3` or `zod/v4` to match your version.
- **Module Resolution**: Ensure `moduleResolution` is set to `NodeNext` or `Bundler` to avoid import issues with ESM/CJS.

---

## Phase 4: Findings Output

Return a JSON array sorted by severity (critical -> warning -> suggestion):

```json
[
  {
    "severity": "critical | warning | suggestion",
    "category": "transport | schema | security | async | reliability | injection",
    "location": "src/tools/foo.ts:42",
    "issue": "Tool declares outputSchema but error path omits structuredContent",
    "evidence": "return { isError: true, content: [...] }",
    "impact": "SDK rejects tool result; client receives -32602",
    "fix": "Return a schema-conforming structuredContent envelope even on errors",
    "verification": "rg \"outputSchema\" src && rg \"isError: true\" src"
  }
]
```

---

## Phase 5: Quick Verification Suite

Prefer black-box verification with MCP Inspector.

| Test                        | How                                                                          | Expected                                      |
| --------------------------- | ---------------------------------------------------------------------------- | --------------------------------------------- |
| STDIO clean                 | Run via Inspector (`npx @modelcontextprotocol/inspector node dist/index.js`) | No parse errors; no stdout noise              |
| Unknown fields rejected     | Call a tool with extra keys                                                  | Validation error, no crash                    |
| Schema enforcement          | Call tool with wrong types                                                   | JSON-RPC error or `isError: true` tool result |
| Protocol version mismatch   | Send unsupported `MCP-Protocol-Version` / `initialize.protocolVersion`       | 400 or JSON-RPC error                         |
| Path traversal              | Try `../` or `file:///...` outside roots                                     | Denied                                        |
| Timeout                     | Block network / slow endpoint                                                | Error within 10-30s                           |
| Streamable HTTP host/origin | Send invalid `Host`/`Origin`                                                 | Rejected (typically 403)                      |
| HTTP Accept/202 behavior    | Send notifications/responses over POST                                       | HTTP 202 with no body                         |
| Session correctness         | Initialize then call tool using returned session header                      | Works across subsequent requests              |
| ListChanged notifications   | Change tools/resources/prompts list                                          | `notifications/*/list_changed` emitted        |
| Completion                  | Call `completion/complete` for prompt/resource args                          | Results returned (<= 100)                     |
| Cancellation                | Cancel a long-running request                                                | Work stops; no success result                 |

---

## Appendix: Platform-Friendly Search Commands

### Cross-platform (ripgrep)

```sh
rg "console\\.log|process\\.stdout\\.write" src
rg "createMcpExpressApp\(|hostHeaderValidation\(|StreamableHTTP" src
rg "MCP-Protocol-Version|Mcp-Session-Id" src
rg "outputSchema|structuredContent" src
rg "notifications/(tools|resources|prompts)/list_changed|resources/subscribe" src
rg "completion/complete|prompts/get|resources/templates/list" src
rg "AbortSignal\\.timeout\(" src
```

### Fallback (grep)

```sh
grep -R "console.log" src --include="*.ts"
grep -R "createMcpExpressApp\\|hostHeaderValidation\\|StreamableHTTP" src --include="*.ts"
grep -R "MCP-Protocol-Version\\|Mcp-Session-Id" src --include="*.ts"
grep -R "outputSchema" src --include="*.ts"
grep -R "structuredContent" src --include="*.ts"
```
