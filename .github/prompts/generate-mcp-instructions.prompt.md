# Generate MCP Agent Instructions

You are an expert MCP Architect and Agentic Workflow Designer. Your task is to generate **Agent Instructions** for THIS MCP server.

## Objective

Create a high-signal **concise (<2KB)** `instructions.md` that teaches an AI agent how to use this specific MCP server effectively—bridging raw tool schemas to practical workflows—AND provide the exact code snippet needed to expose these instructions in the server implementation.

## Hard Constraints

- Do **not** invent tools, workflows, file paths, or commands.
- Only include what you can **verify from the repository**; if unsure, omit or label **UNVERIFIED**.
- Separate **Read** tools (safe) vs **Write** tools (side effects). If no write tools exist, do not describe write workflows.
- Never guess IDs or resource URIs—always list/search first.
- Keep `instructions.md` under **2KB** (tight, high-signal).

## Phase 1: Forensic Discovery (Repository-Backed)

Scan the workspace to determine (with file evidence):

1. **Runtime**: Node (TS/JS) vs Python vs Go
2. **SDK framework**: low-level SDK vs TypeScript `McpServer` (high-level) vs Python `FastMCP`
3. **Tool inventory**: list every tool; classify each as **Read** or **Write**
4. **Implicit workflows**: inspect `examples/`, `test/`, docs, or scripts to infer how humans chain tools

Record evidence as file references (e.g., `package.json`, `src/server.ts`, `examples/*`).

## Phase 2: Write `instructions.md` (Return as Markdown)

Generate a concise Markdown file using EXACT structure below (fill with verified details only):

```markdown
# {Server Name} Instructions

> Guidance for the Agent: These instructions are available as a resource (`internal://instructions`) or prompt (`get-help`). Load them when you are unsure about tool usage.

## 1. Core Capability

- **Domain:** [One sentence summary]
- **Primary Resources:** [Key data types the server deals with]

## 2. The "Golden Path" Workflows (Critical)

_Describe the standard order of operations using ONLY tools that exist._

### Workflow A: [Name]

1. Call `{tool}` ...
2. Call `{tool}` ...
   > Constraint: Never guess IDs/URIs. Always list/search first.

### Workflow B: [Name] (Only if supported by tools)

1. ...

## 3. Tool Nuances & Gotchas

_Do NOT repeat JSON schema. Focus on behavior and pitfalls._

- **`{tool_name}`**
  - **Purpose:** [1 line]
  - **Inputs:** [Only key constraints: formats, required fields, limits]
  - **Side effects:** [None | Describe impact; require user confirmation if destructive]
  - **Latency/limits:** [If implied by code/tests; otherwise omit]
  - **Common failure modes:** [What errors look like + what to do]

## 4. Error Handling Strategy

- [Repo-verified retry/backoff or common errors]
- [Fallback steps (search/list, narrower queries, etc.)]
```

## Phase 3: Integration Logic (Choose One; Repo-Detected)

Based on detected runtime/framework, output the exact code snippet to expose `instructions.md`:

### A) TypeScript (`@modelcontextprotocol/sdk`)

- Expose as Resource: `internal://instructions` with `text/markdown`
- Use repo conventions for file paths (root `instructions.md` vs `src/instructions.md`)

### B) Python (`FastMCP`)

- Use constructor injection: `FastMCP(..., instructions=open(...).read())`

### C) Python (Low-Level SDK)

- Implement resource listing + reader for `internal://instructions`

Do not include code for paths that do not match the repo’s runtime/framework.

## Phase 4: Final Output (STRICT)

Return ONLY the following, in order:

1. A single Markdown code block containing the full contents of `instructions.md` (placed at the verified repo-appropriate path; mention the path in the first heading or a comment line).
2. A single code block with the exact integration snippet for this repo.
3. A short verification checklist (3–6 bullets) confirming:
   - No invented tools/workflows
   - <2KB markdown
   - Read vs Write classified
   - Evidence-based commands/URIs
   - No schema dumping
