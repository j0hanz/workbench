# TypeScript MCP Server Instructions (Protocol 2025-11-25)

## Related Files

- [typescript-mcp-expert.agent.md](../agents/typescript-mcp-expert.agent.md) - Agent workflows and debugging
- [typescript-mcp-server-generator.prompt.md](../prompts/typescript-mcp-server-generator.prompt.md) - Project scaffolding generator

# TypeScript MCP Server Rules (mcp-expert aligned)

## Protocol + Stack Baseline

- Protocol target is MCP `2025-11-25`.
- Prefer latest stable `@modelcontextprotocol/sdk` v1.x unless the repo intentionally pins otherwise.
- Use Node `>=20`, TypeScript strict mode, and Zod v4.
- Treat protocol conformance and security controls as mandatory, not optional enhancements.

## Architecture Principles (Mandatory)

- Keep boundaries explicit: Host handles user consent, Client handles negotiation/transport, Server exposes capabilities.
- Servers must not assume access to conversation history or other servers.
- Expose only capabilities actually implemented.
- For every new feature, define trust boundary and user-consent expectations.

## Lifecycle and Negotiation

- Initialization flow must be: `initialize` request -> initialize result -> `notifications/initialized`.
- Verify negotiated `protocolVersion` and capability intersections before enabling advanced features.
- For HTTP transports, require `MCP-Protocol-Version: <negotiated>` on post-init requests; reject invalid/unsupported values with `400`.
- Do not depend on a custom shutdown message; close transport cleanly and handle process signals.

## Repository Convention (Default)

Use this structure unless the repository already has established patterns:

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

## TypeScript and Module Rules

- Use named exports only.
- Use type-only imports where possible.
- Use `.js` extensions for local imports when emitting NodeNext/ESM.
- Exported functions should use explicit return types.
- Enable or justify deviation from `strict`, `noUncheckedIndexedAccess`, `verbatimModuleSyntax`, and `isolatedModules`.
- If used as CLI/bin entrypoint, `src/index.ts` must start with `#!/usr/bin/env node` on line 1.

## Tool Standards

### Naming and Metadata

- Tool names should be unique, 1-128 chars, and match `[A-Za-z0-9_.-]+`.
- Every tool must provide `name` and a precise `description`.
- Every tool should provide `title`, `annotations`, and optional `icons`.

### Input/Output Validation

- Use `z.strictObject()` for object inputs.
- Add `.describe()` to each field.
- Add explicit bounds (`.min()`/`.max()`) and enums where appropriate.
- Tools with no args should use `z.strictObject({})`.
- If you define `outputSchema`, ensure returned `structuredContent` conforms exactly.

### Result and Error Semantics

- Prefer tool execution errors for user-correctable issues; avoid escalating routine validation failures to protocol errors.
- Tool logic failures must return `isError: true` in the tool result.
- If returning `structuredContent`, also include JSON text in `content` for compatibility.
- Supported `content` entries include `text`, `image`, `audio`, `resource_link`, and embedded `resource`.

### Canonical Error-Safe Pattern

```ts
server.registerTool(
  "tool_name",
  {
    title: "Human Title",
    description: "What it does and when to use it",
    inputSchema: z.strictObject({
      param: z.string().min(1).max(200).describe("Parameter description"),
    }),
    annotations: { readOnlyHint: true, idempotentHint: true },
  },
  async (params) => {
    try {
      const result = await doWork(params);
      return {
        content: [{ type: "text", text: JSON.stringify(result) }],
        structuredContent: result,
      };
    } catch (err) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              ok: false,
              error: { code: "E_FAILED", message: getErrorMessage(err) },
            }),
          },
        ],
        structuredContent: {
          ok: false,
          error: { code: "E_FAILED", message: getErrorMessage(err) },
        },
        isError: true,
      };
    }
  },
);
```

## Annotations Are Advisory Only

- `readOnlyHint`, `idempotentHint`, `destructiveHint`, and `openWorldHint` are hints, not authorization.
- Never use annotations as security controls.

## Resources

- Use unique URIs and valid schemes.
- For filesystem resources and roots, restrict to `file://` and enforce canonical path bounds (prevent traversal).
- Use RFC 6570 URI templates for dynamic resources.
- Return `contents[]` with `{ uri, text }` or `{ uri, blob }` and include `mimeType` when applicable.
- If `listChanged` or `subscribe` capabilities are declared, emit corresponding notifications accurately.
- Resource annotations may include `audience`, `priority` (0.0-1.0), and `lastModified` (ISO 8601).

