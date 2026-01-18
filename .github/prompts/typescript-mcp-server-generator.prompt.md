---
description: "Generate production-ready MCP servers in TypeScript"
---

> **Related Files:**  
> [typescript-mcp-server.instructions.md](../instructions/typescript-mcp-server.instructions.md) for mandatory rules | [typescript-mcp-expert.agent.md](../agents/typescript-mcp-expert.agent.md) for debugging workflows

# Generate TypeScript MCP Server

Generate a Model Context Protocol server following these steps.

## Step 1: Confirm SDK Line and Transport

- Use `@modelcontextprotocol/sdk` v1.x for production; v2 is pre-alpha (stable Q1 2026)
- v2 will split into `@modelcontextprotocol/server` and `@modelcontextprotocol/client`
- Choose transport:
  - stdio for local or CLI use
  - Streamable HTTP for remote or multi-client use (recommended)
  - HTTP+SSE only for legacy compatibility
- For Streamable HTTP (CVE-2025-66414 DNS rebinding protection):
  - Use `createMcpExpressApp()` helper (auto DNS protection)
  - Or use `hostHeaderValidation` middleware manually
  - Validate `Origin` header (MUST per spec 2025-11-25). If `Origin` is present and invalid, respond with HTTP 403.
  - MCP endpoint MUST support both `POST` and `GET` (GET may return SSE or HTTP 405)
  - Client `POST` MUST send `Accept` including both `application/json` and `text/event-stream`
  - Clients MUST send `MCP-Protocol-Version: <negotiated-version>` on subsequent HTTP requests; invalid/unsupported MUST return HTTP 400
  - Bind localhost for local use
  - Require auth for remote use
  - Use `MCP-Session-Id` header for stateful sessions (note: Node lowercases request headers → `req.headers['mcp-session-id']`)

## Step 2: Identify Server Type

| Type            | Examples             | Key Pattern                          |
| --------------- | -------------------- | ------------------------------------ |
| Data Access     | Filesystem, Database | `readOnlyHint: true`                 |
| API Integration | GitHub, Slack        | `openWorldHint: true`, rate limiting |
| DevOps          | Docker, K8s          | `destructiveHint: true`, elicitation |
| AI/ML           | Embeddings           | LLM sampling                         |

## Step 3: Generate Project Structure

```
src/
|- index.ts           # Entry, shutdown handlers, stdio transport
|- tools/
|  |- index.ts        # registerAllTools(server)
|  `- {name}.ts       # One file per tool
|- schemas/
|  |- inputs.ts       # Zod input schemas (use .strict())
|  `- outputs.ts      # Zod output schemas (DefaultOutputSchema)
`- lib/
   |- errors.ts       # createErrorResponse, getErrorMessage helpers
   |- tool_response.ts # createToolResponse helper
   `- types.ts        # Shared type definitions (optional)
```

## Step 4: Generate Configuration

**package.json:**

```json
{
  "name": "{{package-name}}",
  "version": "1.0.0",
  "mcpName": "{{mcp-name}}",
  "description": "{{description}}",
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "exports": {
    ".": "./dist/index.js"
  },
  "sideEffects": false,
  "bin": {
    "{{bin-name}}": "dist/index.js"
  },
  "files": ["dist", "README.md"],
  "scripts": {
    "clean": "node -e \"require('fs').rmSync('dist', {recursive: true, force: true})\"",
    "build": "tsc",
    "dev": "tsx watch src/index.ts",
    "start": "node dist/index.js",
    "test": "node --import tsx/esm --test tests/*.test.ts",
    "test:coverage": "node --import tsx/esm --test --experimental-test-coverage tests/*.test.ts",
    "lint": "eslint .",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "type-check": "tsc --noEmit",
    "inspector": "npx @modelcontextprotocol/inspector",
    "prepublishOnly": "npm run lint && npm run type-check && npm run build"
  },
  "keywords": ["mcp", "model-context-protocol"],
  "author": "{{author}}",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "{{repository-url}}"
  },
  "homepage": "{{homepage-url}}",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.25.1",
    "zod": "^4.0.0"
  },
  "devDependencies": {
    "@eslint/js": "^9.39.0",
    "@trivago/prettier-plugin-sort-imports": "^6.0.0",
    "@types/node": "^22.19.0",
    "eslint": "^9.23.0",
    "eslint-config-prettier": "^10.1.0",
    "eslint-plugin-unused-imports": "^4.3.0",
    "prettier": "^3.7.0",
    "tsx": "^4.21.0",
    "typescript": "^5.9.3",
    "typescript-eslint": "^8.50.0"
  },
  "engines": {
    "node": ">=20.0.0"
  }
}
```

**tsconfig.json:**

