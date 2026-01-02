---
description: 'Rules for building MCP servers with TypeScript SDK'
applyTo: '**/*.ts, **/*.js, **/package.json'
---

# TypeScript MCP Server Rules

> **SDK**: `@modelcontextprotocol/sdk` **v1.x (production)** | **Zod**: v3.24+ (this repo) or v4 | **Node**: `>=20.0.0` | **TS**: `5.9+`
>
> **Note**: SDK v2 is pre-alpha; v1.x is the recommended production line.

## Mandatory Rules

### Versioning & Compatibility

- Use `@modelcontextprotocol/sdk` v1.x for production servers
- SDK supports Zod v3 and v4; this repo currently uses Zod v3.24.x. Import `z` from `zod` unless you intentionally pin `zod/v3` or `zod/v4`.
- **v2 Migration Note**: SDK v2 (pre-alpha, stable Q1 2026) splits into `@modelcontextprotocol/server` and `@modelcontextprotocol/client`

### TypeScript & Imports

- Use `.js` extensions in all local imports (NodeNext resolution)
- Use `import type { X }` for type-only imports (inline style: `import { type X }`)
- Named exports only (no default exports)
- Explicit return types on exported functions
- Enable `strict`, `noUncheckedIndexedAccess`, `verbatimModuleSyntax`, `isolatedModules`
- Use `prefer-const`, no `var`, prefer template literals

### Tool Implementation

```typescript
server.registerTool(
  'tool_name',
  {
    title: 'Human Title', // Required: UI display
    description: 'LLM description', // Required: clear, actionable
    inputSchema: z
      .object({
        param: z.string().min(1).max(200).describe('Parameter description'),
      })
      .strict(), // Use .strict() to reject unknown fields
    outputSchema: z
      .object({
        ok: z.boolean(),
        result: z.unknown().optional(),
        error: z.object({ code: z.string(), message: z.string() }).optional(),
      })
      .strict(),
    annotations: {
      /* hints */
    },
  },
  async (params) => {
    const structured = { ok: true, result: await doWork(params) };
    return {
      content: [{ type: 'text', text: JSON.stringify(structured) }],
      structuredContent: structured,
    };
  }
);
```

### Output Schema Pattern

```typescript
outputSchema: z.object({
  ok: z.boolean(),
  result: z.unknown().optional(),
  error: z.object({ code: z.string(), message: z.string() }).optional(),
}).strict();
```

### Structured Content (Backward Compatibility)

- When you return `structuredContent`, also include a JSON string in `content` for older clients

### Annotations (Hints Only)

| Hint              | When True                                                                                                                                                                         |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `readOnlyHint`    | Doesn't modify state                                                                                                                                                              |
| `idempotentHint`  | Safe to retry: repeated calls with same arguments have the same _effect_ (read-only tools are often idempotent; avoid setting this if results are intentionally nondeterministic) |
| `destructiveHint` | Irreversible changes (only makes sense for tools that modify state)                                                                                                               |
| `openWorldHint`   | Calls external APIs                                                                                                                                                               |

> Annotations are not a security boundary. Enforce authorization separately.

### Transport Rules

- **Streamable HTTP** is recommended for remote servers; **stdio** is ideal for local/CLI use
- **HTTP+SSE** is a legacy transport; only support it for backward compatibility
- **stdio**: never write non-MCP data to stdout; use `console.error()` for logs
- **Streamable HTTP security** (CVE-2025-66414):
  - Use `createMcpExpressApp()` helper for automatic DNS rebinding protection
  - Or use `hostHeaderValidation` middleware manually
  - Validate `Origin` header (MUST per spec 2025-11-25). If `Origin` is present and invalid, respond with HTTP 403.
  - Bind localhost for local use; require auth for remote use
  - Use `MCP-Session-Id` header for stateful sessions (Node/Express lowercases request header names, so you’ll read it as `req.headers['mcp-session-id']`)

## Error Handling

```typescript
// Helper: extract message from unknown error
function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string' && error.length > 0) return error;
  return 'Unknown error';
}

// Tool handler pattern
async (params): Promise<ToolResponse> => {
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
};
```

## Capabilities & UX

- **Prompts**: user-controlled; declare the prompts capability and validate prompt args
- **Sampling**: only if the client declares sampling capability; keep a human in the loop
- **Sampling tool use**: only if the client declares `sampling.tools`
- **Elicitation**: only if the client declares elicitation capability; use URL mode for sensitive info

## Security

- **DNS rebinding (CVE-2025-66414)**: Use `createMcpExpressApp()` or `hostHeaderValidation` middleware for HTTP servers
- Validate paths: resolve symlinks, check against allowed roots
- Set limits: `.min()`, `.max()` on strings/arrays/numbers
- Use `.strict()` on all Zod object schemas to reject unknown fields
- Use `AbortSignal.timeout()` on external calls
- No `eval()`, `Function()`, or dynamic code
- Secrets in environment variables only

## Patterns

### Response Helpers

```typescript
// lib/tool_response.ts
import type { CallToolResult } from '@modelcontextprotocol/sdk/types.js';

export function createToolResponse<T extends Record<string, unknown>>(
  structuredContent: T
): CallToolResult & { structuredContent: T } {
  return {
    content: [{ type: 'text', text: JSON.stringify(structuredContent) }],
    structuredContent,
  };
}
```

### stdio Server

