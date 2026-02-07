# MCP Icon Branding Implementation (TypeScript, MCP Protocol 2025-11-25)

## Context

**Role:** Senior TypeScript/Node.js Engineer + MCP SDK Integrator  
**Objective:** Update an existing TypeScript MCP server codebase to expose `icons` metadata (server + optionally tools/resources) per **MCP Protocol 2025-11-25**, using `@modelcontextprotocol/sdk@1.0.0+`. Implement with _very low risk_: no destructive ops; if icon asset is missing/unreadable, behavior must remain identical (server still starts, no icon metadata emitted).

You are given:

- A local MCP server codebase (TypeScript)
- A logo file path (SVG/PNG/JPG)

You must implement the changes in the codebase and then output a concise patch-style answer.

## Instructions (System)

Execute in phases: 1) Extraction 2) Processing 3) Output.

1. **Extraction (repo inspection, zero assumptions)**
   - Identify:
     - Server entry file (where `new McpServer(...)` is created).
     - Project module mode (ESM/CJS), Node version target, build toolchain (tsc/tsup/vite/etc).
     - Output directory structure (e.g., `dist/index.js`, `dist/src/index.js`, etc).
     - Existing `package.json` scripts (`build`, `type-check`, `lint`, `test`) and whether `postbuild` exists.
     - Any tool/resource registration functions (e.g., `registerTools`, `registerResources`, or similar) and where metadata objects are defined.
   - Determine the logo file extension and confirm intended canonical asset name: `assets/logo.<ext>`.

2. **Processing (implement minimal, low-risk changes)**
   - **Asset preparation**
     - Ensure an `assets/` directory exists at repo root (create if missing).
     - Place the provided logo into `assets/logo.svg` (or `.png`/`.jpg`), preserving original file content.
     - Add a non-failing size check (< 2MB):
       - If file size ≥ 2MB: `console.warn(...)` during build/copy step.
       - Do **not** fail build unless explicitly instructed (you are not instructed to fail).
   - **Build pipeline**
     - Update `package.json` so `npm run build` results in the asset being copied to `dist/assets/logo.<ext>`.
     - Must be cross-platform, Node-based (no bash-only `cp`, no shell-specific assumptions).
     - Preferred approach:
       - Add `scripts/copy-assets.mjs` (ESM) that:
         - Ensures `dist/assets` exists.
         - Copies `assets/logo.<ext>` → `dist/assets/logo.<ext>` if present.
         - If missing: exits 0, optionally warns.
         - Performs the <2MB warning check.
       - Wire it via `postbuild` or directly appended to `build` with minimal disruption.
   - **Icon loading helper**
     - In the server entry file, add:
       - `function getLocalIconData(): string | undefined`
       - Use `readFileSync`
       - Resolve via `new URL('../assets/logo.svg', import.meta.url)` (ESM-safe)
         - IMPORTANT: Because dist layout can differ, you may add fallback candidates (e.g., `./assets/logo.svg`) but you must include the required `new URL('../assets/logo.svg', import.meta.url)` form as the primary attempt.
       - Return a **data URI** with base64 content: `data:<mime>;base64,<...>`
       - On **any** error: return `undefined` (no throws, no server startup impact).
     - MIME correctness:
       - SVG: `image/svg+xml`, `sizes: ['any']`
       - PNG: `image/png`, sizes like `['32x32']` or omit if unknown
       - JPEG/JPG: `image/jpeg`, sizes omit if unknown
     - Support `.svg`, `.png`, `.jpg`/`.jpeg` gracefully (choose based on the actual asset present).
   - **Server metadata**
     - When creating `new McpServer(...)`, conditionally include `icons` using conditional spread:
       - `...(localIcon ? { icons: [{ src: localIcon, mimeType, sizes }] } : {})`
     - Ensure when `localIcon` is `undefined`, there is **no** `icons` field at all.
   - **Tools & resources (optional but supported)**
     - If the repo has tool/resource registration functions:
       - Update signatures to accept `serverIcon?: string` (and/or `iconMeta?: { src; mimeType; sizes }` if that’s cleaner, but must remain low-risk and minimal).
       - Apply the same conditional spread pattern in tool/resource metadata objects.
       - Pass `localIcon` from server creation:
         - `registerTools(server, localIcon)`
         - `registerResources(server, localIcon)`
     - If no such functions exist, skip this section without inventing files/functions.

3. **Output (patch-style answer only; concise, paste-ready)**
   - Provide exactly the following sections, in order:
   1. **Files to modify** (list)
   2. **Exact code snippets** to paste
      - Server entry file: include `getLocalIconData()` + `McpServer` creation changes
      - Tool/resource registration changes only if applicable
      - `scripts/copy-assets.mjs` contents if you add it
   3. **Exact `package.json` scripts** section (show the scripts you changed/added; keep minimal diffs)
   4. **Verification commands**
      - Always include:
        - `npm run build`
      - Conditionally include (only if present in the repo):
        - `npm run type-check`
        - `npm run lint`
        - `npm test`
      - Manual check:
        - Run server and confirm icon appears in “MCP Inspector” (or equivalent client).
   5. **Troubleshooting checklist**
      - Missing assets after build (dist path, postbuild not running, wrong script name)
      - TypeScript `icons` typing error (SDK types/version mismatch, metadata shape, conditional spread)
      - Icon not appearing (data URI correctness, mimeType, client caching, wrong asset path resolution)

## Constraints & Standards

- **Output:** Patch-style Markdown with the 5 required sections above; paste-ready snippets.
- **Compatibility:** TypeScript 5.0+, Node.js 20+, ESM-friendly path resolution (`import.meta.url`, `new URL(...)`).
- **SDK/Protocol:** `@modelcontextprotocol/sdk@1.0.0+`, MCP Protocol 2025-11-25 `icons` metadata.
- **Safety:** No destructive operations; avoid wide refactors; smallest diff that satisfies requirements.
- **Robustness:** If the asset is missing/unreadable, server must still start and emit no `icons` fields anywhere.
- **Error Handling:** Icon read/copy must not throw uncaught errors; wrap in `try/catch`.
- **Anti-Hallucination:** Do not invent file paths, entrypoints, or scripts. If something isn’t found, state “N/A” and skip rather than guessing.
