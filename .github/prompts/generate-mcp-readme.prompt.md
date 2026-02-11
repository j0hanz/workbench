# MCP Server README Generator (Evidence-First)

## Context

**Role:** Senior Open Source Software Engineer + Technical Writer (MCP ecosystem)  
**Objective:** Inspect the entire repository/workspace and produce a **comprehensive, appealing, and concise** `README.md` for the MCP server **using only verified repo evidence** (no guessing).

You must follow an evidence-first workflow and produce a README inspired (structure/tone/content) by these examples:

- https://raw.githubusercontent.com/Azure-Samples/serverless-chat-langchainjs/refs/heads/main/README.md
- https://raw.githubusercontent.com/Azure-Samples/serverless-recipes-javascript/refs/heads/main/README.md
- https://raw.githubusercontent.com/sinedied/run-on-output/refs/heads/main/README.md
- https://raw.githubusercontent.com/sinedied/smoke/refs/heads/main/README.md

## Instructions (System — Execute in phases: 1) Extraction 2) Processing 3) Output)

### Phase 1 — Extraction (Repo discovery; MANDATORY; evidence-first)

Use the repository filesystem tools exactly as follows:

1. **Discover repo roots**

- Call `filesystem-mcp/roots`.

2. **List repo root contents**

- Call `filesystem-mcp/ls` at the repo root.

3. **Read high-signal files in batches**

- Prefer `filesystem-mcp/read_many` for 2+ files at once.
- Prioritize (only if present):
  - `package.json`
  - existing `README.md`
  - entrypoints: `src/index.ts`, `src/server.ts`, `main.go`, etc.
  - config/docs: `CONFIGURATION.md`, `.env.example`, `tsconfig.json`, `pyproject.toml`, `go.mod`, etc.
  - MCP-related configs for clients (Claude Desktop, VS Code, Cursor, Windsurf) if present
  - CI/workflows (e.g., `.github/workflows/*`) if present

4. **Tool discovery / code scanning**

- Use `filesystem-mcp/find` to locate relevant sources (e.g., `src/**/*.ts`, `src/**/*.js`, `*.go`, etc.).
- Use `filesystem-mcp/grep` for MCP registration patterns and SDK equivalents:
  - `registerTool`, `registerTools`
  - `registerResource`, `registerResources`
  - `registerPrompt`, `registerPrompts`
  - plus any SDK-specific constructs you discover (search for imports and framework usage).

5. **Extract and record a structured “fact table” (with evidence pointers)**
   For each item below, extract **file path + minimal snippet** (or strongly pinpointed reference) sufficient to support README claims:

- **Project identity**
  - Name (prefer `package.json.name` or README title)
  - Description/tagline (from README/package/headers)
  - Logo/icon presence (search for `logo.*`, `icon.*`, `assets/`, `docs/`, `.png/.svg/.ico`)

- **Transports**
  - stdio vs HTTP/SSE/Streamable HTTP
  - ports/paths
  - session behavior, if any

- **CLI/entrypoints**
  - `bin` in `package.json`
  - executable name(s)
  - flags/args (and defaults if documented)

- **Configuration surface**
  - env vars (names, defaults, validation, constraints)
  - config files (if any)
  - runtime modes

- **MCP surface**
  - **Tools:** name, description, params (types/required/defaults/limits), return shapes, errors
  - **Resources:** URI patterns, MIME types, content behavior
  - **Prompts:** name, args, purpose
  - **Tasks/async:** existence + retrieval/polling mechanics (only if evidenced)

- **Security controls (only if implemented)**
  - stdout pollution precautions (stdio)
  - auth, origin checks, DNS rebinding mitigations (HTTP)
  - SSRF/path traversal mitigations
  - input validation patterns

- **Dev workflow**
  - scripts from `package.json` (build/test/lint/format/dev)
  - release workflow if present (CI configs, publish scripts)
  - runtime/version requirements ONLY if explicitly stated

### Phase 2 — Processing (Strict anti-hallucination)

1. Build a **fact table** for everything you intend to mention in the README:

- Each claim must map to a repo location (path + excerpt/anchor).
- If something is not evidenced, do one of:
  - Omit the section entirely, OR
  - Include a short **“Missing info”** note inside that section.

2. Do **not** invent any of:

- tool names, parameters, return shapes
- endpoints/ports/paths
- flags/arguments
- env vars/defaults
- runtime versions
- MCP SDK/library names

3. Examples must be derived from schemas/types/code:

- Mirror real parameter names/types.
- If you can’t prove a field exists, don’t show it.

4. Use `thinkseq.thinkseq` ONLY if:

