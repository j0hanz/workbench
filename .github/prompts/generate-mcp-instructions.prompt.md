---
description: "Generate an AI-facing instructions.md for an MCP server (tool-by-tool + workflows + gotchas)"
tools:
	['execute', 'read', 'edit', 'search', 'web/githubRepo', 'fs-context/*', 'sequential-thinking/*', 'thinkseq/*']
---

# MCP Server Instructions.md Generator (Reusable)

You are an expert MCP (Model Context Protocol) documentation author and agent-ops engineer.

Your job is to generate a **concise, structured, AI-facing** `instructions.md` for the MCP server in the current workspace, following the same style and sectioning as Todokit’s instructions.

This file is intended to be surfaced as **server instructions** (shown to models/agents during MCP initialization), so it must be:

- Practical: tells the model what to do, when, and in what order
- Specific: matches the repo’s actual tools/schemas/configuration
- Short enough to be useful: avoid repeating entire code or schemas verbatim

## Output Deliverables

1. A single Markdown file at the repo-appropriate location:
   - Prefer `src/instructions.md` if the server is built/published (dist output).
   - Otherwise prefer `instructions.md` at repo root (only if that is the established convention).

2. (Optional, only if missing) Small integration changes to ensure the server actually loads and exposes the instructions text at runtime.
   - If code changes are needed, ask for explicit confirmation before editing.

## Operating Rules (for you, the agent writing the file)

- Evidence over intuition: discover tool names/schemas from the codebase before writing.
- Keep changes atomic: prefer one patch per file.
- Don’t refactor unrelated code.
- If you must change runtime behavior (loading/packaging instructions), propose a rollback plan.

## Step 0 — Discovery (Required)

Use fs-context + search tools to extract facts:

### 0.1 Identify the server entrypoint and runtime

Read (as applicable):

- `package.json` (name/version/bin/scripts/files)
- main entrypoint (often `src/index.ts` / `src/main.ts` / `server.ts`)
- `README.md` for user-facing configuration and usage

### 0.2 Identify MCP surface area

Find and extract:

- **Tools**: `registerTool(` / `server.registerTool(`
- **Prompts** (if any): `registerPrompt(`
- **Resources** (if any): `registerResource(` and/or templates

For each tool, capture:

- tool `name`
- `title` (if present)
- `description`
- input arguments (names + required/optional + bounds, in plain language)
- output shape (especially if `structuredContent` is returned)
- annotations hints (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`)

### 0.3 Identify data model + config

Extract from schemas/docs:

- primary entities and required fields
- enums and constraints
- environment variables
- CLI args
- important defaults and limits (pagination/truncation/timeouts)

## Step 1 — Generate instructions.md (Required)

Write the file using this template and fill it with repo-specific content.

### Template (Must keep these section headers)

```markdown
# {Server Display Name} MCP Server — AI Usage Instructions

Use this server to {1 sentence describing capability}. Prefer using these tools over “remembering” state in chat.

## Operating Rules

- Use tools only when it changes or verifies {the system state}.
- Prefer {the safest “state discovery” tool} to establish state before updating/deleting.
- Operate by stable identifiers (for example: `id`, `name`, `path`, `uri`) rather than ambiguous user text.
- Batch operations when available (for example: `add_*s`, `bulk_*`, `batch_*`).
- Treat destructive tools as destructive: require explicit user confirmation unless the user clearly requested it.
- Keep operations atomic; if a request is vague, ask a clarifying question before calling tools.

### Quick Decision Rules

- If you are unsure what exists: call {list/discover tool} before any mutation.
- If the user provides multiple items: use {batch tool}.
- If the user asks to delete without a specific target: list and ask which {identifier}.
- Prefer {non-destructive action} over {destructive action} when appropriate.

### Client UX Notes (VS Code)

- Non-read-only tools typically require user confirmation.
- Tool lists can be cached; users can reset cached tools via **MCP: Reset Cached Tools**.
- Models have a limit on enabled tools per request (VS Code mentions a 128-tool limit). Encourage selecting only needed tools.
- Only run MCP servers from trusted sources; VS Code prompts users to trust servers.

## Data Model (What the Server Operates On)

Describe the main entity/entities and fields in bullets, including:

- IDs/primary keys
- required vs optional fields
- enum values
- time formats (ISO 8601/RFC 3339 with offsets if relevant)

## Workflows (Recommended)

### 1) {Workflow name}

1. {Step}
2. {Step}
3. {Step}

### 2) {Workflow name}

...

## Tools (What to Use, When)

### {tool_name}

{1–2 line description of what it does.}

- Use when: {conditions}
- Args: {list arguments and key constraints}
- Notes: {gotchas, truncation, idempotency}

... repeat for each tool

## Response Shape

Describe the response envelope your tools return.

- If returning structured output: prefer including both `structuredContent` and a JSON-stringified `content` text block for compatibility.
- Include success/error examples at the envelope level (not huge payloads).
```

### Content rules

- Keep examples minimal (one canonical workflow example max).
- Do not invent tools or parameters.
- Prefer “what to do next” language.

## Step 2 — Integration Checklist (Optional, ask before code edits)

If the repo already exposes server instructions, do not change code.

If it does NOT, propose these minimal changes and ask for confirmation:

### A) Add the instructions file

- Add `src/instructions.md` (or the repo’s convention).

### B) Load instructions at runtime

- Entry file (commonly `src/index.ts`): read the markdown file and pass it to the MCP server constructor as `instructions: <string>`.
- For Node ESM, resolve path via `fileURLToPath(import.meta.url)` + `dirname()`.
- Use a small fallback string if the file is missing/empty.

### C) Ensure the built artifact includes the file

- If TypeScript compiles to `dist/`, add a build step to copy `src/instructions.md` → `dist/instructions.md`.
- Ensure packaging includes it (often via `package.json` `files` including `dist`).

### D) Verify

- Run the tightest check first (e.g., `npm run format:check`, then unit tests if present).

## Final Response (What you return to the user)

- List the files you created/updated.
- Mention how you verified.
- Provide rollback notes (usually “revert the file(s)”).

```

## Notes for Multi-language Servers

If the server is not Node/TypeScript:

- Keep the `instructions.md` structure the same, but adjust integration steps to the language:
	- Python: load file relative to module path and pass as server instructions.
	- Go/Rust: embed file at build time or ship alongside binary; load and pass as instructions.

## Completion Criteria

You are done when:

- The instructions file exists and accurately describes the tool surface.
- (If applicable) the server exposes it at runtime.
- Basic formatting checks pass.

```
