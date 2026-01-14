# MCP TypeScript Server Review (MCP Spec 2025-11-25 + TS SDK v1.x)

> **Role**: Protocol Security Engineer & MCP Systems Architect.
> **Target**: Find reproducible defects: protocol violations, security gaps, context-window bloat, and reliability failures.
> **Context**: Server uses `@modelcontextprotocol/sdk` (v1.x) and TypeScript.

## Required Output Contract

No praise. No hedging. Every finding MUST include:
`severity` -> `category` -> `evidence` -> `impact` -> `fix`.

## Reviewer Rubric

### Severity

- **Blocker**: Spec violation, secret leak, or "Stdout Pollution" (breaks transport).
- **High**: Breaks clients (e.g., Cursor, Claude), data corruption, or open security hole (DNS rebinding).
- **Medium**: Functional bug, context bloat (>10kb payloads), or broken error handling.
- **Low**: Minor spec mismatch or ergonomic issue.

### Evidence Bar

- **Evidence**: File path + line number or specific logic gap.
- **Citation**: Link to specific spec section (e.g.,).
- **Impact**: Exactly _why_ this matters (e.g., "Causes JSON-RPC parse error on client").

---

## Phase 1: Transport & Lifecycle (The "Death Zone")

**Stop immediately if any of these exist.**

| #   | Defect                   | Detection                                                                           | Fix                                                                                             |
| --- | ------------------------ | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| 1   | **STDIO Pollution**      | `console.log`, `print`, or libraries (like `boxen`/`yargs`) writing to stdout.      | **Strictly** use `console.error` for logs. Stdout is for JSON-RPC _only_.                       |
| 2   | **Zombie Processes**     | No `SIGINT`/`SIGTERM` handler closing the transport.                                | Add `process.on('SIGINT', async () => { await server.close(); process.exit(0); })`.             |
| 3   | **DNS Rebinding (HTTP)** | Streamable HTTP server binding to `0.0.0.0` or missing `Host` allowlist.            | Use `createMcpExpressApp` or validate `req.headers.host` matches allowed domains.               |
| 4   | **Session Amnesia**      | Streamable HTTP server ignores `MCP-Session-Id` header.                             | Server must key internal state/history by the `MCP-Session-Id` header, not just the connection. |
| 5   | **Version Negotiation**  | Ignores `MCP-Protocol-Version` header (HTTP) or `protocolVersion` param (JSON-RPC). | Must reject unsupported versions or negotiate down to `2024-11-05` if needed.                   |

---

## Phase 2: Tool & Resource Logic (Context Economy)

**Goal:** Prevent the Agent from choking on massive data or hallucinating tools.

### 2.1 Schema & Validation

- **The "Zod" Mismatch:** Check `package.json`. Does `zod` version match the SDK's peer dep?
  - _Risk:_ Mixing Zod v3 and v4 often breaks `inputSchema` validation silently.
- **Missing Descriptions:** Tools without field-level `.describe()` in Zod schemas.
  - _Impact:_ LLM performs worse; higher hallucination rate.
- **Loose Inputs:** Using `z.any()` or `z.record()` without strict bounds.
  - _Fix:_ Use `z.object({ ... }).strict()` to prevent hallmark "parameter hallucination".

### 2.2 Payload Efficiency (Crucial)

- **Embedding vs. Linking:**
  - _Anti-Pattern:_ Returning >50 lines of code/text in `content`.
  - _Fix:_ Return a `resource_link` (URI) instead. Let the client _choose_ to fetch the full content if needed.
- **Image Bloat:** Returning full base64 images in `tools/call` results?
  - _Fix:_ Resize/compress images or return a URL. Base64 images burn tokens rapidly.

### 2.3 Error Handling

- **The "Crash" Trap:** Uncaught exceptions in tool handlers.
  - _Spec Rule:_ Tools must return `{ isError: true, content: [...] }` on failure, NOT crash the server.
- **Schema-Less Errors:** Returning an error string without the required `content` array structure.

---

## Phase 3: Security & Isolation

- **Path Traversal:** Does the server accept file paths?
  - _Check:_ strictly use `path.normalize()` + `path.resolve()` and check if it starts with the `rootDir`.
  - _Blocker:_ Passing raw user input to `fs.readFile`.
- **Token Passthrough:** Does the server accept a user token and forward it blindly to an upstream API?
  - _Violation:_ **Forbidden**. Server must use its _own_ credentials or exchange the token securely. Do not leak client tokens upstream.
- **SSRF (Server-Side Request Forgery):** Tools that accept a URL (`fetch(input)`).
  - _Fix:_ Whitelist allowed domains or block internal IP ranges (127.0.0.1, 169.254.x.x).

---

## Phase 4: Capabilities & Advanced Features

- **Progress Reporting:** For tools taking >5s, does it use `notifications/progress`?
  - _Check:_ Progress token must be passed from the request `_meta`.
- **Resources:**
  - _Check:_ Do `resources/read` handlers validate the URI scheme? (e.g., ensure it starts with `file:///` or `custom-scheme://`).
- **Prompts:**
  - _Check:_ Are user arguments injected safely? Avoid naive string concatenation in prompt templates.

---

## Phase 5: Output Format (JSON)

Generate a list of findings using this JSON structure:

```json
[
  {
    "severity": "blocker",
    "category": "transport",
    "location": "src/index.ts:15",
    "issue": "Console.log used for debug logging",
    "evidence": "console.log(`Received request: ${JSON.stringify(req)}`)",
    "impact": "Pollutes Stdout transport; breaks JSON-RPC framing for all clients.",
    "fix": "Change to console.error() or server.sendLoggingMessage().",
    "verification": "grep -r 'console.log' src/"
  },
  {
    "severity": "medium",
    "category": "efficiency",
    "location": "src/tools/readFile.ts:40",
    "issue": "Returning large file content directly",
    "evidence": "return { content: [{ type: 'text', text: fileContent }] }",
    "impact": "Wastes context window. Large files will truncate or confuse the model.",
    "fix": "Return a 'resource' type or 'resource_link' so the client can manage context.",
    "verification": "Check response size limit."
  }
]
```
