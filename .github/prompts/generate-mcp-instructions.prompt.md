---
description: 'Generate LLM-optimized instructions.md for MCP servers'
---

> **Related Files:**
> [typescript-mcp-server.instructions.md](../instructions/typescript-mcp-server.instructions.md) for SDK rules | [typescript-mcp-server-generator.prompt.md](typescript-mcp-server-generator.prompt.md) for scaffolding | [create-agentsmd.prompt.md](create-agentsmd.prompt.md) for repository-level agent context

# Generate MCP Server Instructions (instructions.md)

You are an expert MCP (Model Context Protocol) instructions author. Generate a comprehensive, LLM-optimized `instructions.md` file for the target MCP server.

**Audience:** LLMs and autonomous agents integrating with the server via MCP protocol.
**Format:** Markdown (.md) — the universal standard for MCP instructions.
**Delivery:** The generated file will be served via three MCP channels:

1. **Server `instructions` field** — injected into every session at initialization
2. **MCP Resource** — `internal://instructions` (on-demand via `resources/read`)
3. **MCP Prompt** — `get-help` (user-invoked slash command)

---

## Step 1 — Discover Server Context (Evidence-First)

Before writing anything, gather facts from file evidence:

### 1a. Identify the Server

- Read `package.json` (or equivalent manifest) for: name, description, version, homepage.
- Read the server entrypoint (`src/index.ts` or `src/server.ts`) for: transport type, capabilities declared.
- Determine the server domain: filesystem, database, API integration, DevOps, AI/ML, etc.

### 1b. Inventory All Tools

