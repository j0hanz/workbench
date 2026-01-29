# Generate MCP Agent Instructions (Repo-Verified)

## Context

**Role:** Expert MCP Architect + Agentic Workflow Designer  
**Stack:** Detect from repository (Node/TS/JS vs Python vs Go; MCP SDK flavor)  
**Mode:** Chained System

## Objective

Produce a concise (<2KB) `instructions.md` that teaches an AI agent how to use **this specific MCP server** effectively, based strictly on repository evidence, and provide the exact code snippet needed to expose those instructions in the server.

Execute in phases: 1) Raw Data Extraction 2) Data Processing 3) Final Output Generation.

## Standards & Constraints

- **No invention:** Do not invent tools, workflows, file paths, commands, IDs, URIs, or capabilities.
- **Evidence-bound:** Only include details you can **verify in-repo**. If unsure, omit or label **UNVERIFIED**.
- **Tool safety:** Separate **Read** tools (no side effects) vs **Write** tools (side effects). If no write tools exist, do not describe write workflows.
- **Never guess IDs/URIs:** Always list/search first; explicitly state this in the instructions.
- **Do not dump JSON schemas:** Focus on practical behavior, constraints, pitfalls, and safe usage patterns.
- **Size:** `instructions.md` must be **<2KB** (tight, high-signal).
- **Integration snippet:** Choose exactly one integration approach based on detected runtime/framework:
  - TypeScript `@modelcontextprotocol/sdk` (high-level `McpServer`) → expose Resource `internal://instructions` as `text/markdown`
  - Python `FastMCP` → constructor injection `FastMCP(..., instructions=open(...).read())`
  - Python low-level SDK → implement resource listing + reader for `internal://instructions`
  - Do not include code for frameworks not used by this repo.

## Phase 1 — Forensic Discovery (Repository-Backed)

Scan the workspace and record evidence with file references:

1. **Runtime:** Node (TS/JS) vs Python vs Go
   - Evidence targets: `package.json`, `tsconfig.json`, `pyproject.toml`, `requirements.txt`, `go.mod`, etc.
2. **SDK framework:** low-level vs high-level (`McpServer` / `FastMCP`)
   - Evidence targets: server entry file(s), imports, initialization patterns.
3. **Tool inventory:** list every tool, classify as **Read** or **Write**
   - Evidence targets: tool registration code; any `resources`, `prompts`, handlers.
4. **Implicit workflows:** infer safe tool-chains from `examples/`, `tests/`, docs, scripts
   - Evidence targets: `examples/*`, `test/*`, `docs/*`, `README*`, `scripts/*`.

Output an internal “Evidence Notes” section while working (for your own correctness), but DO NOT include it in the final answer unless requested.

## Phase 2 — Synthesize Practical Agent Guidance

From verified tools/resources/prompts:

- Identify the server’s **domain** and **primary resources** (1 sentence + short list).
- Build 1–2 **Golden Path** workflows that represent how humans/agents should use the server.
- For each tool, extract only the **nuances**:
  - key required/format constraints
  - side effects (if any) + when to ask user confirmation
  - common failure modes and remediation (list/search first, narrower queries, etc.)
- Capture error-handling strategy (repo-verified retries/backoff if present; otherwise omit).

## Phase 3 — Author `instructions.md` (Exact Structure)

Write `instructions.md` using ONLY verified details and EXACT structure:

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

Ensure the entire file is <2KB.

## Phase 4 — Integration Snippet (Repo-Detected)

Based on detected runtime/framework, output the exact code snippet that exposes `instructions.md` per repo conventions:

- If TypeScript SDK: register `internal://instructions` resource with `text/markdown` content loaded from the repo-appropriate path.
- If Python FastMCP: inject `instructions=open(...).read()` into `FastMCP(...)`.
- If Python low-level: implement list/read for `internal://instructions`.

Use paths consistent with repo patterns (root vs `src/`), proven by evidence.

## Final Output (STRICT)

Return ONLY the following, in order:

1. A single **Markdown** code block containing the full contents of `instructions.md`
   - Include the verified repo path in the first heading line or a top comment (e.g., `<!-- path: ... -->`).

2. A single code block with the exact integration snippet for this repo.
3. A short verification checklist (3–6 bullets) confirming:
   - No invented tools/workflows
   - `<2KB` markdown
   - Read vs Write classified
   - Evidence-based commands/URIs
   - No schema dumping
