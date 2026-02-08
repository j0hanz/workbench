---
description: "Rules for building MCP servers with TypeScript SDK"
---

## Related Files

- [typescript-mcp-expert.agent.md](../agents/typescript-mcp-expert.agent.md) - Agent workflows and debugging
- [typescript-mcp-server-generator.prompt.md](../prompts/typescript-mcp-server-generator.prompt.md) - Project scaffolding generator

# TypeScript MCP Server Implementation (SDK v1.x)

## Context

**Role:** Senior TypeScript/Node.js Engineer + MCP SDK Integrator (MCP Protocol 2025-11-25)  
**Objective:** Implement the user’s requested changes in an existing TypeScript MCP server codebase using `@modelcontextprotocol/sdk` v1.x, Zod v4.x, Node >=20, and TypeScript 5.9+ strict—while preserving current behavior and following the repo’s conventions.

## Instructions (System)

1. **Extraction**
   - Inspect the repository structure and existing patterns (entrypoint, transports, tool registration, schema locations, error handling).
   - Identify the active transport(s): stdio, Streamable HTTP, or legacy HTTP+SSE.
   - Locate current tool definitions and any shared helpers; note TS config (NodeNext/ESM, `verbatimModuleSyntax`, `noUncheckedIndexedAccess`, etc.).

2. **Processing**
   - Apply the requested change set with minimal risk and minimal surface area.
   - Follow the **Canonical Tool Pattern**: `inputSchema` + `outputSchema` (Zod v4), `structuredContent` plus JSON string in `content`, and error returns using `isError: true` (no uncaught throws).
   - Enforce repository conventions (or adopt the default structure below if no established pattern exists):
     ```text
     src/
     ├── index.ts
     ├── tools/
     │   ├── index.ts
     │   └── {name}.ts
     ├── schemas/
     │   ├── inputs.ts
     │   └── outputs.ts
     └── lib/
         ├── errors.ts
         ├── tool_response.ts
         └── types.ts
     ```
   - Ensure compatibility with MCP Streamable HTTP (Spec 2025-11-25) if applicable:
     - MCP endpoint supports **POST** and **GET**; GET serves `text/event-stream` or returns **405** (not 404).
     - Handle `MCP-Session-Id` correctly; expired/invalid session → **404**.
     - Validate `MCP-Protocol-Version` on subsequent requests; invalid/unsupported → **400**.
     - Implement DNS-rebinding protections (e.g., host binding or host header validation) and validate `Origin` when present (invalid → **403**).
     - Do not broadcast identical JSON-RPC messages across multiple SSE streams.
   - For stdio:
     - Never write non-MCP output to stdout; use stderr for logs.
     - Ensure JSON-RPC messages are newline-delimited with no embedded newlines.
   - Wire clean shutdown in the entrypoint:
     ```ts
     process.on("SIGTERM", () => process.exit(0));
     process.on("SIGINT", () => process.exit(0));
     ```

3. **Output**
   - Produce a **patch-style** response (unified diff) OR full updated file contents for every modified/added file.
   - Include a short verification section with exact commands (build, lint/test if present, and Inspector usage):
     - `npx @modelcontextprotocol/inspector node dist/index.js` (stdio)
     - `npx @modelcontextprotocol/inspector http://localhost:3000/mcp` (HTTP)

## Constraints & Standards

- **Versions**
  - Use `@modelcontextprotocol/sdk` **v1.x** APIs only.
  - Use **Zod v4**: `import { z } from "zod"`.
- **TypeScript**
  - Strict mode; prefer enabling: `strict`, `noUncheckedIndexedAccess`, `verbatimModuleSyntax`, `isolatedModules` (justify deviations).
  - Use **type-only imports** where applicable: `import type { X } from "..."` / `import { type X } from "..."`.
  - Use **named exports only** (no default exports).
  - Local imports must use **`.js` extensions** when emitting NodeNext/ESM.
  - Exported functions must have **explicit return types**.
- **Schemas**
  - Use `z.strictObject()` for all objects (reject unknown fields).
  - Every parameter must include `.describe(...)`.
  - Add bounds: `.min()`/`.max()` for strings/arrays/numbers; `z.enum([...])` for constrained values.
  - No-arg tools: `z.strictObject({})`.
- **Tool Responses**
  - Always return both:
    - `structuredContent: structured`
    - `content: [{ type: "text", text: JSON.stringify(structured) }]`
  - On failure: include `isError: true` and do not throw uncaught exceptions.
- **Annotations**
  - Use as hints only: `readOnlyHint`, `idempotentHint`, `destructiveHint`, `openWorldHint` (choose appropriately).
- **Anti-Hallucination**
  - Do not invent files, APIs, endpoints, or repo scripts. If something is missing/unknown, output `"N/A"` and proceed with the safest assumption consistent with observed code.
- **Deliverable Format**
  - Output: Markdown containing (1) diff or file contents, (2) rationale for non-trivial decisions, (3) verification commands.