```json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2022"],
    "moduleDetection": "force",
    "isolatedModules": true,
    "verbatimModuleSyntax": true,
    "esModuleInterop": true,
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "incremental": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "types": ["node"]
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

**eslint.config.mjs:**

```javascript
import eslint from "@eslint/js";
import eslintConfigPrettier from "eslint-config-prettier";
import unusedImports from "eslint-plugin-unused-imports";
import { defineConfig } from "eslint/config";
import tseslint from "typescript-eslint";

export default defineConfig(
  { ignores: ["dist", "node_modules", "*.config.mjs", "*.config.js"] },
  eslint.configs.recommended,
  {
    files: ["src/**/*.ts"],
    extends: [
      tseslint.configs.strictTypeChecked,
      tseslint.configs.stylisticTypeChecked,
    ],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: { "unused-imports": unusedImports },
    rules: {
      "unused-imports/no-unused-imports": "error",
      "@typescript-eslint/consistent-type-imports": [
        "error",
        { prefer: "type-imports", fixStyle: "inline-type-imports" },
      ],
      "@typescript-eslint/consistent-type-exports": [
        "error",
        { fixMixedExportsWithInlineTypeSpecifier: true },
      ],
      "@typescript-eslint/explicit-function-return-type": [
        "error",
        { allowExpressions: true, allowTypedFunctionExpressions: true },
      ],
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-floating-promises": "error",
      "@typescript-eslint/no-misused-promises": [
        "error",
        { checksVoidReturn: { arguments: false } },
      ],
      "@typescript-eslint/only-throw-error": "error",
      "prefer-const": "error",
      "no-var": "error",
    },
  },
  eslintConfigPrettier
);
```

### Scripts Reference

| Script | Purpose |
|--------|--------|
| `dev` | Watch mode with tsx (hot reload) |
| `build` | Compile TypeScript to `dist/` |
| `start` | Run compiled server |
| `test` | Run unit tests with Node test runner |
| `inspector` | Launch MCP Inspector for testing |
| `lint` | Run ESLint |
| `type-check` | Verify types without emitting |

## Step 5: Generate Server Entry

**stdio transport:**

```typescript
#!/usr/bin/env node
import { createRequire } from "node:module";

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const require = createRequire(import.meta.url);
const packageJson = require("../package.json") as { version?: string };
const SERVER_VERSION = packageJson.version ?? "0.0.0";

const server = new McpServer(
  { name: "{{name}}", version: SERVER_VERSION },
  { instructions: "{{description}}", capabilities: { logging: {} } }
);

// Register tools here

await server.connect(new StdioServerTransport());
```

**Streamable HTTP transport (recommended with DNS protection):**

Default to stateless (no `sessionIdGenerator`) unless you explicitly need stateful sessions.

```typescript
#!/usr/bin/env node
import { createRequire } from "node:module";

import { createMcpExpressApp } from "@modelcontextprotocol/sdk/server/express.js";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";

const require = createRequire(import.meta.url);
const packageJson = require("../package.json") as { version?: string };
const SERVER_VERSION = packageJson.version ?? "0.0.0";

const server = new McpServer(
  { name: "{{name}}", version: SERVER_VERSION },
  { instructions: "{{description}}", capabilities: { logging: {} } }
);

// DNS rebinding protection auto-enabled (CVE-2025-66414)
const app = createMcpExpressApp({ host: "localhost" });

// Spec: MCP endpoint must support GET too (may return SSE or 405)
app.get("/mcp", (_req, res) => {
  res.sendStatus(405);
});

app.post("/mcp", async (req, res) => {
  const transport = new StreamableHTTPServerTransport({
    enableJsonResponse: true,
  });
  res.on("close", () => transport.close());
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
});

app.listen(process.env.PORT || 3000);
```

If you enable stateful sessions (`sessionIdGenerator`), you must reuse transports per session and route `POST`/`GET`/`DELETE` to them (see upstream `simpleStreamableHttp.ts` pattern). Do not create a new transport per request.

**Streamable HTTP transport (manual setup with middleware):**

```typescript
#!/usr/bin/env node
import { createRequire } from "node:module";

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { hostHeaderValidation } from "@modelcontextprotocol/sdk/server/middleware/hostHeaderValidation.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";

import express from "express";

const require = createRequire(import.meta.url);
const packageJson = require("../package.json") as { version?: string };
const SERVER_VERSION = packageJson.version ?? "0.0.0";

const server = new McpServer(
  { name: "{{name}}", version: SERVER_VERSION },
  { instructions: "{{description}}", capabilities: { logging: {} } }
);

const app = express();
app.use(express.json());
app.use(hostHeaderValidation(["localhost", "127.0.0.1"])); // DNS rebinding protection