- Scan `src/tools/` (one file per tool pattern) or the tool registration file.
- For each tool, extract:
  - **Name** (the MCP tool name string)
  - **Purpose** (from description or code comments)
  - **Input schema** (all parameters with types, defaults, constraints)
  - **Output schema** (structured response shape)
  - **Annotations** (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`)
  - **Side effects** (creates files, modifies state, network calls)
  - **Gotchas** (edge cases, pagination, truncation, resource externalization)

### 1c. Inventory Resources & Prompts

- Check `src/resources.ts` for registered MCP resources (URIs, descriptions).
- Check `src/prompts.ts` for registered MCP prompts (names, arguments).
- Note any resource templates (URI patterns like `server://result/{id}`).

### 1d. Identify Error Codes

- Scan `src/config.ts`, `src/lib/errors.ts`, or equivalent for error code enums/constants.
- Map each error code to its cause and recommended recovery action.

### 1e. Check for Constraints

- Environment variables that affect behavior (timeouts, size limits, feature flags).
- Security boundaries (allowed directories, path validation, symlink protection).
- Rate limits, max result counts, file size limits, binary file handling.

---

## Step 2 — Write the Instructions

Generate the `instructions.md` using the **mandatory template** below. Every section is required unless the server genuinely has nothing for that category.

### Writing Rules (Non-Negotiable)

1. **LLM-first language** — Write for an LLM agent, not a human developer. Use imperative verbs: "Call", "Use", "Check", "Never".
2. **Prescriptive, not descriptive** — Don't say "this tool can search files"; say "Call `grep` to search file contents by regex".
3. **Exact tool names** — Always use backtick-quoted tool names exactly as registered (e.g., `read`, not `Read` or `readFile`).
4. **Golden Path sequences** — Group tools into step-by-step workflows for common tasks. LLMs need prescribed sequences, not capability lists.
5. **Gotchas inline** — Place gotchas/nuances directly under the tool they affect, not in a separate section.
6. **Error → action mapping** — Every error code must have a concrete recovery instruction.
7. **No redundancy with schema** — Don't repeat what's already in `.describe()` on schema fields. Focus on behavior, edge cases, and cross-tool relationships.
8. **Concise** — Target 100–200 lines. Remove filler words. Every line must add value for an LLM.
9. **Evidence-based** — Only document behavior you can verify from source code. Never invent capabilities.

---

## Step 3 — Mandatory Template

```markdown
# {SERVER_TITLE} INSTRUCTIONS

These instructions are available as a resource (internal://instructions) or prompt (get-help). Load them when unsure about tool usage.

---

## CORE CAPABILITY

- Domain: {One sentence describing what this server does and for whom.}
- Primary Resources: {What data types/entities the server operates on.}
- Tools: {Comma-separated list of all tool names, grouped by READ vs WRITE.}

---

## PROMPTS

- `get-help`: Returns these instructions for quick recall.
  {- `other-prompt`: Description of what it does and when to use it.}

---

## RESOURCES & RESOURCE LINKS

- `internal://instructions`: This document.
  {- `server://result/{id}`: Description of cached/dynamic resources.}
- If a tool response includes a `resourceUri` or `resource_link`, call `resources/read` with the URI to fetch the full payload.

---

## PROGRESS & TASKS

{If the server supports MCP Tasks (experimental):}

- Include `_meta.progressToken` in requests to receive `notifications/progress` updates for long-running tools.
- Task-augmented tool calls are supported for {list tools with taskSupport}:
  - Send `tools/call` with `task` to get a task id.
  - Poll `tasks/get` and fetch results via `tasks/result`.
  - Use `tasks/cancel` to abort.
    {If not supported, omit this entire section.}

---

## THE "GOLDEN PATH" WORKFLOWS (CRITICAL)

{Define 2-4 workflows covering the server's primary use cases.
Each workflow is a numbered/bulleted sequence of tool calls.
Include NOTE lines for critical constraints.}

### WORKFLOW A: {PRIMARY_USE_CASE}

- Call `{tool_1}` to {action}.
- Call `{tool_2}` with {key params} to {action}.
- Call `{tool_3}` to {action}.
  NOTE: {Critical constraint, e.g., "Never guess paths. Always list first."}

### WORKFLOW B: {SECONDARY_USE_CASE}

- Call `{tool_1}` to {action}.
- Call `{tool_2}` to {action}.
- If {condition}, use `{tool_3}` instead of `{tool_2}`.

### WORKFLOW C: {MODIFICATION/WRITE_USE_CASE}

{Only if the server has write tools.}

- Call `{tool_1}` to {prepare/verify}.
- Call `{tool_2}` to {apply change}.
  NOTE: Always confirm destructive actions with the user first.

---

## TOOL NUANCES & GOTCHAS

{One subsection per tool. Only include tools that have non-obvious behavior.
Skip tools whose schema `.describe()` is sufficient.}

`{tool_name}`

- Purpose: {One-line summary.}
- Input: {Key params with defaults and constraints not obvious from schema.}
- Output: {Shape highlights, especially pagination, truncation, resource links.}
- Gotcha: {Edge case, e.g., "Large files return `resourceUri`; read it or use pagination."}
- Limits: {Hard limits, e.g., "Returns max 50 inline matches."}

`{another_tool}`

- Purpose: {Summary.}
- Nuance: {Cross-tool relationship, e.g., "Respects `.gitignore` unless `includeIgnored=true`."}

---

## CROSS-FEATURE RELATIONSHIPS

{Document tool interactions that aren't obvious:}

- {e.g., "Use `roots` output to scope `find` and `grep` searches."}
- {e.g., "`gzip-file-as-resource` creates session-scoped resources accessible only during the current session."}

---

## CONSTRAINTS & LIMITATIONS

{Document hard boundaries:}

- {e.g., "Max file read size: 10MB per file."}
- {e.g., "Session resources are ephemeral and lost when the session ends."}
- {e.g., "Binary files are skipped during content search."}

---

## ERROR HANDLING STRATEGY

{Map every error code to a recovery action:}

- `{ERROR_CODE}`: {What went wrong.} → {What to do.}
- `{ERROR_CODE}`: {What went wrong.} → {What to do.}

---
```

---

## Step 4 — Validate & Integrate

After generating the instructions, verify integration:

### 4a. File Placement

Place the generated file at `src/instructions.md` (or the path configured in the build pipeline).

### 4b. Build Validation

Ensure the build pipeline:

1. **Validates** that `src/instructions.md` exists (fail build if missing).
2. **Copies** it to `dist/instructions.md` during the asset copy step.
3. **Loads** it at runtime via `fs.readFile(path.join(__dirname, 'instructions.md'))`.

### 4c. Server Registration (Three Channels)

Verify the server registers instructions through all three delivery channels:

**Channel 1 — Server `instructions` field (auto-injected at init):**

```typescript
const serverConfig = {
  capabilities: {
    /* ... */
  },
  instructions: serverInstructions, // ← loaded from instructions.md
};
```

**Channel 2 — MCP Resource (on-demand):**

```typescript
server.registerResource(
  'server-instructions',
  'internal://instructions',
  {
    title: 'Server Instructions',
    description: 'Guidance for using the MCP tools effectively.',
    mimeType: 'text/markdown',
    annotations: { audience: ['assistant'], priority: 0.8 },
  },
  (uri) => ({
    contents: [
      { uri: uri.href, mimeType: 'text/markdown', text: instructions },
    ],
  })
);
```

**Channel 3 — MCP Prompt (user-invoked):**

```typescript
server.registerPrompt(
  'get-help',
  {
    title: 'Get Help',
    description: 'Return the server usage instructions.',
  },
  () => ({
    description: 'Server usage instructions',
    messages: [{ role: 'user', content: { type: 'text', text: instructions } }],
  })
);
```

### 4d. Verify Runtime Loading

```typescript
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
let serverInstructions = '(Instructions failed to load)';
try {
  serverInstructions = await fs.readFile(
    path.join(currentDir, 'instructions.md'),
    'utf-8'
  );
} catch (error) {
  console.error('[WARNING] Failed to load instructions.md:', error);
}
```

---

## Step 5 — Quality Checklist

Before delivering, verify against this checklist:

- [ ] **Every registered tool** appears in either CORE CAPABILITY list or TOOL NUANCES section
- [ ] **Golden Path workflows** cover the 2-4 most common use cases
- [ ] **Every error code** from the error enum has a recovery action
- [ ] **No schema duplication** — nuances add value beyond `.describe()` text
- [ ] **Prescriptive language** — uses "Call", "Use", "Check", "Never" (not "can", "might", "should")
- [ ] **Tool names exact** — match registered names with backtick formatting
- [ ] **Cross-references** — tools that work together are linked in workflows or CROSS-FEATURE section
- [ ] **Constraints documented** — size limits, timeouts, binary handling, session scope
- [ ] **Resource/prompt self-reference** — first line mentions `internal://instructions` and `get-help`
- [ ] **Line count** — between 100-250 lines (concise but complete)
- [ ] **Build integration** — file path matches build pipeline expectations
- [ ] **Three delivery channels** — server field + resource + prompt all wired

---

## Anti-Patterns (Avoid)

1. **Capability dumps** — "This server provides tools for X, Y, Z" without sequences.
2. **Schema echo** — Repeating parameter types/descriptions already in `.describe()`.
3. **Marketing language** — "Powerful", "seamless", "robust" add zero value for LLMs.
4. **Missing gotchas** — If a tool truncates output or has pagination, it MUST be documented.
5. **Generic error advice** — "Check your input" is useless. Specify exact recovery: "Run `ls` to verify the path exists."
6. **Orphaned tools** — Every tool must appear in at least one workflow or the nuances section.
7. **Static assumptions** — Don't hardcode paths or values that may differ across deployments.

---

## Output Requirements

Return the complete `instructions.md` content ready to save at the configured path. If code changes are needed to wire the three delivery channels, provide those as separate code blocks with file paths.
