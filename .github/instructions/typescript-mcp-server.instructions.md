---
description: 'Rules for building MCP servers with TypeScript SDK'
applyTo: '**/*.ts, **/*.js, **/package.json'
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
├── server.ts             # McpServer instance, capability declaration
├── tools/
│   ├── index.ts          # registerAllTools(server)
│   └── {name}.ts         # One tool per file
├── resources/
│   └── index.ts          # Resource registration (static + templates)
├── prompts/
│   └── index.ts          # Prompt registration
├── schemas/
│   ├── inputs.ts         # Zod input schemas (z.strictObject)
│   └── outputs.ts        # Zod output schemas
└── lib/
    ├── errors.ts         # getErrorMessage + error helpers
    ├── tool-response.ts  # createToolResponse/createErrorResponse helpers
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
- Tool names SHOULD be unique within a server.

## Tool Implementation Standard

### Metadata

Every tool MUST have:

- `name`: Unique identifier matching `[A-Za-z0-9_.-]+`
- `description`: Clear, actionable LLM description (when to use it, what it returns)

Every tool SHOULD have:

- `title`: Human-readable display name for UI surfaces
- `annotations`: Behavioral hints for clients (see [Annotations](#annotations-hints-only))
- `icons`: Array of icon objects for UI display (see [Icons](#icons))

### Input/Output Schemas

- Use `z.strictObject()` for all object schemas (reject unknown fields).
- Add `.describe()` to every parameter for LLM guidance.
- Add bounds: `.min()`/`.max()` for strings/arrays/numbers; use `z.enum([...])` for constrained values.
- Tools with no parameters use `z.strictObject({})`.

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

### Content Types in Tool Results

Tools may return multiple content types in the `content` array:

- **Text**: `{ type: 'text', text: '...' }`
- **Image**: `{ type: 'image', data: 'base64...', mimeType: 'image/png' }`
- **Audio**: `{ type: 'audio', data: 'base64...', mimeType: 'audio/wav' }`
- **Resource link**: `{ type: 'resource_link', uri: '...', name: '...', mimeType: '...' }`
- **Embedded resource**: `{ type: 'resource', resource: { uri: '...', mimeType: '...', text: '...' } }`

### Errors

- Prefer tool execution errors over protocol errors for invalid tool inputs.
- On failure return `isError: true` in the tool result; do not throw uncaught exceptions.

### Canonical Tool Pattern

```ts
server.registerTool(
  'tool_name',
  {
    title: 'Human Title',
    description:
      'Clear, actionable LLM description (when to use it, what it returns)',
    inputSchema: z.strictObject({
      param: z.string().min(1).max(200).describe('Parameter description'),
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
  }
);
```

## Annotations (Hints Only)

Annotations guide LLM behavior; they are not authorization.

- `readOnlyHint`: does not modify state
- `idempotentHint`: safe to retry with same args (avoid if intentionally nondeterministic)
- `destructiveHint`: irreversible change
- `openWorldHint`: external network/API calls

## Icons

Tools, resources, resource templates, and prompts support optional `icons` arrays for UI display:

```ts
icons: [
  { src: "https://example.com/icon.svg", mimeType: "image/svg+xml" },
  { src: "data:image/png;base64,...", mimeType: "image/png" },
],
```

- Icons have `src` (URL or data URI), `mimeType`, and optional `sizes` array.
- Omit `sizes` for maximum client compatibility.
- Use `data:` URIs for bundled icons; HTTPS URLs for remote icons.

## Resources

### Registration

- Static resources: `server.registerResource(name, uri, metadata, readCallback)`.
- Dynamic resources: `ResourceTemplate` with URI pattern + `readCallback`.
- Provide `listCallback` for dynamic templates to make them discoverable.

### Metadata

Resources and resource templates support:

- `name`: Identifier for the resource.
- `title`: Optional human-readable display name.
- `description`: Optional description.
- `mimeType`: Optional MIME type.
- `icons`: Optional array of icon objects.

### Annotations

Resource annotations provide hints for clients:

- `audience`: `["user"]`, `["assistant"]`, or `["user", "assistant"]`
- `priority`: `0.0` (least important) to `1.0` (most important / required)
- `lastModified`: ISO 8601 timestamp

### Content

Resources return `contents[]` with:

- Text: `{ uri, mimeType, text }`
- Binary: `{ uri, mimeType, blob }` (base64-encoded)

### Subscriptions

- Declare `subscribe` in `resources` capability to allow clients to subscribe to individual resource changes.
- Send `notifications/resources/updated` when a subscribed resource changes.

## Prompts

- Declare `prompts` capability; validate arguments with Zod.
- Every prompt SHOULD have `name`, `title`, `description`.
- Support optional `icons` and `arguments` for customization.
- Use completable arguments only where completion is supported and safe.
- Return `messages[]` with `role` ("user" or "assistant") and content (text, image, audio, or embedded resource).

## Transport Rules

### Defaults

- **Streamable HTTP**: recommended for remote servers.
- **stdio**: ideal for local/CLI servers.
- HTTP+SSE legacy transport: only for backward compatibility.

### stdio Hygiene

- Never write non-MCP output to **stdout** (it corrupts JSON-RPC).
- Use `console.error()` or protocol logging.

### Streamable HTTP Security

- Validate `Origin` **if present**; if invalid → **HTTP 403**.
- Prefer `createMcpExpressApp({ host: 'localhost' })` for DNS rebinding protection.
- Or use `hostHeaderValidation([...])`.
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

## Logging

- Declare `logging` capability to emit structured log notifications.
- Log levels follow RFC 5424 syslog severity: `debug`, `info`, `notice`, `warning`, `error`, `critical`, `alert`, `emergency`.
- Respect client `logging/setLevel` requests; filter messages below the set level.
- Include relevant context in log `data` field; use consistent `logger` names.
- Gate logging: only send `notifications/message` if client declared `logging` capability.
- Never log secrets, PII, or credentials.

## Progress Notifications

- Clients include `_meta.progressToken` in requests to receive progress updates.
- Send `notifications/progress` with matching token, monotonically increasing `progress`, optional `total`, and optional `message`.
- Stop sending progress notifications after the operation completes.
- For task-augmented requests, the progress token remains valid throughout the task's lifetime until the task reaches a terminal status.

## Tasks

- If supported: declare `capabilities.tasks` with supported request types (e.g., `tasks.requests.tools.call`).
- Tools declare task support via `execution.taskSupport`:
  - `"required"`: clients MUST invoke as task
  - `"optional"`: clients MAY invoke as task or normally
  - `"forbidden"` (default): clients MUST NOT invoke as task
- Task lifecycle: `working` → `input_required` | `completed` | `failed` | `cancelled`.
- Task cancellation uses `tasks/cancel` (not `notifications/cancelled`).
- All related messages MUST include `io.modelcontextprotocol/related-task` in `_meta`.

## Capabilities & UX

### Sampling

- Only if client `sampling` capability exists; keep a human in the loop.
- Use `modelPreferences` with hints and priority values (cost/speed/intelligence).
- Honor `sampling.tools` capability for tool-enabled sampling requests.
- Tool use in sampling follows a multi-turn loop pattern.

### Elicitation

- Only if client `elicitation` capability exists.
- **Form mode** (default): collect structured data via JSON Schema (flat objects, primitive types only).
- **URL mode**: direct users to external URLs for sensitive interactions (OAuth flows, API keys, payments).
- MUST NOT request sensitive credentials via form mode; use URL mode instead.
- Handle all response actions: `accept`, `decline`, `cancel`.

### Completion

- Implement argument auto-completion for prompts and resource templates via the completion API.
- Only provide completions where safe and useful.

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
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
```
