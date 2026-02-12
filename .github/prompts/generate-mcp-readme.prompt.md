# MCP Server README Generator (Evidence-First)

## Context

**Role:** Senior Open Source Software Engineer + Technical Writer (MCP ecosystem)
**Objective:** Inspect the entire repository/workspace and produce a **comprehensive, appealing, and concise** `README.md` for the MCP server **using only verified repo evidence** (no guessing).

---

## Instructions (System — Execute in phases: 1) Extraction 2) Processing 3) Output)

### Phase 1 — Extraction (Repo Discovery; MANDATORY; Evidence-First)

Use the repository filesystem tools exactly as follows:

#### 1. Discover repo roots

- Call `filesystem-mcp/roots`.

#### 2. List repo root contents

- Call `filesystem-mcp/ls` at the repo root.

#### 3. Read high-signal files in batches

- Prefer `filesystem-mcp/read_many` for 2+ files at once.
- Prioritize (only if present):
  - `package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml` / `*.csproj`
  - existing `README.md`
  - entrypoints: `src/index.ts`, `src/server.ts`, `main.go`, `src/main.rs`, `Program.cs`, etc.
  - config/docs: `CONFIGURATION.md`, `.env.example`, `tsconfig.json`, etc.
  - MCP-related client configs for Claude Desktop, VS Code, Cursor, Windsurf, etc.
  - CI/workflows: `.github/workflows/*`
  - Docker: `Dockerfile`, `docker-compose.yml`
  - Smithery config: `smithery.yaml`, `smithery.json`

#### 4. Tool discovery / code scanning

- Use `filesystem-mcp/find` to locate relevant sources (e.g., `src/**/*.ts`, `src/**/*.js`, `*.go`, `*.rs`, `*.cs`).
- Use `filesystem-mcp/grep` for MCP registration patterns and SDK equivalents:
  - TypeScript: `registerTool`, `registerTools`, `registerResource`, `registerResources`, `registerPrompt`, `registerPrompts`, `McpServer`, `server.tool(`, `server.resource(`
  - Python: `@mcp.tool`, `@server.tool`, `Tool(`, `server.add_tool`
  - .NET: `[McpServerTool]`, `[McpServerToolType]`
  - Go: `server.AddTool`, `mcp.NewTool`
  - Plus any SDK-specific constructs you discover (search for imports and framework usage).

#### 5. Extract and record a structured "fact table" (with evidence pointers)

For each item below, extract **file path + minimal snippet** (or strongly pinpointed reference) sufficient to support README claims:

- **Project identity**
  - Name (prefer `package.json` `name` field, or README title)
  - Description/tagline (from README/package/headers)
  - Logo/icon/cover/banner presence (search for `logo.*`, `icon.*`, `cover.*`, `banner.*`, `hero.*`, `assets/`, `docs/`, `public/`, `.png/.svg/.ico/.jpg`)
  - MCP name meta tag: search for `<!-- mcp-name:` in existing README

- **Transports**
  - stdio vs HTTP/SSE/Streamable HTTP
  - Ports/paths (e.g., `/mcp`, port `3000`)
  - Session behavior (stateful/stateless), if any

- **CLI/entrypoints**
  - `bin` in `package.json`
  - Executable name(s) and invocation patterns
  - Flags/args (and defaults if documented)
  - Docker image name (if Dockerfile present)

- **Configuration surface**
  - Env vars (names, defaults, validation, constraints)
  - Config files (JSON schemas, `.env.example`)
  - Runtime modes (stdio/sse/streamableHttp flags)

- **MCP surface**
  - **Tools:** name, description, params (types/required/defaults/limits), return shapes, errors
  - **Resources:** URI patterns, MIME types, content behavior
  - **Prompts:** name, args, purpose
  - **Tasks/async:** existence + retrieval/polling mechanics (only if evidenced)

- **Security controls (only if implemented)**
  - stdout pollution precautions (stdio)
  - Auth, origin checks, DNS rebinding mitigations (HTTP)
  - SSRF/path traversal mitigations
  - Input validation patterns

- **Dev workflow**
  - Scripts from `package.json` or equivalent (build/test/lint/format/dev)
  - Release workflow if present (CI configs, publish scripts)
  - Runtime/version requirements ONLY if explicitly stated

- **Distribution**
  - npm/PyPI/NuGet/crates.io package name (if published)
  - Docker image (if Dockerfile present)
  - Smithery listing (if `smithery.yaml` exists)
  - MCP Registry presence

---