```typescript
import { createRequire } from 'node:module';

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

const require = createRequire(import.meta.url);
const packageJson = require('../package.json') as { version?: string };
const SERVER_VERSION = packageJson.version ?? '0.0.0';

const server = new McpServer(
  { name: 'my-server', version: SERVER_VERSION },
  { instructions: 'Usage for LLM', capabilities: { logging: {} } }
);
await server.connect(new StdioServerTransport());
```

### Streamable HTTP Server

**Option 1: Stateless (recommended default; simplest)**

Use this if you do not need session persistence, resumability, or server→client notifications.

```typescript
import { createRequire } from 'node:module';

import { createMcpExpressApp } from '@modelcontextprotocol/sdk/server/express.js';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';

const require = createRequire(import.meta.url);
const packageJson = require('../package.json') as { version?: string };
const SERVER_VERSION = packageJson.version ?? '0.0.0';

const server = new McpServer(
  { name: 'my-server', version: SERVER_VERSION },
  { instructions: 'Usage for LLM', capabilities: { logging: {} } }
);

// DNS rebinding protection auto-enabled for localhost
const app = createMcpExpressApp({ host: 'localhost' });

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

**Option 2: Stateful sessions (advanced; requires session reuse + GET/DELETE)**

If you enable sessions (`sessionIdGenerator`), you must reuse the same transport for the lifetime of that session and route `POST`, `GET`, and `DELETE` to it. This is the pattern used by the upstream SDK examples.

Key requirements:

- Validate `Origin` (if present) and return HTTP 403 when invalid.
- Read the session header as `req.headers['mcp-session-id']` and treat it as case-insensitive on the wire (spec name: `MCP-Session-Id`).
- Implement `DELETE` to close server-side session state.

```typescript
import { createRequire } from 'node:module';

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { hostHeaderValidation } from '@modelcontextprotocol/sdk/server/middleware/hostHeaderValidation.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';

import express from 'express';

const require = createRequire(import.meta.url);
const packageJson = require('../package.json') as { version?: string };
const SERVER_VERSION = packageJson.version ?? '0.0.0';

const server = new McpServer(
  { name: 'my-server', version: SERVER_VERSION },
  { instructions: 'Usage for LLM', capabilities: { logging: {} } }
);

const app = express();
app.use(express.json());
app.use(hostHeaderValidation(['localhost', '127.0.0.1'])); // DNS rebinding protection

const transports = new Map<string, StreamableHTTPServerTransport>();

app.all('/mcp', async (req, res) => {
  const origin = req.headers.origin;
  if (typeof origin === 'string' && origin.length > 0) {
    // Enforce an allow-list appropriate for your deployment.
    const isAllowedOrigin = origin === 'http://localhost:3000';
    if (!isAllowedOrigin) {
      res.status(403).end();
      return;
    }
  }

  const sessionId =
    typeof req.headers['mcp-session-id'] === 'string'
      ? req.headers['mcp-session-id']
      : undefined;
  let transport = sessionId ? transports.get(sessionId) : undefined;

  if (!transport) {
    transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => crypto.randomUUID(),
      enableJsonResponse: true,
    });
    await server.connect(transport);

    // Once initialized, the transport will have a session ID the client must send on future requests.
    // Persist the transport by its session ID.
    transport.onsessioninitialized = (newSessionId) => {
      transports.set(newSessionId, transport!);
    };
    transport.onsessionclosed = (closedSessionId) => {
      transports.delete(closedSessionId);
    };
  }

  res.on('close', () => transport!.close());
  const body = req.method === 'POST' ? req.body : undefined;
  await transport.handleRequest(req, res, body);
});

app.listen(3000);
```

### Dynamic Resource

```typescript
import { ResourceTemplate } from '@modelcontextprotocol/sdk/server/mcp.js';

server.registerResource(
  'user',
  new ResourceTemplate('users://{userId}', {
    list: undefined,
    complete: { userId: (p) => ids.filter((id) => id.startsWith(p)) },
  }),
  { title: 'User', mimeType: 'application/json' },
  async (uri, { userId }) => ({
    contents: [{ uri: uri.href, text: JSON.stringify(data) }],
  })
);
```

### Prompt with Completion

```typescript
import { completable } from '@modelcontextprotocol/sdk/server/completable.js';

server.registerPrompt(
  'review',
  {
    argsSchema: {
      lang: completable(z.enum(['ts', 'py']), (p) =>
        ['ts', 'py'].filter((l) => l.startsWith(p))
      ),
      code: z.string(),
    },
  },
  ({ lang, code }) => ({
    messages: [
      {
        role: 'user',
        content: { type: 'text', text: `Review ${lang}:\n${code}` },
      },
    ],
  })
);
```

### LLM Sampling

```typescript
const response = await server.server.createMessage({
  messages: [{ role: 'user', content: { type: 'text', text: 'Summarize' } }],
  maxTokens: 500,
});
```

### User Elicitation

```typescript
const result = await server.server.elicitInput({
  message: 'Confirm?',
  requestedSchema: {
    type: 'object',
    properties: { confirm: { type: 'boolean' } },
    required: ['confirm'],
  },
});
if (result.action === 'accept' && result.content?.confirm) {
  /* proceed */
}
```

## Testing

```bash
npx @modelcontextprotocol/inspector node dist/index.js        # stdio
npx @modelcontextprotocol/inspector http://localhost:3000/mcp # HTTP
```

## Shutdown

```typescript
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
```
