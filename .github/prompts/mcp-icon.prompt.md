# MCP Icon Branding Implementation Prompt (TypeScript, MCP Protocol 2025-11-25)

## Overview

**Role:** Senior TypeScript/Node.js Engineer + MCP SDK Integrator

## Objective

You are given an MCP server codebase (TypeScript) and an SVG/PNG/JPG logo file path. Update the server to expose **icons** metadata (server + optionally tools/resources) per **MCP Protocol 2025-11-25**, using `@modelcontextprotocol/sdk@1.0.0+`.

Implement the changes with **VERY LOW risk**, no destructive operations, and keep behavior identical if the asset is missing.

**Implement directly.**

### Functional requirements

1. **Asset preparation**
   - Ensure an `assets/` directory exists.
   - Place `assets/logo.svg` (or `.png` / `.jpg`) there.
   - Enforce file size < 2MB (warn if larger; do not fail build unless instructed).

2. **Build pipeline**
   - Update `package.json` so that assets are copied to `dist/assets` on build.
   - Use a cross-platform Node copy command (no bash-only assumptions).
   - Ensure `npm run build` results in `dist/assets/logo.svg` existing.

3. **Icon loading**
   - Add a small helper `getLocalIconData(): string | undefined` in the server entry file.
   - Use `readFileSync` and resolve path via `new URL('../assets/logo.svg', import.meta.url)` (ESM-safe).
   - Return a **data URI** with `base64` content.
   - On any error, return `undefined` (graceful fallback).

4. **Server metadata**
   - When creating `new McpServer(...)`, conditionally include:
     - `icons: [{ src, mimeType, sizes }]`
   - Must use **conditional spread** to preserve backward compatibility:
     - `...(localIcon ? { icons: [...] } : {})`

5. **Tools & resources (optional but supported)**
   - If the codebase has tool/resource registration functions, update their signatures to accept `serverIcon?: string`.
   - Apply the same conditional spread to tool/resource metadata.
   - Pass `localIcon` from server creation to `registerTools(server, localIcon)` and `registerResources(server, localIcon)`.

6. **Verification instructions**
   - Provide the exact commands:
     - `npm run build`
     - `npm run type-check` (if present)
     - `npm run lint` (if present)
     - `npm test` (if present)
   - Include a manual check step: run server + confirm icon shows in “MCP Inspector” (or equivalent client).
   - Add troubleshooting checklist for: missing assets after build, TypeScript `icons` typing error, icon not appearing.

## Standards & Constraints

- **Compatibility:** TypeScript 5.0+, Node.js 20+, ESM-friendly path resolution.
- **Safety:** No destructive ops; roll back via `git checkout <files>`.
- **Robustness:** If asset missing/unreadable, server must still start with no icon.
- **Code Style:** Clean, minimal, idiomatic TypeScript; prefer small pure helpers.
- **Error Handling:** `try/catch` around icon read; no thrown errors from icon loading.
- **MIME correctness:**
  - SVG: `image/svg+xml`, sizes `['any']`
  - PNG: `image/png`, sizes like `['32x32']` or omit if unknown
  - JPEG: `image/jpeg`

## Examples

### Data URI output

- Input: `assets/logo.svg`
- Output: `data:image/svg+xml;base64,PHN2Zy4uLg==...`

### Conditional metadata pattern

- If `localIcon` undefined → no `icons` field present at all.

## Response Format

- Output a concise patch-style answer:
  1. **Files to modify** (list)
  2. **Exact code snippets** to paste (server file + tools/resources if applicable)
  3. **Exact `package.json` scripts** section
  4. **Verification commands**
  5. **Troubleshooting checklist**
- Include docstrings/comments only where they meaningfully clarify behavior.
