---
description: "Generate production-ready MCP servers in TypeScript"
---

> **Related Files:**  
> [typescript-mcp-server.instructions.md](../instructions/typescript-mcp-server.instructions.md) for mandatory rules | [typescript-mcp-expert.agent.md](../agents/typescript-mcp-expert.agent.md) for debugging workflows

# Generate TypeScript MCP Server (SDK v1.x) — Prompt

You are an MCP TypeScript engineer. Generate a complete, production-ready MCP server using:

- `@modelcontextprotocol/sdk` **v1.x**
- TypeScript **5.9+** (strict)
- Node **>=20**
- Zod **v4.x**

## Step 1 — Confirm Transport (Ask If Missing)

- Use SDK **v1.x** (production).
- Ask the user to choose **one** transport if not explicitly specified:
  - **stdio** (local/CLI)
  - **Streamable HTTP** (remote/multi-client; recommended)
  - **HTTP+SSE** (legacy compatibility only)

### Streamable HTTP Requirements (If Chosen)

- DNS rebinding protection: use `createMcpExpressApp()` (preferred) or `hostHeaderValidation`.
- Validate `Origin` **if present**; invalid → **HTTP 403** (spec 2025-11-25).
- MCP endpoint supports **POST** and **GET** (GET returns SSE or **405**, not 404).
- Clients POSTing JSON-RPC send `Accept: application/json, text/event-stream`.
- Clients send `MCP-Protocol-Version: <negotiated>` on subsequent HTTP requests; invalid/unsupported → **400**.
- Bind localhost for local use; require auth for remote/public use.
- Stateful sessions (only if explicitly needed): use `MCP-Session-Id` (read as `req.headers['mcp-session-id']` in Node).

## Step 2 — Identify Server Type (Ask If Needed)

Determine server type and pick initial tools accordingly (no tool invention beyond the chosen type):

- **Data Access** (filesystem/db) → `readOnlyHint: true`
- **API Integration** (GitHub/Slack) → `openWorldHint: true` + rate limiting + timeouts
- **DevOps** (Docker/K8s) → `destructiveHint: true` + elicitation/confirmation
- **AI/ML** (embeddings/sampling) → sampling gated by client capabilities

## Step 3 — Identify Capabilities

Determine which MCP capabilities the server needs:

- **Tools** (always): core tool handlers.
- **Resources** (if applicable): static or dynamic data the client can read.
- **Prompts** (if applicable): parameterized prompt templates.
- **Logging** (recommended): structured log notifications (RFC 5424 levels).
- **Tasks** (if long-running): task-augmented tool execution with progress.

## Step 4 — Generate Project Structure (Default)

Use this structure unless the user requests otherwise:

```text
src/
├── index.ts               # Entrypoint: shebang, transport, shutdown
├── server.ts              # McpServer instance, capability declaration
├── tools/
│   ├── index.ts           # registerAllTools(server)
│   └── {name}.ts          # One tool per file
├── resources/
│   └── index.ts           # Resource registration (static + templates)
├── prompts/
│   └── index.ts           # Prompt registration
├── schemas/
│   ├── inputs.ts          # Zod input schemas (z.strictObject)
│   └── outputs.ts         # Zod output schemas (DefaultOutputSchema)
└── lib/
    ├── errors.ts          # getErrorMessage + createErrorResponse
    ├── tool-response.ts   # createToolResponse helper
    └── types.ts           # Shared types (optional)
```

## Step 5 — Generate Configuration Files

Output complete, copy-paste-ready:

- `package.json` (ESM, build/test/dev scripts, inspector, Node>=20)
- `tsconfig.json` (NodeNext, strict, `noUncheckedIndexedAccess`, `verbatimModuleSyntax`, `isolatedModules`)
- `eslint.config.mjs` (TS strict rules, unused imports, explicit return types)

## Step 6 — Generate Server Entry (`src/index.ts`) + Server Instance (`src/server.ts`)

### `src/index.ts`

- Include shebang if CLI/bin execution is expected: `#!/usr/bin/env node` as the first line.
- Wire the chosen transport (stdio or Streamable HTTP).
- No stdout pollution for stdio servers (`console.error` only).
- Add SIGINT/SIGTERM shutdown handlers.
- Import and start server from `src/server.ts`.

