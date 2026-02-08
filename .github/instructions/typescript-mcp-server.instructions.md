---
description: "Rules for building MCP servers with TypeScript SDK"
---

## Related Files

- [typescript-mcp-expert.agent.md](../agents/typescript-mcp-expert.agent.md) - Agent workflows and debugging
- [typescript-mcp-server-generator.prompt.md](../prompts/typescript-mcp-server-generator.prompt.md) - Project scaffolding generator

# TypeScript MCP Server Rules (SDK v1.x)

Target stack:

- `@modelcontextprotocol/sdk` **v1.x (production)**
- Zod **v4.x**
- Node **>=20**
- TypeScript **5.9+** (strict)

## Repository Convention (Default)

Use this structure unless the repo already has established patterns:

```text
src/
├── index.ts              # Entrypoint: shebang, transport wiring, shutdown
├── tools/
│   ├── index.ts          # registerAllTools(server)
│   └── {name}.ts         # One tool per file
├── schemas/
│   ├── inputs.ts         # Zod input schemas (z.strictObject)
│   └── outputs.ts        # Zod output schemas
└── lib/
    ├── errors.ts         # getErrorMessage + error helpers
    ├── tool_response.ts  # createToolResponse/createErrorResponse helpers
    └── types.ts          # Shared types (optional)
```

## Mandatory Rules

### Versions & Imports

- Use `@modelcontextprotocol/sdk` **v1.x** for production servers.
- Standardize on **Zod v4** (`import { z } from 'zod'`); do not use `zod/v3` unless intentionally pinned.
- Use **named exports only** (no default exports).
- Use **type-only imports**: `import type { X }` / `import { type X }`.
- Use `.js` extensions in **local imports** when using NodeNext/ESM output.
- Exported functions should have **explicit return types**.

### TypeScript Strictness

Enable (or justify deviations):

- `strict`
- `noUncheckedIndexedAccess`
- `verbatimModuleSyntax`
- `isolatedModules`

### CLI Entrypoint (Shebang)

If executed via `node dist/index.js` or exposed via `bin` in `package.json`:

- `src/index.ts` MUST start with this exact first line (no BOM/blank lines):
  - `#!/usr/bin/env node`

### Tool Naming

- Tool names SHOULD be 1–128 chars and match: `[A-Za-z0-9_.-]+` (no spaces)

## Tool Implementation Standard

### Input/Output Schemas

- Use `z.strictObject()` for all object schemas (reject unknown fields).
- Add `.describe()` to every parameter for LLM guidance.
- Add bounds: `.min()`/`.max()` for strings/arrays/numbers; use `z.enum([...])` for constrained values.
- For no-arg tools, use `z.strictObject({})` to accept only empty objects.
- JSON Schema dialect defaults to **2020-12** when `$schema` is omitted.

### Output Shape (Recommended Baseline)

```ts
outputSchema: z.strictObject({
  ok: z.boolean(),
  result: z.unknown().optional(),
  error: z.strictObject({ code: z.string(), message: z.string() }).optional(),
});
```

### Structured Content (Backward Compatibility)

When returning `structuredContent`, ALSO include a JSON string in `content`:

- `content: [{ type: 'text', text: JSON.stringify(structured) }]`

### Errors

- Prefer tool execution errors over protocol errors for invalid tool inputs.
- On failure return `isError: true` in the tool result; do not throw uncaught exceptions.

### Canonical Tool Pattern

```ts
server.registerTool(
  "tool_name",
  {
    title: "Human Title",
    description:
      "Clear, actionable LLM description (when to use it, what it returns)",
    inputSchema: z.strictObject({
      param: z.string().min(1).max(200).describe("Parameter description"),
    }),
    outputSchema: z.strictObject({
      ok: z.boolean(),
      result: z.unknown().optional(),
      error: z
        .strictObject({ code: z.string(), message: z.string() })
        .optional(),
    }),
    annotations: { readOnlyHint: true, idempotentHint: true },
  },
  async (params) => {
    try {
      const result = await doWork(params);
      const structured = { ok: true, result };
      return {
        content: [{ type: "text", text: JSON.stringify(structured) }],
        structuredContent: structured,
      };
    } catch (err) {
      const structured = {
        ok: false,
        error: { code: "E_FAILED", message: getErrorMessage(err) },
      };
      return {
        content: [{ type: "text", text: JSON.stringify(structured) }],
        structuredContent: structured,
        isError: true,
      };
    }
  },
);
```

