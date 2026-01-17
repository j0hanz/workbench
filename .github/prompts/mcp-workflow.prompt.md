# MCP Server Protocol Audit & Code Review

> **SDK Context (Jan 2026):** This audit targets **TypeScript SDK v1.x** (`@modelcontextprotocol/sdk`) as the production-ready standard. SDK v2 is pre-alpha (stable Q1 2026) and splits into `@modelcontextprotocol/server` and `@modelcontextprotocol/client`. Use v1.x for production servers. For Python SDK or raw JSON-RPC implementations, adapt checks accordingly.

You are an expert Model Context Protocol (MCP) Systems Engineer. Your task is to audit the provided MCP server codebase for protocol compliance, transport stability, and robust integration patterns.

## 1. Context Analysis (SDK vs. Raw)

- **Detection:** Determine if the server uses an official SDK (TypeScript/Python) or a raw JSON-RPC implementation.
  - _If SDK:_ Audit the configuration of the `Server` instance and `capabilities` declaration.
  - _If Raw:_ Strictly validate JSON-RPC 2.0 compliance (id, method, params) and handshake logic.

### 1.1 TypeScript SDK Essentials (If Applicable)

- **Shebang (CLI Servers):** Verify `#!/usr/bin/env node` is the **first line** in entrypoint files (e.g., `src/index.ts`).
  - _Critical:_ Missing shebang causes runtime failures when executed via `node dist/index.js` or `package.json` bin.
- **Import Extensions:** All local imports MUST use `.js` extensions for NodeNext module resolution.
  - _Example:_ `import { helper } from './lib.js'` (not `./lib` or `./lib.ts`).
- **Named Exports Only:** No default exports; use `export { MyClass }` pattern.
- **Type-Only Imports:** Use `import type { X }` or inline `import { type X }` to avoid runtime overhead.
- **Strict TypeScript:** Enable `strict`, `noUncheckedIndexedAccess`, `verbatimModuleSyntax`, `isolatedModules` in `tsconfig.json`.

## 2. Transport & Hygiene (CRITICAL)

- **Stdout Pollution (The "Death Rule" - Stdio Servers):** Flag _any_ instance of `print`, `console.log`, or `fmt.Println` to stdout in **stdio servers**.
  - _Why Critical:_ Stdio transport uses stdout for JSON-RPC messages; any non-protocol output crashes the client.
  - _Correction (Stdio):_ Replace with `console.error()` (stderr) OR `server.sendLoggingMessage()` (protocol logging).
  - _HTTP Servers:_ Still flag `console.log()` but less critical; recommend `server.sendLoggingMessage()` for observability.
- **Connection Lifecycle:** Check how the transport is attached (`StdioServerTransport` vs `StreamableHTTPServerTransport`). Ensure clean shutdown handling on `SIGINT`/`SIGTERM`.
  - _Pattern:_ `process.on('SIGTERM', () => process.exit(0))`

## 2.1 Lifecycle & Capability Negotiation (CRITICAL)

- **Initialization Ordering:** Ensure `initialize` is the first request and `notifications/initialized` is sent before normal operations.
  - Client **SHOULD NOT** send requests other than `ping` before `initialize` response.
  - Server **SHOULD NOT** send requests other than `ping`/logging before `notifications/initialized`.
- **Version Negotiation:** Validate protocol version compatibility and disconnection on mismatch.
- **Capabilities:** Verify declared capabilities match implemented features, including `listChanged` and `subscribe` sub-capabilities.
- **Operational Guardrails:** Ensure both sides only use negotiated capabilities during the session.

### 2.2 HTTP Transport Specifics (Streamable HTTP)

- **Stateless vs. Stateful Sessions:**
  - _Stateless (Recommended):_ New `StreamableHTTPServerTransport` per request; no session reuse. Simpler and more reliable.
  - _Stateful:_ Requires session management via `sessionIdGenerator`, persisting transports by `MCP-Session-Id`, and routing GET/POST/DELETE.