### `src/server.ts`

- Create `McpServer` instance with name, version, and capability declaration.
- Declare capabilities: `tools`, `resources` (if needed), `prompts` (if needed), `logging` (recommended), `tasks` (if needed).
- Call `registerAllTools(server)` and other registration functions.
- Gate logging: only send `notifications/message` if client declared `logging` capability.

## Step 7 — Generate Tool Template + One Real Tool

- Implement one tool end-to-end (name determined by server type).
- Add `title` (human-readable display name) and `description` (LLM-facing guidance).
- Add `annotations`: `readOnlyHint`, `idempotentHint`, `destructiveHint`, `openWorldHint` as appropriate.
- Zod input schema uses `z.strictObject()` and every field has `.describe()`.
- Add `.min()`/`.max()` on strings/arrays/numbers; use `z.enum` where appropriate.
- Tool returns both `content` (JSON string) and `structuredContent` (object).
- Tool handler uses try/catch; errors return `isError: true` via `createErrorResponse`.
- If long-running: set `execution.taskSupport: "optional"` and emit `notifications/progress` when `_meta.progressToken` is present.

## Step 8 — Optional: Resource Template (Only If Requested)

- Provide a static resource and/or a dynamic `ResourceTemplate` example only if the user asked for resources.
- Add resource annotations: `audience`, `priority` (0.0–1.0), `lastModified` (ISO 8601).
- Add `title`, `description`, `mimeType`, and optional `icons`.
- If subscriptions needed: declare `subscribe` capability and send `notifications/resources/updated` on changes.

## Step 9 — Optional: Prompt Template (Only If Requested)

- Provide prompts only if requested.
- Add `title`, `description`, and optional `icons`.
- Validate args with Zod; completions only where safe.
- Return `messages[]` with correct roles and content types (text, image, audio, embedded resource).

## Step 10 — Generate Helpers (`src/lib/*`)

- `errors.ts`: `getErrorMessage(error: unknown): string` + `createErrorResponse(code, message, result?)`
- `tool-response.ts`: `createToolResponse(structured)` that also emits JSON string to `content`

## Step 11 — Generate Tests (`tests/*.test.ts`)

- Use `node:test` + `node:assert/strict`.
- Include at least:
  - tool registration test
  - schema validation test
  - (optional) tool handler happy-path test if deterministic

## Step 12 — Generate README.md

Include:

- install
- run dev/build/test
- inspector usage (stdio/http)
- MCP config snippet for clients

## Generation Rules (Strict)

1. All Zod object schemas use `z.strictObject()`.
2. Every field uses `.describe()`.
3. Strings/arrays/numbers have `.min()` and `.max()` limits.
4. Every tool returns `content` + `structuredContent`.
5. `content` includes JSON string for backward compatibility.
6. Every tool has try/catch; errors return `isError: true`.
7. Use `createToolResponse` and `createErrorResponse`.
8. Every exported function has an explicit return type.
9. Local imports use `.js` extension.
10. No `console.log` in stdio servers; use `console.error`.
11. Annotations are hints, not security.
12. Sampling/elicit only if client capabilities support it.
13. Schemas live in `schemas/inputs.ts` and `schemas/outputs.ts`.
14. Prefer tool execution errors over protocol errors for invalid tool inputs.
15. Tool names: 1–128 chars, `[A-Za-z0-9_.-]` only, unique within a server.
16. Tools with no params use `z.strictObject({})`.
17. Every tool and prompt has `title` and `description`.
18. Gate logging notifications behind client `logging` capability.
19. Gate progress notifications behind `_meta.progressToken` presence.

## Output Requirements

Return the full generated project as a file tree with code blocks per file:

- `package.json`, `tsconfig.json`, `eslint.config.mjs`
- `src/index.ts`, `src/server.ts`
- `src/tools/index.ts` + `src/tools/{tool}.ts`
- `src/schemas/inputs.ts`, `src/schemas/outputs.ts`
- `src/lib/errors.ts`, `src/lib/tool-response.ts`
- `tests/{tool}.test.ts`
- `README.md`