## Annotations (Hints Only)

Annotations guide LLM behavior; they are not authorization.

- `readOnlyHint`: does not modify state
- `idempotentHint`: safe to retry with same args (avoid if intentionally nondeterministic)
- `destructiveHint`: irreversible change
- `openWorldHint`: external network/API calls

## Transport Rules

### Defaults

- **Streamable HTTP**: recommended for remote servers.
- **stdio**: ideal for local/CLI servers.
- HTTP+SSE legacy transport: only for backward compatibility.

### stdio Hygiene

- Never write non-MCP output to **stdout** (it corrupts JSON-RPC).
- Use `console.error()` or protocol logging.
- JSON-RPC messages are newline-delimited and **MUST NOT** contain embedded newlines.

### Streamable HTTP Security (CVE-2025-66414)

- Prefer `createMcpExpressApp({ host: 'localhost' })` for DNS rebinding protection.
- Or use `hostHeaderValidation([...])`.
- Validate `Origin` **if present**; if invalid → **HTTP 403**.
- For stateful sessions, read header as `req.headers['mcp-session-id']` (Express lowercases).

## Streamable HTTP (Spec 2025-11-25 Essentials)

- MCP endpoint MUST support both `POST` and `GET`.
  - `GET` MUST serve `text/event-stream` or return **405** (not 404).

- JSON-RPC POST clients MUST send `Accept: application/json, text/event-stream`.
- Expired session: server returns **404** for invalid/expired `MCP-Session-Id`; client must re-initialize without session id.
- Clients MUST send `MCP-Protocol-Version: <negotiated>` on subsequent requests; invalid/unsupported → **400**.
- SSE resume uses **GET + Last-Event-ID**.
- Do not broadcast the same JSON-RPC message across multiple SSE streams.

## Authorization (HTTP; Optional but Common)

- stdio servers generally avoid HTTP auth flows; use environment-provided credentials.
- If implementing auth, support Protected Resource Metadata (RFC 9728) discovery via:
  - `WWW-Authenticate: Bearer resource_metadata="..."` (recommended on 401), or
  - `/.well-known/oauth-protected-resource[...]` fallback.

- Do not accept tokens not issued for this MCP server (no token passthrough).

## Tasks (Experimental)

- If supported: declare `capabilities.tasks`.
- Honor `execution.taskSupport` (`required|optional|forbidden`) for tools.
- Task cancellation uses `tasks/cancel` (not `notifications/cancelled`).

### Tasks Appendix

- Only augment requests with tasks when the peer declares the matching `capabilities.tasks` entry.
- `tasks/result` blocks until terminal status (`completed|failed|cancelled`).
- Use `notifications/cancelled` for non-task requests only.

## Logging (Optional)

- Declare `capabilities.logging` if sending log notifications.
- Use `notifications/message` for structured log delivery; avoid secrets/PII in logs.

## Capabilities & UX

- Prompts: declare capability and validate prompt args.
- Sampling: only if client capability exists; keep a human in the loop; honor `sampling.tools`.
- Elicitation: only if client capability exists; use URL-mode elicitation for sensitive info.

## Helpers (Recommended)

- Provide shared helpers in `src/lib/`:
  - `getErrorMessage(error: unknown): string`
  - `createToolResponse(structured)` (always sets both `content` and `structuredContent`)
  - `createErrorResponse(code, message)` (sets `isError: true`)

## Testing & Verification

- Inspector:
  - `npx @modelcontextprotocol/inspector node dist/index.js` (stdio)
  - `npx @modelcontextprotocol/inspector http://localhost:3000/mcp` (HTTP)

- Prefer `node:test` for unit tests; keep tests deterministic.

## Shutdown (Required)

Wire clean exit:

```ts
process.on("SIGTERM", () => process.exit(0));
process.on("SIGINT", () => process.exit(0));
```