## Prompts

- Declare `prompts` capability before exposing prompts.
- Validate arguments.
- Prompts should include `name`, `title`, and `description`.
- Return `messages[]` with valid roles and content blocks.

## Sampling, Roots, and Elicitation

- Sampling is allowed only when client declares `sampling`; maintain human-in-the-loop review.
- Default sampling context should remain minimal (`includeContext: "none"` unless explicitly justified).
- Roots are `file://` only, user-approved, and path-validated.
- Use elicitation `url` mode for secrets/credentials; do not collect sensitive credentials in `form` mode.
- Handle all elicitation outcomes: `accept`, `decline`, `cancel`.

## Transport Rules

### stdio

- JSON-RPC goes to `stdout` only.
- Logs and diagnostics go to `stderr` only.
- Never emit non-protocol output on `stdout`.

### Streamable HTTP (Preferred for Remote)

- Provide a single MCP endpoint supporting both `POST` and `GET`.
- `GET` must provide SSE (`text/event-stream`) or return `405` (not `404`).
- For JSON-RPC `POST`, expect `Accept: application/json, text/event-stream`.
- Validate `Origin` on incoming requests; invalid origin should return `403`.
- For local servers, bind to `127.0.0.1`.
- If sessions are used, server may issue `Mcp-Session-Id` at init and clients must send it on subsequent requests.
- Invalid/expired sessions should return `404` so clients re-initialize.
- Support SSE resume with `Last-Event-ID` where implemented.
- Do not fan out the same JSON-RPC response across multiple SSE streams.
- HTTP+SSE legacy transport is backward-compat only.

## Auth and Authorization (HTTP)

- Require authentication for remote/public HTTP deployments.
- Implement OAuth 2.1 + PKCE for bearer-token flows.
- Support RFC 9728 protected resource metadata discovery (`WWW-Authenticate` and/or `/.well-known/oauth-protected-resource`).
- Reject tokens not issued for this MCP server (no token passthrough).

## Cancellation, Tasks, Progress, Logging

- Support request cancellation via `notifications/cancelled` for in-flight non-task requests.
- For task-mode execution, use `tasks/cancel`.
- If tasks are supported, declare `capabilities.tasks` (for example `tasks.requests.tools.call`) and set per-tool `execution.taskSupport` (`required`, `optional`, or `forbidden`).
- Task lifecycle should follow: `pending` -> `working` -> `completed` | `failed` | `cancelled` | `input_required`.
- Include `io.modelcontextprotocol/related-task` metadata on task-related messages.
- Emit progress only when `_meta.progressToken` is provided; keep progress monotonic.
- Logging levels must follow RFC 5424 and honor `logging/setLevel`.
- Emit logging notifications only if client declared `logging`.
- Never log secrets, credentials, tokens, or sensitive PII.

## Security Baseline

- Validate all external inputs, including URI params and tool arguments.
- Enforce bounds to prevent unbounded memory/time behavior.
- Protect file operations against traversal and symlink-escape.
- Use timeouts and cancellation propagation for external calls.
- Avoid dynamic code execution (`eval`, `new Function`).
- Keep secrets in environment variables or secret stores, never in code or logs.

## Testing and Verification

- Use Inspector for end-to-end checks: `npx @modelcontextprotocol/inspector node dist/index.js` and `npx @modelcontextprotocol/inspector http://localhost:3000/mcp`.
- Validate capability truthfulness: declared capabilities must work.
- Test tools across happy path, schema failure, and execution-error paths.
- Test resource read/list/template behavior and prompt argument validation.
- Test cancellation, progress, and task lifecycle when implemented.
- Prefer deterministic unit/integration tests (`node:test`) and run build before release.

## Quick Conformance Checklist

- JSON-RPC 2.0 message structure is valid.
- Initialization ordering is correct.
- Capability declaration matches implementation.
- Tool schemas are strict and bounded.
- Tool failures return `isError: true`.
- Resources use valid URIs and safe path handling.
- Streamable HTTP enforces `Origin` and protocol/session headers.
- Logging and progress are gated by client capabilities.
- Sensitive data is never logged or exposed.