- there are **5+ tools**, OR
- tools are interdependent/complex, OR
- repo sources conflict.
  Otherwise, proceed without it.

### Phase 3 — Output (Generate README.md only)

Produce the complete `README.md` in **GitHub Flavored Markdown** with **GitHub admonition syntax** where useful.

**Hard rules**

- Keep it concise and to the point.
- Do not overuse emojis.
- Do **not** include sections like: `LICENSE`, `CONTRIBUTING`, `CHANGELOG`, etc. (dedicated files exist).
- Include a logo/icon in the header if found (use a relative path).

#### README Sections (include ONLY if supported by repo evidence)

1. **Header**

- `# {Project Name}` (evidence-based)
- Badges (ONLY if verifiable): npm version (if published), license badge, runtime/TS/MCP SDK indicators
- **One-Click Install buttons** (ONLY when a CLI/NPX entrypoint exists and is evidenced)
  - VS Code + VS Code Insiders (npx)
  - Claude Desktop (only if stdio is supported)
  - Cursor deeplink (base64 config)
- One-line description grounded in repo docs/code.

2. **Overview**

- Short paragraph explaining what the server does (evidence-based).

3. **Key Features**

- 4–8 bullets tied to specific tools/transports/capabilities found.

4. **Tech Stack**

- Runtime, language, MCP SDK, core libraries, package manager (all evidence-based).

5. **Architecture**

- Short numbered pipeline ONLY if documented or clearly shown by code structure; else add “Missing info”.

6. **Repository Structure**

- Top-level tree + key folders (concise).

7. **Requirements**

- Runtime requirements (versions ONLY if explicitly stated).

8. **Quickstart**

- Minimal run command (often `npx` or binary) + one working client config JSON (prefer stdio if supported).
- Must be runnable using repo-evidenced args/env.

9. **Installation**

- NPX (recommended) if supported
- Global install if supported
- From source: clone/build/run steps tied to scripts and docs

10. **Configuration**

- Runtime modes table (flags/descriptions) if applicable
- CLI arguments table (only verified)
- Environment variables table(s) (only verified)
- Defaults/limits ONLY if present in code/docs

11. **Usage**

- Short examples for each supported transport (stdio/HTTP) if evidenced.

12. **MCP Surface**

- **Tools:** one subsection per tool:
  - purpose
  - parameters table: name | type | required | default | description
  - returns description + example JSON derived from code
- **Resources:** URI patterns table (if any)
- **Prompts:** names + args (if any)
- **Tasks:** async tasks support + how to call/retrieve (only if evidenced)

13. **HTTP Mode Endpoints** (ONLY if HTTP supported)

- Table: method | path | auth | notes
- headers/session behavior only if evidenced.

14. **Client Configuration Examples**

- Use `<details>` blocks ONLY for supported/verified clients:
  - VS Code
  - Claude Desktop
  - Cursor
  - Windsurf
- Omit any client you can’t support with evidence.

15. **Security** (ONLY if evidenced)

- stdout pollution warning for stdio
- origin validation / DNS rebinding mitigation for HTTP
- filesystem/path traversal constraints
- auth/token handling if implemented

16. **Development Workflow**

- install dependencies
- scripts table from `package.json`: script name → command → purpose

17. **Build and Release** (ONLY if evidenced)

- build steps and publish workflow summary grounded in repo files/CI configs

18. **Troubleshooting**

- Include only issues evidenced by code/docs or common to the detected transport:
  - inspector usage
  - common config mistakes
  - stdout/stderr guidance for stdio

19. **Contributing & License**

- Link to `CONTRIBUTING.md` if present
- State license (from repo)

#### One-Click Install details (generate precisely from evidence)

- `{package-name}` MUST come from `package.json.name`.
- `{mcp-server-name}` should be a short display name from repo (README/title) else safely derived from `{package-name}`.
- Cursor deeplink base64 JSON MUST be exactly one of:

Default:

```json
{ "command": "npx", "args": ["-y", "{package-name}@latest"] }
```

If a workspace folder argument is required (ONLY if evidenced):

```json
{
  "command": "npx",
  "args": ["-y", "{package-name}@latest", "${workspaceFolder}"]
}
```

If a stdio flag or mode flag is required, include it in `args` ONLY if evidenced by code/docs.

## Constraints & Standards

- **Output:** Return ONLY the complete `README.md` content in Markdown (no commentary, no analysis).
- **Style:** Production MCP README tone; concise and practical; prefer tables and short bullet lists; use `<details>` blocks for configs.
- **Anti-Hallucination:** Every non-trivial statement must be backed by repo evidence. If missing/uncertain, omit or mark **“Missing info”**. Never invent tools, endpoints, ports, flags, env vars, SDKs, or versions.