- **DNS Rebinding Protection:** Use `createMcpExpressApp({ host: 'localhost' })` or `hostHeaderValidation` middleware (see CVE-2025-66414).
- **Session Header Handling:** Read `req.headers['mcp-session-id']` (Express lowercases it; spec name is `MCP-Session-Id`).
- **Origin Validation (Spec 2025-11-25):** If `Origin` header present and invalid, respond with HTTP 403. Required for remote servers.
- **Endpoint Requirements:** `POST` for requests, `GET` for SSE resumption (with `Last-Event-ID`), `DELETE` for session cleanup.

## 3. Tool Definition & Schema

- **Input Schemas:** Verify that all Tools define explicit, non-ambiguous JSON Schemas (Draft 07).
  - _Check:_ Are strictly typed libraries used (e.g., `zod` in TS, `pydantic` in Python)?
  - _Check:_ Are descriptions descriptive enough for an LLM to understand _when_ to use the tool?
- **Zod v4 Requirements (TypeScript SDK):**
  - Use `z.strictObject()` (not `z.object()`) to reject unknown fields (security).
  - Add `.describe()` to all parameters for LLM guidance.
  - Set limits: `.min()`, `.max()` on strings/arrays/numbers to prevent abuse.
  - Validate enums with `z.enum(['val1', 'val2'])` for constrained inputs.
- **Structured Content Pattern (Backward Compatibility):**
  - Tools MUST return both `content` (JSON string in text block) AND `structuredContent` (typed object).
  - _Why:_ Old clients only read `content`; new clients prefer `structuredContent`. Return both for compatibility.
  - _Example:_ `{ content: [{type: 'text', text: JSON.stringify(data)}], structuredContent: data }`
- **Error Propagation:** Ensure tools return `isError: true` in the `CallToolResult` rather than throwing uncaught exceptions.

### 3.2 Annotations Semantics (Hints Only)

- **Not Security Boundaries:** Annotations (`readOnlyHint`, `idempotentHint`, `destructiveHint`, `openWorldHint`) are **hints for LLMs**, not enforcement mechanisms.
  - _readOnlyHint:_ Tool doesn't modify state (e.g., read file, list resources).
  - _idempotentHint:_ Safe to retry; repeated calls with same args have same effect (read-only tools are often idempotent).
  - _destructiveHint:_ Irreversible changes (e.g., delete file, drop database).
  - _openWorldHint:_ Calls external APIs (network boundary crossing).
- **Authorization Separation:** Enforce permissions separately; don't assume annotations provide access control.

## 3.1 Completions Utility (If Supported)

- **Capability Declaration:** If `completion/complete` is implemented, server **MUST** declare `capabilities.completions`.
- **Input Validation:** Validate `ref` type (`ref/prompt` or `ref/resource`) and `context.arguments` for multi-arg prompts/templates.
- **Result Limits:** Enforce max 100 completion values, and include `total`/`hasMore` when applicable.
- **Error Codes:** Use JSON-RPC errors: `-32601` unsupported, `-32602` invalid params, `-32603` internal.
- **Security:** Rate limit completion requests and prevent sensitive data leakage via suggestions.

## 4. Resource & URI Patterns

- **URI Consistency:** Inspect `ListResources` and `ReadResource`.
  - _Rule:_ Do resource URIs follow a consistent scheme (e.g., `custom-scheme://internal/id`)?
  - _Rule:_ Does the `ReadResource` handler validate that the requested URI matches the expected pattern?
- **Subscription Support:** If the data changes, does the server implement `notifications/resources/updated`?

## 5. Security & Isolation

- **Path Traversal:** If the server accesses the filesystem, verify it checks against a permitted `root` directory.
  - **Symlink Resolution (Critical):** Check for `fs.realpath()` usage to resolve symlinks BEFORE validation.
  - _Why:_ Attackers can bypass allow-list checks using symlinks to external directories.
  - _Pattern:_ `const realPath = await fs.realpath(userPath); validateAgainstAllowList(realPath);`
- **Input Sanitization:** Ensure tool arguments are validated _before_ being passed to shell commands or database queries (Injection risks).

### 5.1 DNS Rebinding (CVE-2025-66414 - HTTP Servers Only)

- **Automatic Protection:** Check if server uses `createMcpExpressApp({ host: 'localhost' })` helper (includes DNS rebinding protection).
- **Manual Validation:** If not using helper, verify `hostHeaderValidation` middleware is applied.
  - _Example:_ `app.use(hostHeaderValidation(['localhost', '127.0.0.1']))`
