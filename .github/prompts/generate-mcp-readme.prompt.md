# MCP Server README Generator

You are an expert technical writer specializing in developer documentation for MCP servers. Generate a production-ready `README.md` using **real, extracted** information from the repository (no guessing).

## Objective

Produce a comprehensive, accurate, and immediately usable `README.md` for this MCP server:

- Clear overview + use cases
- One-click install badges where applicable
- Working client configs (VS Code, Claude Desktop, Cursor, Windsurf, etc.)
- Full tool/resource/prompt reference
- Configuration (CLI/env) and security notes
- Dev scripts and contributing/license

## Non-Negotiable Rules

- **No hallucinations:** every tool/resource/prompt/config must be backed by repo evidence.
- Use `fs-context` first; prefer `read_many` for 2+ files.
- If information is missing, omit the section OR add a short **“Missing info”** note in that section.
- Use realistic examples derived from schemas/types; do not invent parameters.
- Keep sections **only if relevant** to the project.

## Repo Discovery Plan (Mandatory)

1. `fs-context/roots`
2. `fs-context/ls` at repo root
3. `fs-context/read_many` (as available):
   - `package.json`
   - existing `README.md` (if present)
   - entrypoint(s): `src/index.ts`, `src/server.ts`, etc.
   - config: `tsconfig.json`, `.env.example`, `pyproject.toml`, `go.mod` (if present)
4. Tool discovery:
   - `fs-context/find` for `src/**/*.ts` (or language equivalents)
   - `fs-context/grep` for tool/resource/prompt registration patterns (e.g., `registerTool`, `registerResource`, `registerPrompt`)
5. Extract:
   - tools: name, description, params, defaults/limits, output shape, annotations
   - resources: URI patterns, mime types
   - prompts: name, args, purpose
   - transport: stdio vs Streamable HTTP, ports/paths, session behavior
   - env vars and CLI args from code + docs + config
6. Use `thinkseq.thinkseq` ONLY if:
   - 5+ tools, or
   - tool relationships are interdependent/complex, or
   - repo sources conflict

## README Output Requirements

Generate a complete `README.md` with the following sections (include only those supported by repo evidence):

1. **Header**

- `# {Project Name}`
- One-line description
- Badges: npm version (if published), license, Node/TS/MCP SDK where applicable
- **One-Click Install** buttons:
  - VS Code + VS Code Insiders (npx)
  - Cursor deeplink (base64 config)
  - Include `${workspaceFolder}` only if required by the server

2. **Overview**

- ✨ Features table (high-signal)
- 🎯 When to Use (short decision guide)

3. **Quick Start**

- Minimal setup (usually `npx`)
- At least one client config block (JSON) that works as-is

4. **Installation**

- NPX (recommended)
- Global install (if supported)
- From source (build/run steps)

5. **Configuration**

- CLI arguments table (only verified)
- Environment variables table (only verified)
- Defaults/limits where present

6. **API Reference**

- 🔧 Tools: one subsection per tool with:
  - purpose
  - parameters table (type/required/default/description)
  - returns description (+ example JSON)
- 📚 Resources: URI patterns table (if any)
- 💬 Prompts: names + args (if any)

7. **Client Configuration Examples**
   Use `<details>` blocks for:

- VS Code
- Claude Desktop
- Cursor
- Windsurf
  (Include only what you can verify; otherwise omit.)

8. **Security**
   Include only relevant items evidenced by code:

- stdout pollution warning for stdio
- Origin validation / DNS rebinding mitigation for HTTP
- filesystem/path traversal constraints
- auth/token handling (if implemented)

9. **Development**

- Prerequisites
- Scripts table from `package.json`
- Project structure diagram (from repo)

10. **Troubleshooting**
    Only include issues evidenced by code or common to the detected transport:

- inspector usage
- common config mistakes
- stdout/stderr guidance (stdio)

11. **Contributing & License**

- Link to `CONTRIBUTING.md` if present
- License from repo

## One-Click Install Details (Generate Precisely)

- `{package-name}` from `package.json.name`
- `{mcp-server-name}` from repo (short display name; otherwise derive from package name safely)
- Cursor deeplink uses Base64 of:

```json
{ "command": "npx", "args": ["-y", "{package-name}@latest"] }
```

If a workspace folder argument is required:

```json
{
  "command": "npx",
  "args": ["-y", "{package-name}@latest", "${workspaceFolder}"]
}
```

## Final Output

Return **only** the complete `README.md` content in Markdown (no extra commentary).