### Phase 2 — Processing (Strict Anti-Hallucination)

1. Build a **fact table** for everything you intend to mention in the README:
   - Each claim must map to a repo location (path + excerpt/anchor).
   - If something is not evidenced, do one of:
     - Omit the section entirely, OR
     - Include a short note: `> [!NOTE]`/`> [!WARNING]` indicating missing info.

2. Do **not** invent any of:
   - Tool names, parameters, return shapes
   - Endpoints/ports/paths
   - Flags/arguments
   - Env vars/defaults
   - Runtime versions
   - MCP SDK/library names

3. Examples must be derived from schemas/types/code:
   - Mirror real parameter names/types.
   - If you can't prove a field exists, don't show it.

4. Use `thinkseq.thinkseq` ONLY if:
   - There are **5+ tools**, OR
   - Tools are interdependent/complex, OR
   - Repo sources conflict.
     Otherwise, proceed without it.

---

### Phase 3 — Output (Generate README.md Only)

Produce the complete `README.md` in **GitHub Flavored Markdown**.

#### Hard Rules

- Keep it concise and to the point.
- Do not overuse emojis.
- Do **not** include full `LICENSE`, `CONTRIBUTING`, or `CHANGELOG` content (dedicated files exist).
- Include a logo/icon/cover image in the header if found (use relative path).
- Use **GitHub alert/admonition syntax** where appropriate (see [Markdown Reference](#markdown-reference) below).
- Use `<details>` blocks for client configurations and lengthy content.
- Include the `<!-- mcp-name: ... -->` meta tag if a canonical MCP name can be derived.

---

## README Sections (Include ONLY If Supported by Repo Evidence)

### 1. Header

- Cover/banner image (if found, centered with `<p align="center">`)
- `# {Project Name}` (evidence-based)
- `<!-- mcp-name: {reverse-dns-style-name} -->` meta tag (derived from package name or repo)
- **Badges** (ONLY if verifiable):
  - npm/PyPI/NuGet version (if published)
  - License badge
  - Smithery badge (if listed): `[![smithery badge](https://smithery.ai/badge/@org/pkg)](https://smithery.ai/server/@org/pkg)`
  - Runtime/SDK indicators
  - CI status badge (if GitHub Actions workflow exists)
- **One-Click Install Buttons** — place immediately after badges (see [One-Click Install Reference](#one-click-install-reference) below)
- One-line description grounded in repo docs/code.

### 2. Overview

- Short paragraph explaining what the server does (evidence-based).
- Optionally use problem/solution framing (e.g., "Without X" vs "With X") if the repo README already uses this pattern.

### 3. Key Features

- 4–8 bullets tied to specific tools/transports/capabilities found.

### 4. Requirements

- Runtime requirements (versions ONLY if explicitly stated in repo).
- Required external dependencies (e.g., `uv`, Docker, browser, API keys).
- Supported MCP clients.

### 5. Quick Start

- Show a **"Standard config"** JSON block that works in most MCP clients:

```json
{
  "mcpServers": {
    "{server-name}": {
      "command": "npx",
      "args": ["-y", "{package-name}@latest"]
    }
  }
}
```

- Immediately followed by one-click install badges (if not already in Header).
- Must be runnable using repo-evidenced args/env.

> [!TIP]
> Use the Playwright MCP pattern: show ONE universal config first, then per-client `<details>` blocks.

### 6. Client Configuration

Use `<details>` blocks for **each supported client**. Include ONLY clients whose config format can be verified or reasonably derived from the transport type.

**Client priority order** (include all that apply):

| Tier                          | Clients                                                                                                                      | Badge Support           |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| **Tier 1** (one-click badges) | VS Code, VS Code Insiders, Cursor                                                                                            | Shields.io / SVG badges |
| **Tier 2** (one-click badges) | Visual Studio, Goose, LM Studio                                                                                              | Official SVG badges     |
| **Tier 3** (`<details>` only) | Claude Desktop, Claude Code, Windsurf, Amp, Cline, Codex, Copilot, Warp, Kiro, Gemini CLI, Zed, Augment, Roo Code, Kilo Code | Config JSON only        |

For each client, show:

```markdown
<details>
<summary><b>Install in {Client Name}</b></summary>

{One-click badge if Tier 1/2}

{Config JSON block}

{CLI command if applicable}

For more info, see [{Client} MCP docs]({docs-url}).

</details>
```

**Config format per client** (use evidence; fall back to these standard patterns):

- **Claude Desktop:** `claude_desktop_config.json` → `{ "mcpServers": { ... } }`
- **VS Code:** `.vscode/mcp.json` or user config → `{ "servers": { ... } }` (use `"mcp": { "servers": { ... } }` in `settings.json`)
- **Cursor:** `~/.cursor/mcp.json` → `{ "mcpServers": { ... } }`
- **Windsurf:** MCP config → `{ "mcpServers": { ... } }` (use `"serverUrl"` for remote HTTP)
- **Cline:** `cline_mcp_settings.json` → `{ "mcpServers": { ... } }`
- **Zed:** `settings.json` → `{ "context_servers": { ... } }`
- **Augment:** `settings.json` → `"augment.advanced": { "mcpServers": [...] }`

**CLI install commands** (where applicable):

- VS Code: `code --add-mcp '{"name":"...","command":"npx","args":["-y","..."]}'`
- VS Code Insiders: `code-insiders --add-mcp '...'`
- Claude Code: `claude mcp add {name} -- npx -y {package}`
- Amp: `amp mcp add {name} -- npx {package}`

### 7. MCP Surface

- **Tools:** one subsection per tool:
  - Purpose (single sentence)
  - Parameters table: `Name | Type | Required | Default | Description`
  - Returns description + example JSON derived from code
- **Resources:** URI patterns table (if any)
- **Prompts:** names + args (if any)
- **Tasks:** async tasks support + how to call/retrieve (only if evidenced)

### 8. Configuration

- Runtime modes table (flags/descriptions) if applicable.
- CLI arguments table (only verified): `Option | Description | Env Var`
- Environment variables table(s) (only verified): `Variable | Description | Default | Required`
- Config file format/schema (in `<details>` block if lengthy).

### 9. HTTP Mode Endpoints (ONLY if HTTP supported)

- Table: `Method | Path | Auth | Notes`
- Headers/session behavior only if evidenced.

### 10. Security (ONLY if evidenced)

- stdout pollution warning for stdio.
- Origin validation / DNS rebinding mitigation for HTTP.
- Filesystem/path traversal constraints.
- Auth/token handling if implemented.

### 11. Development

- Install dependencies: command from repo.
- Scripts table from `package.json` (or equivalent): `Script | Command | Purpose`
- Debugging with MCP Inspector:

```bash
# stdio
npx @modelcontextprotocol/inspector {command} {args}

# HTTP
npx @modelcontextprotocol/inspector {url}
```

### 12. Build & Release (ONLY if evidenced)

- Build steps and publish workflow summary grounded in repo files/CI configs.
- Docker build command (if Dockerfile exists).

### 13. Troubleshooting

- Include only issues evidenced by code/docs or common to the detected transport:
  - Inspector usage
  - Common config mistakes per client
  - stdout/stderr guidance for stdio
  - Log file locations (e.g., `~/Library/Logs/Claude/mcp*.log`)

### 14. Contributing & License

- Link to `CONTRIBUTING.md` if present.
- State license (from repo).

---

## One-Click Install Reference

Generate install buttons **precisely from evidence**. Use these patterns:

### Badge URL Patterns

#### VS Code (stable)

```
https://insiders.vscode.dev/redirect/mcp/install?name={NAME}&config={URL_ENCODED_JSON}
```

Badge markdown:

```markdown
[![Install in VS Code](https://img.shields.io/badge/VS_Code-Install_Server-0098FF?style=flat-square&logo=visualstudiocode&logoColor=white)](URL)
```

#### VS Code Insiders

Same URL as VS Code + append `&quality=insiders`.

Badge markdown:

```markdown
[![Install in VS Code Insiders](https://img.shields.io/badge/VS_Code_Insiders-Install_Server-24bfa5?style=flat-square&logo=visualstudiocode&logoColor=white)](URL)
```

#### Visual Studio

```
https://vs-open.link/mcp-install?{URL_ENCODED_JSON_WITH_NAME}
```

Badge markdown:

```markdown
[![Install in Visual Studio](https://img.shields.io/badge/Visual_Studio-Install_Server-C16FDE?logo=visualstudio&logoColor=white)](URL)
```

#### Cursor

Deeplink URL:

```
cursor://anysphere.cursor-deeplink/mcp/install?name={NAME}&config={BASE64_JSON}
```

Or web URL:

```
https://cursor.com/en/install-mcp?name={NAME}&config={BASE64_JSON}
```

Badge markdown:

```markdown
[![Install in Cursor](https://cursor.com/deeplink/mcp-install-dark.svg)](URL)
```

#### Goose

```
https://block.github.io/goose/extension?cmd={CMD}&arg={URL_ENCODED_ARGS}&id={ID}&name={NAME}&description={DESC}
```

Badge markdown:

```markdown
[![Install in Goose](https://block.github.io/goose/img/extension-install-dark.svg)](URL)
```

#### LM Studio

```
https://lmstudio.ai/install-mcp?name={NAME}&config={BASE64_JSON}
```

Badge markdown:

```markdown
[![Add to LM Studio](https://files.lmstudio.ai/deeplink/mcp-install-light.svg)](URL)
```

### Config JSON for URL Encoding

**For NPX packages (stdio):**

```json
{ "command": "npx", "args": ["-y", "{package-name}@latest"] }
```

**For NPX with workspace folder** (ONLY if evidenced):

```json
{
  "command": "npx",
  "args": ["-y", "{package-name}@latest", "${workspaceFolder}"]
}
```

**For remote HTTP servers:**

```json
{ "type": "http", "url": "{server-url}" }
```

**For Docker containers:**

```json
{ "command": "docker", "args": ["run", "-i", "--rm", "{image-name}"] }
```

### URL Encoding Reference

| Character | Encoded |
| --------- | ------- |
| `{`       | `%7B`   |
| `}`       | `%7D`   |
| `"`       | `%22`   |
| `:`       | `%3A`   |
| `/`       | `%2F`   |
| `[`       | `%5B`   |
| `]`       | `%5D`   |
| `,`       | `%2C`   |
| `@`       | `%40`   |

### Naming Rules

- `{package-name}` MUST come from the package manifest (e.g., `package.json` `name` field).
- `{NAME}` for display should be a short, human-friendly name derived from the repo (README title or package name without scope).
- `{BASE64_JSON}` must be standard Base64 encoding of the config JSON (no padding removal).

---

## Markdown Reference

### GitHub Alert / Admonition Syntax

Use these for important callouts (rendered with color and icons on GitHub):

```markdown
> [!NOTE]
> Informational highlight — useful supplementary information.

> [!TIP]
> Helpful advice for the reader.

> [!IMPORTANT]
> Critical information the reader must know.

> [!WARNING]
> Potential issues or pitfalls to be aware of.

> [!CAUTION]
> Negative consequences of an action — use sparingly.
```

### Collapsible Sections

Use `<details>` blocks to keep the README scannable:

```markdown
<details>
<summary><b>Section Title</b></summary>

Content here (leave a blank line after `<summary>` closing tag).

</details>
```

### Badge Patterns (shields.io)

```markdown
[![Label](https://img.shields.io/badge/LABEL-MESSAGE-COLOR?style=flat-square&logo=LOGO&logoColor=white)](URL)
```

Common badge colors:

| Purpose          | Color    | Logo               |
| ---------------- | -------- | ------------------ |
| VS Code          | `0098FF` | `visualstudiocode` |
| VS Code Insiders | `24bfa5` | `visualstudiocode` |
| Visual Studio    | `C16FDE` | `visualstudio`     |
| npm              | `CB3837` | `npm`              |
| License (MIT)    | `blue`   | —                  |
| TypeScript       | `3178C6` | `typescript`       |
| Node.js          | `339933` | `nodedotjs`        |
| Python           | `3776AB` | `python`           |
| .NET             | `512BD4` | `dotnet`           |
| Docker           | `2496ED` | `docker`           |

### Code Block Language Tags

Use specific language tags for syntax highlighting:

- `json` — config files, tool schemas
- `bash` / `sh` — shell commands
- `typescript` / `ts` — TypeScript code
- `python` — Python code
- `csharp` — C# code
- `go` — Go code
- `toml` — TOML configs

---

## Constraints & Standards

- **Output:** Return ONLY the complete `README.md` content in Markdown (no commentary, no analysis).
- **Style:** Production MCP README tone; concise and practical; prefer tables and short bullet lists; use `<details>` blocks for client configs and lengthy content.
- **Anti-Hallucination:** Every non-trivial statement must be backed by repo evidence. If missing/uncertain, omit or use a `> [!NOTE]` admonition with "Missing info". Never invent tools, endpoints, ports, flags, env vars, SDKs, or versions.
- **Markdown Quality:**
  - Use ATX-style headers (`#`, `##`, `###`).
  - Use fenced code blocks with language tags — never indented code blocks.
  - One blank line before and after headers, code blocks, lists, and admonitions.
  - Tables must have aligned separators.
  - Links should use descriptive text, not raw URLs.
  - No trailing whitespace.