app.post("/mcp", async (req, res) => {
  const transport = new StreamableHTTPServerTransport({
    enableJsonResponse: true,
  });
  res.on("close", () => transport.close());
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
});

app.listen(process.env.PORT || 3000);
```

### Shutdown Handlers

Add these to `src/index.ts` after transport connection:

```typescript
process.on('SIGTERM', () => {
  console.error('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.error('SIGINT received, shutting down gracefully');
  process.exit(0);
});
```

## Step 6: Generate Tool Template

```typescript
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';

import { createErrorResponse, getErrorMessage } from '../lib/errors.js';
import { createToolResponse } from '../lib/tool_response.js';
import { {{ToolName}}Schema } from '../schemas/inputs.js';
import { DefaultOutputSchema } from '../schemas/outputs.js';

export function register{{ToolName}}(server: McpServer): void {
  server.registerTool(
    '{{tool_name}}',
    {
      title: '{{Title}}',
      description: '{{Description for LLM}}',
      inputSchema: {{ToolName}}Schema,
      outputSchema: DefaultOutputSchema,
      annotations: {
        readOnlyHint: true,    // Adjust based on behavior
        idempotentHint: true
      }
    },
    async ({ param }) => {
      try {
        const result = await doWork(param);
        return createToolResponse({
          ok: true,
          result: { item: result, summary: 'Operation completed' },
        });
      } catch (err) {
        return createErrorResponse('E_{{TOOL_NAME}}', getErrorMessage(err));
      }
    }
  );
}
```

**schemas/inputs.ts example:**

```typescript
import { z } from 'zod';

export const {{ToolName}}Schema = z.strictObject({
  param: z.string().min(1).max(200).describe('Parameter description'),
});
```

**schemas/outputs.ts:**

```typescript
import { z } from "zod";

export const DefaultOutputSchema = z.strictObject({
  ok: z.boolean(),
  result: z.unknown().optional(),
  error: z.strictObject({ code: z.string(), message: z.string() }).optional(),
});
```

## Step 6.5: Generate Resource Templates

**Static resource:**

```typescript
server.registerResource(
  'config',
  { title: 'Configuration', mimeType: 'application/json' },
  async () => ({
    contents: [
      {
        uri: 'config://settings',
        text: JSON.stringify({ version: '1.0', env: process.env.NODE_ENV }),
      },
    ],
  })
);
```

**Dynamic resource with completion:**

```typescript
import { ResourceTemplate } from '@modelcontextprotocol/sdk/server/mcp.js';

server.registerResource(
  'user',
  new ResourceTemplate('users://{userId}', {
    list: undefined,
    complete: { userId: (p) => userIds.filter((id) => id.startsWith(p)) },
  }),
  { title: 'User Profile', mimeType: 'application/json' },
  async (uri, { userId }) => ({
    contents: [{ uri: uri.href, text: JSON.stringify(await getUser(userId)) }],
  })
);
```

## Step 6.75: Generate Prompt Templates

**Basic prompt:**

```typescript
server.registerPrompt(
  'review',
  {
    argsSchema: {
      code: z.string().min(1).describe('Code to review'),
      language: z.enum(['typescript', 'python']).describe('Programming language'),
    },
  },
  ({ code, language }) => ({
    messages: [
      {
        role: 'user',
        content: {
          type: 'text',
          text: `Review this ${language} code:\n\n${code}`,
        },
      },
    ],
  })
);
```

**Prompt with argument completion:**

```typescript
import { completable } from '@modelcontextprotocol/sdk/server/completable.js';

server.registerPrompt(
  'analyze',
  {
    argsSchema: {
      file: completable(
        z.string().min(1).describe('File path'),
        (partial) => files.filter((f) => f.startsWith(partial))
      ),
      depth: z.enum(['shallow', 'deep']).describe('Analysis depth'),
    },
  },
  ({ file, depth }) => ({
    messages: [
      {
        role: 'user',
        content: { type: 'text', text: `Analyze ${file} at ${depth} depth` },
      },
    ],
  })
);
```

## Step 7: Generate Helpers

**lib/errors.ts:**

```typescript
export interface ErrorResponse {
  content: { type: "text"; text: string }[];
  structuredContent: {
    ok: false;
    error: { code: string; message: string };
    result?: unknown;
  };
  isError: true;
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "string" && error.length > 0) return error;
  return "Unknown error";
}

export function createErrorResponse(
  code: string,
  message: string,
  result?: unknown
): ErrorResponse {
  const structured = {
    ok: false as const,
    error: { code, message },
    ...(result !== undefined && { result }),
  };
  return {
    content: [{ type: "text" as const, text: JSON.stringify(structured) }],
    structuredContent: structured,
    isError: true as const,
  };
}
```

**lib/tool_response.ts:**

```typescript
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";