- **Origin Header Validation:** Per spec 2025-11-25, servers MUST validate `Origin` header if present; respond HTTP 403 if invalid.
- **Localhost Binding:** For local servers, verify socket binds to `localhost` (not `0.0.0.0`).

## 6. Advanced Patterns (Bonus)

- **Progress Reporting:** For long-running tools, does the server use validation tokens and `notifications/progress`?
- **Prompts:** If the server exposes Prompts (`GetPrompt`), are arguments correctly mapped and validated?

## 6.1 Timeouts & Cancellation

- **Request Timeouts:** Ensure per-request timeouts exist and are configurable.
- **Cancellation:** On timeout, sender **SHOULD** send a cancellation notification and stop waiting.
- **Progress Interaction:** Implementations **MAY** reset timeout on progress, but **SHOULD** enforce a maximum timeout.

## 6.2 JSON-RPC Hygiene

- **Request/Response Shape:** Validate JSON-RPC 2.0 correctness: requests include `id`, notifications omit `id`, responses match result/error schemas.

### 6.3 Dynamic Tools (Advanced Pattern)

- **Runtime Tool Mutations:** If server modifies tools at runtime, verify correct usage of:
  - `tool.enable()` / `tool.disable()` - Show/hide tools dynamically.
  - `tool.update({ inputSchema: newSchema })` - Modify tool schemas.
  - `tool.remove()` - Permanently remove tool.
- **Notification Requirement:** All mutations MUST trigger `notifications/tools/list_changed` to inform client.
- **Use Case:** Permission upgrades, feature flags, conditional tool availability.

## Output Format

1.  **Transport Integrity:** (Pass/Fail) - specific status on Stdout usage (differentiate stdio vs HTTP).
2.  **Critical Issues:** Security risks or protocol violations that will crash the client.
3.  **Optimization Tips:** Suggestions to use native Protocol Logging or Progress notifications.
4.  **Refactoring Plan:** Code snippets to fix identified issues using TypeScript SDK v1.x best practices.

### Example Refactoring Patterns (TypeScript SDK)

**Correct Tool Registration:**

```typescript
server.registerTool(
  'read-file',
  {
    title: 'Read File',
    description:
      'Read text file contents. Only works within allowed directories.',
    inputSchema: z.strictObject({
      path: z.string().min(1).max(4096).describe('File path to read'),
    }),
    outputSchema: z.strictObject({
      ok: z.boolean(),
      result: z.object({ content: z.string() }).optional(),
      error: z.object({ code: z.string(), message: z.string() }).optional(),
    }),
    annotations: { readOnlyHint: true },
  },
  async ({ path }) => {
    try {
      const validPath = await validatePath(path); // fs.realpath + allow-list check
      const content = await fs.readFile(validPath, 'utf-8');
      const structured = { ok: true, result: { content } };
      return {
        content: [{ type: 'text', text: JSON.stringify(structured) }],
        structuredContent: structured,
      };
    } catch (err) {
      const structured = {
        ok: false,
        error: { code: 'E_READ_FAILED', message: String(err) },
      };
      return {
        content: [{ type: 'text', text: JSON.stringify(structured) }],
        structuredContent: structured,
        isError: true,
      };
    }
  }
);
```

**Stdio Transport (Local/CLI):**

```typescript
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

const server = new McpServer(
  { name: 'my-server', version: '1.0.0' },
  { instructions: 'Usage for LLM', capabilities: { logging: {}, tools: {} } }
);

await server.connect(new StdioServerTransport());
console.error('Server started'); // Use stderr, never stdout
```

**HTTP Transport (Stateless):**

```typescript
import { createMcpExpressApp } from '@modelcontextprotocol/sdk/server/express.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';

const app = createMcpExpressApp({ host: 'localhost' }); // DNS rebinding protection

app.post('/mcp', async (req, res) => {
  const transport = new StreamableHTTPServerTransport({
    enableJsonResponse: true,
  });
  res.on('close', () => transport.close());
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
});

app.listen(3000);
```
