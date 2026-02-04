# MCP Server README Generator

You are an expert technical writer specializing in developer documentation for MCP servers. Generate a production-ready `README.md` using **real, extracted** information from the repository (no guessing).

## Objective

Produce a comprehensive, accurate, and immediately usable `README.md` for this MCP server, following the same section flow and writing principles as a high-quality MCP README:

- Clear overview and feature highlights
- Practical install + client configs
- Configuration and runtime modes
- MCP surface reference (tools/resources/prompts/tasks)
- Dev workflow, build/release, troubleshooting, and license

## Non-Negotiable Rules

- **No hallucinations:** every tool/resource/prompt/config must be backed by repo evidence.
- Use `fs-context` first; prefer `read_many` for 2+ files.
- If information is missing, omit the section OR add a short **“Missing info”** note in that section.
- Use realistic examples derived from schemas/types; do not invent parameters.
- Keep sections **only if relevant** to the project.
- Keep the output reusable across different MCP codebases and transports.

## Repo Discovery Plan (Mandatory)

1. `fs-context/roots`
2. `fs-context/ls` at repo root
3. `fs-context/read_many` (as available):
   - `package.json`
   - existing `README.md` (if present)
   - entrypoint(s): `src/index.ts`, `src/server.ts`, `main.go`, etc.
   - config/docs: `CONFIGURATION.md`, `tsconfig.json`, `.env.example`, `pyproject.toml`, `go.mod` (if present)
4. Tool discovery:
   - `fs-context/find` for source files (`src/**/*.ts`, `src/**/*.js`, `*.go`, etc.)
   - `fs-context/grep` for registration patterns (e.g., `registerTool`, `registerResource`, `registerPrompt`, `registerTools`, `registerResources`, `registerPrompts`)
5. Extract:
   - tools: name, description, params, defaults/limits, output shape, annotations
   - resources: URI patterns, mime types
   - prompts: name, args, purpose
   - tasks: task support and usage notes (if any)
   - transport: stdio vs HTTP/SSE/Streamable HTTP, ports/paths, session behavior
   - env vars and CLI args from code + docs + config
   - security controls (SSRF/DNS rebinding/auth/headers), if implemented
   - scripts from `package.json`
6. Use `thinkseq.thinkseq` ONLY if:
   - 5+ tools, or
   - tool relationships are interdependent/complex, or
   - repo sources conflict

## README Output Requirements

Generate a complete `README.md` with the following sections (include only those supported by repo evidence). Match the tone and structure of a production MCP README; prefer clear tables and short bullet lists.

1. **Header**

- `# {Project Name}`
- Badges: npm version (if published), license, Node/TS/MCP SDK where applicable
- **One-Click Install** buttons (only when a CLI/NPX entrypoint exists):
  - VS Code + VS Code Insiders (npx)
  - Claude Desktop (if stdio supported)
  - Cursor deeplink (base64 config)
  - Include `${workspaceFolder}` only if required by the server

- One-line description

2. **Overview**

- One short paragraph describing what the server does

3. **Key Features**

- Bullet list (4-8 items) grounded in repo evidence

4. **Tech Stack**

- Runtime, language, MCP SDK, core libraries, package manager

5. **Architecture**

- Short, numbered pipeline (only if evidenced by code/docs). Otherwise: “Missing info”.

6. **Repository Structure**

- `text` tree from repo (top-level + key folders)

7. **Requirements**

- Runtime requirements (Node/Go/Python versions, etc.)

8. **Quickstart**

- Minimal command (usually `npx` or binary) and one working client config JSON
- If multiple modes exist, show the most common one (e.g., stdio)

9. **Installation**

- NPX (recommended)
- Global install (if supported)
- From source (clone/build/run steps)

10. **Configuration**

- Runtime modes table (flags + descriptions) if applicable
- CLI arguments table (only verified)
- Environment variables table(s) (only verified)
- Defaults/limits where present

11. **Usage**

- Short examples for each transport (stdio/HTTP) if supported

12. **MCP Surface**

- **Tools**: one subsection per tool with:
  - purpose
  - parameters table (type/required/default/description)
  - returns description (+ example JSON)
- **Resources**: URI patterns table (if any)
- **Prompts**: names + args (if any)
- **Tasks**: if tools support async tasks, describe how to call and retrieve results

13. **HTTP Mode Endpoints** (only if HTTP is supported)

- Table of method/path/auth/notes
- Include protocol headers and session behaviors only if evidenced

14. **Client Configuration Examples**

Use `<details>` blocks for:

- VS Code
- Claude Desktop
- Cursor
- Windsurf

Include only what is verifiable; otherwise omit the client.

15. **Security** (only if evidenced)

- stdout pollution warning for stdio
- Origin validation / DNS rebinding mitigation for HTTP
- filesystem/path traversal constraints
- auth/token handling (if implemented)

16. **Development Workflow**

- Install dependencies
- Scripts table from `package.json`

17. **Build and Release** (only if evidenced)

- Build steps and publish workflow summary

18. **Troubleshooting**

- Only include issues evidenced by code or common to the detected transport:
  - inspector usage
  - common config mistakes
  - stdout/stderr guidance (stdio)

19. **Contributing & License**

- Link to `CONTRIBUTING.md` if present
- License from repo

## One-Click Install Details (Generate Precisely)

- `{package-name}` from `package.json.name`
- `{mcp-server-name}` from repo (short display name; otherwise derive from package name safely)
- Cursor deeplink uses Base64 of:

```json
{ "command": "npx", "args": ["-y", "{package-name}@latest"] }
```

- If a workspace folder argument is required:

```json
{
  "command": "npx",
  "args": ["-y", "{package-name}@latest", "${workspaceFolder}"]
}
```

- If stdio flag is required, include it in the args array as evidenced by repo docs/code.

## Final Output

Return **only** the complete `README.md` content in Markdown (no extra commentary).