export function createToolResponse<T extends Record<string, unknown>>(
  structuredContent: T
): CallToolResult & { structuredContent: T } {
  return {
    content: [{ type: "text", text: JSON.stringify(structuredContent) }],
    structuredContent,
  };
}
```

## Step 8: Generate Tests

**Inspector testing:**

```bash
# stdio server
npx @modelcontextprotocol/inspector node dist/index.js

# HTTP server
npx @modelcontextprotocol/inspector http://localhost:3000/mcp
```

**Unit test boilerplate (tests/tools.test.ts):**

```typescript
import { describe, it } from 'node:test';
import assert from 'node:assert';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { register{{ToolName}} } from '../src/tools/{{tool_name}}.js';

describe('{{ToolName}} Tool', () => {
  it('registers successfully', () => {
    const server = new McpServer(
      { name: 'test-server', version: '1.0.0' },
      { capabilities: {} }
    );
    register{{ToolName}}(server);
    assert.ok(server);
  });

  it('validates input schema', () => {
    const schema = z.strictObject({
      param: z.string().min(1).max(200),
    });
    const result = schema.safeParse({ param: 'test' });
    assert.ok(result.success);
  });
});
```

Run: `npm test` or `node --import tsx/esm --test tests/*.test.ts`

## Step 9: Generate README

```markdown
# {{Package Name}}

{{Description}}

## Installation

\`\`\`bash
npm install {{package-name}}
\`\`\`

## Usage

### CLI

\`\`\`bash
{{bin-name}}
\`\`\`

### MCP Configuration

\`\`\`json
{
  "mcpServers": {
    "{{mcp-name}}": {
      "command": "node",
      "args": ["path/to/dist/index.js"]
    }
  }
}
\`\`\`

## Development

\`\`\`bash
npm run dev      # Watch mode
npm run build    # Compile
npm test         # Run tests
npm run inspector # Launch MCP Inspector
\`\`\`

## Testing

\`\`\`bash
npx @modelcontextprotocol/inspector node dist/index.js
\`\`\`

## License

MIT
```

## Generation Rules

1. Every Zod object schema uses `z.strictObject()` to reject unknown fields
2. Every Zod field gets `.describe()` for LLM context
3. Every string/array/number has `.min()` and `.max()` limits
4. Every tool returns `content` plus `structuredContent`
5. Structured results include a JSON string in `content`
6. Every tool has try-catch with `isError: true` on failure
7. Use `createToolResponse` and `createErrorResponse` helpers
8. Every exported function has an explicit return type
9. All imports use `.js` extension
10. No `console.log` in stdio servers (use `console.error`)
11. Annotations are hints; do not use them as security
12. Sampling and elicitation only when client capabilities allow it
13. Schemas organized in `schemas/inputs.ts` and `schemas/outputs.ts`
14. Prefer tool execution errors (not protocol errors) for invalid tool inputs so the model can self-correct
15. Tool names should be 1–128 chars and only contain `[A-Za-z0-9_.-]`
16. For tools with no parameters, prefer `z.strictObject({})` (reject unknown fields)

## Annotation Selection

| Tool Behavior             | Annotations                                |
| ------------------------- | ------------------------------------------ |
| Read files, search, query | `readOnlyHint: true, idempotentHint: true` |
| Call external API         | `openWorldHint: true`                      |
| Delete, modify, write     | `destructiveHint: true`                    |
| LLM-powered               | `idempotentHint: false`                    |

## Transport Selection

| Use Case                       | Transport              |
| ------------------------------ | ---------------------- |
| CLI tool, IDE integration      | stdio                  |
| Cloud deployment, multi-client | Streamable HTTP        |
| Legacy clients                 | HTTP+SSE (compat only) |

## Validation Checklist

- [ ] `inputSchema` and `outputSchema` defined with Zod
- [ ] `z.strictObject()` used for all Zod object schemas (reject unknown fields)
- [ ] `.describe()` on every schema field
- [ ] `.min()` and `.max()` limits on strings, arrays, numbers
- [ ] `content` plus `structuredContent` returned
- [ ] JSON string in `content` for structured results
- [ ] `isError: true` on error responses
- [ ] Use `createToolResponse` and `createErrorResponse` helpers
- [ ] Annotations match tool behavior
- [ ] `.js` extensions in imports
- [ ] No `console.log` in stdio (use `console.error` for logs)
- [ ] Streamable HTTP uses `createMcpExpressApp()` or `hostHeaderValidation` middleware (CVE-2025-66414)
- [ ] Streamable HTTP validates `Origin` header (MUST per spec)
- [ ] Streamable HTTP enforces auth for remote/public use
- [ ] Session management configured if stateful (`sessionIdGenerator`)
- [ ] `SIGTERM` and `SIGINT` handlers added
