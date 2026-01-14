# MCP TypeScript Server Review (MCP Spec 2025-11-25 current + TS SDK v1.x)

> **Target**: Find real, reproducible defects: protocol violations, security gaps, reliability failures.
>
> **Assumption**: Server is written in TypeScript and uses `@modelcontextprotocol/sdk` v1.x (high-level `McpServer`) or low-level request handlers.

## Required Output Contract

No praise. No hedging. Every finding MUST include:

`evidence` -> `impact` -> `fix` -> `verification`.

If you can't produce a reliable reproduction/verification step, do not report it.

## Reviewer Rubric (Severity + Evidence Bar)

Classify each finding by severity and hold yourself to the evidence bar. When in doubt, downgrade severity unless you can show clear impact.

### Severity

Use these exact labels in outputs: `blocker | high | medium | low | nit`.

- **Blocker** (`blocker`): Spec violation or security issue that breaks protocol correctness, leaks secrets, enables unauthorized access, or makes the server unusable.
- **High** (`high`): Likely to break common clients or cause data loss/corruption; serious interoperability risk.
- **Medium** (`medium`): Correctness/compatibility issue with workaround; partial feature break; important but not catastrophic.
- **Low** (`low`): Minor spec mismatch, edge-case bug, or quality problem that doesn't materially affect interoperability.
- **Nit** (`nit`): Style, naming, minor doc/ergonomics; no functional impact.

### Evidence Bar (required for every finding)

- **Evidence**: Point to the exact location (file path + line range) or an API trace/log snippet, and cite the relevant spec section/link.
- **Repro**: Provide deterministic steps or a minimal request/response transcript to reproduce.
- **Impact**: Explain what breaks (which clients, which flows, what security property).
- **Fix**: Give a concrete change (API/behavior) that aligns with the spec.
- **Verification**: Provide a post-fix check (unit/integration test, curl script, or trace expectation).

---

## References (use as ground truth)

### Specification (2025-11-25 current)

- [Spec versioning (current revision)](https://modelcontextprotocol.io/specification/versioning)
- [Spec index (latest)](https://modelcontextprotocol.io/specification/latest)
- [Architecture (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/architecture)
- [Base protocol overview (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic)
- [Lifecycle (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle)
- [Transports (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)
- [Authorization (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization)
- [Security best practices (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices)

### Server Primitives

- [Server overview (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/server)
- [Tools (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
- [Resources (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/server/resources)
- [Prompts (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/server/prompts)
- [Completion (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/server/utilities/completion)
- [Logging (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/server/utilities/logging)
- [Pagination (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/server/utilities/pagination)

### Client Primitives

- [Sampling (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/client/sampling)
- [Elicitation (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/client/elicitation)
- [Roots (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/client/roots)

### Utilities

- [Cancellation (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/cancellation)
- [Ping (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/ping)
- [Progress (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/progress)
- [Tasks (2025-11-25, experimental)](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/tasks)

### Key Changes

- [Key changes (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/key-changes)
- [Key changes (2025-06-18)](https://modelcontextprotocol.io/specification/2025-06-18/key-changes)

### Tools & Advisories

- [TypeScript SDK repo + docs](https://github.com/modelcontextprotocol/typescript-sdk)
- [MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector)
- [CVE-2025-66414 advisory (SDK HTTP servers)](https://github.com/advisories/GHSA-w48q-cv73-mx4w)

---

## Phase 1: Classify the Server

Scan `package.json`, the entry file(s), and transport setup.

Tip: SDK guidance prefers Streamable HTTP for remote servers, stdio for local servers, and HTTP+SSE only for legacy clients.

Fill in:

| Aspect           | Options                                                                                                                         |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **Transport**    | `stdio` / `streamable-http` / `sse` (legacy) / `hybrid`                                                                         |
| **SDK Surface**  | `high` (`McpServer.registerTool/registerResource/registerPrompt`) / `low` (`Server.setRequestHandler`) / `framework`            |
| **Capabilities** | `tools` / `resources` / `prompts` / `logging` / `sampling` / `elicitation` / `completions` / `roots` / `tasks` _(experimental)_ |
| **Risk Profile** | `R0` read-only / `R1` bounded local I/O / `R2` mutations/network / `R3` exec/credentials/PII                                    |

Also record:

- Node runtime range (`engines.node`), TS target/module, and SDK version.
- Protocol revision negotiated during `initialize` (current is 2025-11-25).
- For Streamable HTTP: how `MCP-Protocol-Version` is handled (accept list, default, rejection).
- Whether the server is intended for local use only or exposed remotely; note auth mode if remote.
- Icons usage: whether `icons` arrays are exposed on tools/resources/prompts (security consideration for external URLs).

---

## Phase 2: Critical Defects (Stop Here)

Any item below is an automatic fail. Report each one as `severity: blocker`.

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
| 11  | **Token passthrough to upstream APIs**         | Server forwards client access tokens to external services                                                   | Credential leakage; confused deputy attacks       | NEVER pass through tokens; use server's own credentials for upstream calls                                    |
| 12  | **Progress value decreasing**                  | Progress notifications send decreasing values (except for new phases)                                       | Clients display inconsistent progress UI          | Ensure progress value MUST increase; reset to 0 only for new operation phases                                 |

### Fast scans

Prefer ripgrep (`rg`) if available; otherwise `grep`.

```sh
rg "console\\.log|process\\.stdout\\.write" src
rg "createMcpExpressApp\(|hostHeaderValidation\(|StreamableHTTP" src
rg "MCP-Protocol-Version|MCP-Session-Id" src
rg "registerTool\(|outputSchema|structuredContent" src
rg "notifications/(tools|resources|prompts)/list_changed|resources/subscribe" src
rg "completion/complete|prompts/get|resources/templates/list" src
rg "tasks/(list|get|cancel|result)|execution\.taskSupport" src
rg "progressToken|notifications/progress" src
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
- Single endpoint (the MCP endpoint) must support both `POST` and `GET` for Streamable HTTP.
- Protocol version header:
  - Clients MUST send `MCP-Protocol-Version: <version>` on HTTP requests.
  - If the server receives an invalid or unsupported `MCP-Protocol-Version`, it MUST respond with `400 Bad Request`.
  - Backwards-compat: if `MCP-Protocol-Version` is missing and the server has no other way to identify the version (e.g., no negotiated version from initialization), the server SHOULD assume `2025-03-26`.
- **Accept header handling**:
  - `POST`: client MUST include an `Accept` header listing BOTH `application/json` and `text/event-stream`.
  - `GET`: client MUST include an `Accept` header listing `text/event-stream`.
  - Server behavior MUST interoperate with those headers (do not 406/400 on the required Accept combinations).
- **Content-Type**: `POST` requests must use `Content-Type: application/json`.
- **Response rules**:
  - For JSON-RPC **requests**: respond with JSON or start SSE stream.
  - For **responses/notifications**: return **202 Accepted** with no body.
  - For **invalid/terminated session IDs**: return **404 Not Found**.
  - For **invalid requests**: return appropriate 4xx error.
- Bind `localhost` / `127.0.0.1` by default for local servers.
- If binding to `0.0.0.0` or exposing remotely: require authentication and explicit allowlists.
- Validate `Origin` header (if present) against an allowlist and reject if invalid (403).
- **Proxy Awareness**: If running behind a proxy, ensure `HTTP_PROXY` env vars don't cause `undici`/`fetch` to attempt `CONNECT` tunnels for plain HTTP.

**Session management (stateful mode)**:

- `MCP-Session-Id` header identifies the session after initialization.
- Servers MUST NOT require `MCP-Session-Id` on the **first request** (initialization).
- If the server assigns a session ID, it returns `MCP-Session-Id` on the HTTP response containing the `InitializeResult`.
  - Session IDs MUST contain only visible ASCII characters (0x21 to 0x7E) and SHOULD be cryptographically secure.
- After initialization, the client MUST include `MCP-Session-Id` in all subsequent HTTP requests.
  - If the server requires a session ID, it SHOULD respond (for non-initialization requests missing `MCP-Session-Id`) with `400 Bad Request`.
- Route all `POST`, `GET`, and `DELETE` requests for a session to the same transport instance.
- **DELETE method**: MUST be implemented to close server-side session state (or return 405 if not supported).
- Close transports on connection close (e.g., `res.on('close', ...)`).
- For invalid or terminated session IDs, return **404**.
  - When a client receives HTTP 404 in response to a request containing `MCP-Session-Id`, it MUST start a new session by sending a new `InitializeRequest` without a session ID.

**SSE streaming / polling / resumability**:

- For a POST carrying a JSON-RPC request, the server MUST respond with either:
  - `Content-Type: application/json` (single JSON-RPC response object), OR
  - `Content-Type: text/event-stream` (SSE stream for one or more messages).
- If the server initiates an SSE stream:
  - It SHOULD immediately send an SSE event with an event ID and an empty `data:` field to prime client reconnection (`Last-Event-ID`).
  - It MAY close the connection without terminating the stream; clients SHOULD poll by reconnecting.
  - If it closes the connection without terminating the stream, it SHOULD send an SSE `retry:` field first; clients MUST respect it.
  - Disconnection MUST NOT be treated as cancellation; cancellation should be via `notifications/cancelled`.
  - It SHOULD terminate the stream after emitting the JSON-RPC response for the originating request.
- Listening via HTTP GET:
  - Server MUST return `Content-Type: text/event-stream` OR `405 Method Not Allowed`.
  - Server MUST NOT send JSON-RPC _responses_ on the GET stream unless resuming/redelivering a previously interrupted stream.
- Multiple SSE connections:
  - Client MAY connect multiple streams.
  - Server MUST NOT broadcast the same JSON-RPC message to multiple streams.
- Resumption:
  - Client SHOULD resume via HTTP GET with `Last-Event-ID`.
  - Server MUST NOT replay messages that would have been delivered on a different stream.

**Common defect patterns**:

- Creating a new `StreamableHTTPServerTransport` per request (breaks sessions).
- Supporting `POST` only (clients may rely on `GET`/`DELETE` for streaming/session lifecycle).
- Missing 202 response for notifications/responses over POST.
- **SSE Noise**: `StreamableHTTPClientTransport` may log connection failures noisily; ensure error handling suppresses expected disconnects.

#### SSE (legacy)

- Only support if required for backwards compatibility; prefer Streamable HTTP.
- Apply the same host/origin protections.

---

### 3.2 Tool Definitions (Schema + Output)

For each tool:

- `inputSchema` MUST be a valid JSON Schema object (not `null`), and defaults to JSON Schema 2020-12 if no `$schema` is set.
- For tools with no parameters, use `{ "type": "object", "additionalProperties": false }` (recommended) or `{ "type": "object" }`.
- **Tool name rules**: 1-128 chars, case-sensitive, ASCII letters/digits/underscore/hyphen/dot only, no spaces; unique within the server.
- Validate and bound risky inputs; reject unknown fields where possible.
- No `z.any()` in mutation/network tools; prefer `z.unknown()` only when unavoidable and then validate internally.
- Add size limits: `.max(...)` on strings/arrays; `.int().min().max()` on numbers.

**Optional metadata**:

- `title`: Human-readable display name (optional but recommended for UX).
- `icons`: Array of icon objects with `src`, `mimeType`, and `sizes` (optional; use only trusted URLs).
- `description`: Human-readable description of functionality.

**Output schema rule**:

- If `outputSchema` is declared, the tool MUST return `structuredContent` every time.
- For backwards compatibility, include a JSON string in `content` (a TextContent block) that matches `structuredContent`.
- If `tools.listChanged` is true in capabilities, send `notifications/tools/list_changed` when the list changes.

**Tool result content types**:

| Type            | Fields                                             | Notes                                           |
| --------------- | -------------------------------------------------- | ----------------------------------------------- |
| `text`          | `type`, `text`                                     | Plain text result                               |
| `image`         | `type`, `data` (base64), `mimeType`                | Image content                                   |
| `audio`         | `type`, `data` (base64), `mimeType`                | Audio content (new in 2025-11-25)               |
| `resource_link` | `type`, `uri`, `name`, `description?`, `mimeType?` | Link to a resource (client can fetch/subscribe) |
| `resource`      | `type`, `resource: { uri, text/blob, mimeType }`   | Embedded resource content                       |

- If returning resource links or embedded resources, ensure the `resources` capability is implemented.
- Resource links may not appear in `resources/list` (they are returned by tools, not listed).
- All content items support optional `annotations`: `audience` (`["user"]`, `["assistant"]`, or both), `priority` (0.0-1.0).
- `_meta` is reserved; avoid custom keys (especially `mcp.` prefixed keys).
- Tool annotations are hints only; do not use them for access control or security decisions.

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

- `resources/list` must support pagination (cursor-based); return `nextCursor` when needed.
- `resources/read` returns a `contents` array with text or base64 `blob`, plus `mimeType` and `uri`.
- If `resources.listChanged` is true, send `notifications/resources/list_changed` when the list changes.
- If `resources.subscribe` is true, implement `resources/subscribe` and send `notifications/resources/updated`.
- `resources/templates/list` should be implemented when you expose URI templates; use `completion/complete` for template variables.
- Resource reads MUST be bounded (size limits, paging, and timeouts).
- Set correct `mimeType` for all content.
- If resources read from disk: apply the same roots/realpath validation as tools.

**Resource metadata**:

- `name`: Required identifier for the resource.
- `title`: Optional human-readable display name.
- `description`: Optional description.
- `icons`: Optional array of icon objects with `src`, `mimeType`, and `sizes`.
- `size`: Optional size in bytes.

**Annotations** (on resources and content blocks):

| Annotation     | Type                                 | Description                                 |
| -------------- | ------------------------------------ | ------------------------------------------- |
| `audience`     | `["user"]`, `["assistant"]`, or both | Who should see this resource                |
| `priority`     | Number 0.0-1.0                       | Importance (1.0 = required, 0.0 = optional) |
| `lastModified` | ISO 8601 timestamp                   | When the resource was last modified         |

**Error codes**:

- Resource not found: `-32002`
- Internal errors: `-32603`

**URI Template Strictness**: RFC 6570 matching is strict.

- Missing optional params may cause "Resource not found".
- **Fix**: Define templates precisely matching client usage, or register multiple templates for variations.

**Common URI schemes**:

- `https://` - Web resources (only if client can fetch directly)
- `file://` - Filesystem-like resources (may use XDG MIME types like `inode/directory`)
- `git://` - Git version control integration
- Custom schemes MUST comply with RFC 3986

---

### 3.4 Prompts (Injection-Safe)

- `prompts/list` must support pagination (cursor-based); return `nextCursor` when needed.
- If `prompts.listChanged` is true, send `notifications/prompts/list_changed` when the list changes.
- `prompts/get` returns messages; content can be text, image, audio, or embedded resources.

**Prompt content types**:

| Type       | Fields                                           | Notes              |
| ---------- | ------------------------------------------------ | ------------------ |
| `text`     | `type`, `text`                                   | Plain text content |
| `image`    | `type`, `data` (base64), `mimeType`              | Image content      |
| `audio`    | `type`, `data` (base64), `mimeType`              | Audio content      |
| `resource` | `type`, `resource: { uri, text/blob, mimeType }` | Embedded resource  |

- Image/audio content must include `mimeType` and base64 `data`.
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

- If `completions` capability is declared, implement `completion/complete`.
- Use completions for prompt argument values and resource template variables.

**Reference types**:

| Type           | Description                        | Example                                               |
| -------------- | ---------------------------------- | ----------------------------------------------------- |
| `ref/prompt`   | References a prompt by name        | `{ "type": "ref/prompt", "name": "code_review" }`     |
| `ref/resource` | References a resource URI template | `{ "type": "ref/resource", "uri": "file:///{path}" }` |

**Multi-argument context**:

- For prompts with multiple arguments, include previously completed values in `context.arguments`.
- This allows context-aware completions (e.g., framework suggestions based on selected language).

**Limits and validation**:

- Maximum 100 completion values per response.
- Response includes `total` (optional total matches) and `hasMore` flag.
- Treat completions as hints; never trust them for security decisions.
- Rate limit completion requests server-side.
- Validate all query inputs.

**Error handling** (standard JSON-RPC errors):

- Capability not supported / method not found: `-32601`
- Invalid prompt/resource reference or missing/invalid arguments: `-32602`
- Internal errors: `-32603`

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

### 3.7 Tasks (Experimental)

> **Note**: Tasks are an experimental feature for durable, potentially long-running operations.

- Only use tasks if BOTH sides negotiate `capabilities.tasks` during initialization.
- Capabilities are structured by request category (e.g., server: `tasks.list`, `tasks.cancel`, and `tasks.requests.tools.call`).
- Tool calls add a second layer: tools MAY declare `execution.taskSupport` in `tools/list` results (`"required" | "optional" | "forbidden"`).
  - If `tasks.requests.tools.call` is NOT declared by the server, clients MUST NOT task-augment `tools/call` regardless of `execution.taskSupport`.
  - If `execution.taskSupport` is absent or `"forbidden"`, clients MUST NOT task-augment that tool; if they do, server SHOULD return `-32601`.
  - If `execution.taskSupport` is `"required"`, clients MUST task-augment; if they don't, server MUST return `-32601`.

**Task status lifecycle**:

```
working → completed (success)
working → failed (error)
working → cancelled (via tasks/cancel)
working → input_required (waiting for user input via elicitation)
```

**Required operations**:

| Method         | Description                                                                |
| -------------- | -------------------------------------------------------------------------- |
| `tasks/get`    | Get current task state; requestors poll until terminal or `input_required` |
| `tasks/result` | Blocks until terminal; returns EXACTLY what the underlying request returns |
| `tasks/list`   | (If supported) list tasks with pagination and `nextCursor`                 |
| `tasks/cancel` | (If supported) request cancellation                                        |

**Implementation rules**:

- Use task updates to report progress for long-running work; keep status transitions consistent.
- Cancellation:
  - Reject cancelling tasks already in terminal state with `-32602`.
  - Upon valid cancellation, receiver SHOULD stop work and MUST transition to `cancelled` before responding.
  - Once cancelled, task MUST remain cancelled even if execution later completes/fails.
- **Important**: Do NOT use `notifications/cancelled` to cancel tasks; use `tasks/cancel` instead.
- TTL/polling:
  - Task responses MUST include `createdAt` and `lastUpdatedAt` (ISO 8601).
  - Receiver MAY override requested `ttl`; `tasks/get` MUST return actual `ttl` (or `null` for unlimited).
  - After TTL elapses, receiver MAY delete the task and results (even if still working).
  - Receiver MAY include `pollInterval`; requestor SHOULD respect it.
- Task/message association:
  - All task-related requests/notifications/responses MUST include `_meta.io.modelcontextprotocol/related-task: { taskId }`.
  - Exception: `tasks/get`, `tasks/list`, and `tasks/cancel` should NOT include related-task metadata (taskId is in params/result); receivers MUST ignore related-task metadata if present on those methods.
  - `tasks/result` responses MUST include related-task metadata (because taskId is not in the result structure).
- Status notifications:
  - Receiver MAY send `notifications/tasks/status` when status changes, but requestors MUST NOT rely on it.
  - If sent, `notifications/tasks/status` SHOULD NOT include related-task metadata (taskId is already in params).

**Common defect patterns**:

- Mixing `notifications/cancelled` with task cancellation (wrong protocol).
- Not implementing all four task operations when advertising capability.
- Allowing invalid status transitions (e.g., `completed` → `working`).

---

### 3.8 Security

**Authorization (HTTP only)**:

- If exposed over HTTP, follow the MCP authorization spec (OAuth 2.1); do not invent ad-hoc token schemes.
- Protected resource metadata (RFC 9728):
  - Server MUST implement OAuth 2.0 Protected Resource Metadata.
  - Server MUST provide PRM discovery via either:
    - `WWW-Authenticate` on `401 Unauthorized` including `resource_metadata="..."`, OR
    - a well-known PRM endpoint (`/.well-known/oauth-protected-resource/...`).
  - Server SHOULD include `scope="..."` in `WWW-Authenticate` to guide least-privilege scope selection.
- Token handling:
  - Authorization MUST be included on every HTTP request (even within the same logical session).
  - Tokens MUST NOT be accepted via query string.
  - Server MUST validate tokens per OAuth 2.1 and MUST validate the token audience/resource binding (RFC 8707).
  - Server MUST only accept tokens issued for itself by its authorization server and MUST NOT accept/transit other tokens.
- Runtime insufficient scope:
  - Prefer `403 Forbidden` with `WWW-Authenticate: Bearer error="insufficient_scope", scope="...", resource_metadata="..."`.
- If the codebase includes/ships an authorization server component: require PKCE (S256) and publish `code_challenge_methods_supported` in AS metadata.
- STDIO servers should rely on local OS/process boundaries rather than HTTP auth.

**DNS rebinding protection (MANDATORY for local HTTP servers)**:

- **Both clients and servers MUST verify Host header matches expected values**.
- Use the SDK's `hostHeaderValidation([...allowedHosts])` or `createMcpExpressApp()` helper.
- Block requests with unexpected `Host` or `Origin` headers (return 403).
- This is a critical security requirement per the 2025-11-25 spec.

**Token passthrough (FORBIDDEN)**:

- Servers MUST NOT forward client access tokens to external/upstream APIs.
- Use the server's own credentials for upstream calls.
- This prevents confused deputy attacks and credential leakage.

**Filesystem access requirements**:

- Canonicalize: `path.resolve` + `fs.realpath` (or equivalent) before allowlist checks.
- Validate against the client-provided allowed roots (or an explicit server allowlist).
- Deny traversal and symlink escapes.
- Do not leak full paths or secrets in error messages.

**Roots**:

- If `roots` capability is used, honor the client-provided roots and update when `notifications/roots/list_changed` arrives.

**Network/SSRF requirements**:

- If the tool accepts URLs, restrict schemes (`https:`), restrict hosts (allowlist), and cap redirects.
- Time-limit all network calls.

**Session IDs**:

- Treat session IDs as opaque routing tokens, not authentication.
- Use cryptographically random session IDs and avoid logging them.

**Icons security considerations**:

- `icons` arrays contain URLs that may be user-controlled.
- Validate icon URLs against an allowlist if possible.
- Be aware of potential CSP bypass, tracking, or SSRF via icon URLs.
- Consider proxying icon URLs through the server if displaying to users.

**Reserved keys**:

- `_meta` is reserved for protocol use.
- Keys with `mcp.` prefix are reserved; do not use custom keys with this prefix.

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

**Cancellation**:

- Respect `notifications/cancelled` for in-flight requests.
- **MUST NOT cancel `initialize`**; treat cancellation for unknown IDs as no-op.
- **For tasks**: Use `tasks/cancel` instead of `notifications/cancelled`.
- Clean up resources (abort signals, DB connections) when cancellation is received.

**Progress notifications**:

- Use progress notifications for long-running work; pass `progressToken` in `_meta`.
- **Progress value MUST increase** (or stay the same); it may reset to 0 only when a new phase of work begins.
- Progress supports floating point values.
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

Return a JSON array sorted by severity (`blocker` -> `high` -> `medium` -> `low` -> `nit`).

`severity` MUST be one of: `blocker | high | medium | low | nit`.

```json
[
  {
    "severity": "blocker | high | medium | low | nit",
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

| Test                        | How                                                                          | Expected                                                                                             |
| --------------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| STDIO clean                 | Run via Inspector (`npx @modelcontextprotocol/inspector node dist/index.js`) | No parse errors; no stdout noise                                                                     |
| Unknown fields rejected     | Call a tool with extra keys                                                  | Validation error, no crash                                                                           |
| Schema enforcement          | Call tool with wrong types                                                   | JSON-RPC error or `isError: true` tool result                                                        |
| Protocol version mismatch   | Send unsupported `MCP-Protocol-Version` / `initialize.protocolVersion`       | 400 or JSON-RPC error                                                                                |
| Path traversal              | Try `../` or `file:///...` outside roots                                     | Denied                                                                                               |
| Timeout                     | Block network / slow endpoint                                                | Error within 10-30s                                                                                  |
| Streamable HTTP host/origin | Send invalid `Host`/`Origin`                                                 | Rejected (typically 403)                                                                             |
| Auth PRM discovery          | Call protected endpoint with no `Authorization`                              | 401 with `WWW-Authenticate: Bearer resource_metadata="..."` (optional `scope`)                       |
| Insufficient scope          | Call protected endpoint with token lacking scope                             | 403 with `WWW-Authenticate: Bearer error="insufficient_scope" ...`                                   |
| HTTP 202 behavior           | Send notifications/responses over POST                                       | HTTP 202 Accepted with no body                                                                       |
| DELETE session              | Send DELETE to session endpoint                                              | 200 (session closed) or 405 (not supported)                                                          |
| Invalid session ID          | Send request with invalid `MCP-Session-Id`                                   | HTTP 404 Not Found                                                                                   |
| Session correctness         | Initialize then call tool using returned session header                      | Works across subsequent requests                                                                     |
| ListChanged notifications   | Change tools/resources/prompts list                                          | `notifications/*/list_changed` emitted                                                               |
| Completion                  | Call `completion/complete` for prompt/resource args                          | `result.completion.values` (<= 100), `hasMore` boolean, optional numeric `total`                     |
| Cancellation                | Cancel a long-running request                                                | Work stops; no success result                                                                        |
| Progress monotonicity       | Observe progress notifications                                               | Values increase (except phase resets)                                                                |
| Tasks lifecycle             | Create task, poll `tasks/get`, retrieve via `tasks/result`, cancel           | Valid status transitions; related-task `_meta` on task messages; cancel terminal rejects with -32602 |
| Audio content               | Return audio in tool result (if supported)                                   | Proper base64 + mimeType                                                                             |
| Pagination cursor           | List with cursor continuation                                                | Stable results; cursor is opaque                                                                     |

---

## Appendix: Platform-Friendly Search Commands

### Cross-platform (ripgrep)

```sh
rg "console\\.log|process\\.stdout\\.write" src
rg "createMcpExpressApp\(|hostHeaderValidation\(|StreamableHTTP" src
rg "MCP-Protocol-Version|MCP-Session-Id" src
rg "outputSchema|structuredContent" src
rg "notifications/(tools|resources|prompts)/list_changed|resources/subscribe" src
rg "completion/complete|prompts/get|resources/templates/list" src
rg "tasks/(list|get|cancel|result)|execution\.taskSupport" src
rg "progressToken|notifications/progress" src
rg "AbortSignal\\.timeout\(" src
rg "audience|priority|lastModified|annotations" src
```

### Fallback (grep)

```sh
grep -R "console.log" src --include="*.ts"
grep -R "createMcpExpressApp\\|hostHeaderValidation\\|StreamableHTTP" src --include="*.ts"
grep -R "MCP-Protocol-Version\\|MCP-Session-Id" src --include="*.ts"
grep -R "outputSchema" src --include="*.ts"
grep -R "structuredContent" src --include="*.ts"
grep -R "tasks/list\\|tasks/get\\|tasks/cancel" src --include="*.ts"
grep -R "progressToken" src --include="*.ts"
```

---

## Appendix: Standard JSON-RPC Error Codes

| Code     | Meaning            | Common Cause                                    |
| -------- | ------------------ | ----------------------------------------------- |
| `-32600` | Invalid request    | Malformed JSON-RPC                              |
| `-32601` | Method not found   | Capability not supported                        |
| `-32602` | Invalid params     | Unknown tool, invalid cursor, schema validation |
| `-32603` | Internal error     | Server-side failure                             |
| `-32002` | Resource not found | Unknown resource URI                            |

---

## Appendix: Logging Levels (RFC 5424)

| Level       | Description             | Example                  |
| ----------- | ----------------------- | ------------------------ |
| `debug`     | Detailed debugging      | Function entry/exit      |
| `info`      | General informational   | Operation progress       |
| `notice`    | Normal but significant  | Configuration changes    |
| `warning`   | Warning conditions      | Deprecated feature usage |
| `error`     | Error conditions        | Operation failures       |
| `critical`  | Critical conditions     | Component failures       |
| `alert`     | Immediate action needed | Data corruption          |
| `emergency` | System unusable         | Complete failure         |
