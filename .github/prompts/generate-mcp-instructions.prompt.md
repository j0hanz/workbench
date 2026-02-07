# Generate MCP instructions.md + integration snippet

## Context

**Role:** Expert MCP Architect + Agentic Workflow Designer  
**Objective:** Produce a concise (<2KB) `instructions.md` that teaches an AI agent how to use _this specific_ MCP server effectively, based strictly on repository evidence, and output the exact code snippet needed to expose those instructions in the server.

## Instructions (System)

Execute in phases: **1) Raw Data Extraction 2) Data Processing 3) Final Output Generation**

### Phase 1 — Forensic Discovery (Repository-Backed)

Scan the workspace and maintain an internal **Evidence Notes** log with:

- **file path**
- **line range(s)**
- **short quote(s)**

**Do NOT output Evidence Notes unless explicitly requested.**

Extract and evidence the following (or record “Not evidenced in repo.”):

1. **Runtime detection** (Node TS/JS vs Python vs Go)
   - Evidence targets: `package.json`, `tsconfig.json`, `pyproject.toml`, `requirements.txt`, `go.mod`, etc.

2. **SDK/framework flavor** (MCP low-level vs high-level, e.g., TS `McpServer` vs Python `FastMCP`)
   - Evidence targets: server entry files, imports, initialization patterns, server construction, handlers.

3. **Tool inventory** — list every tool and classify each as:
   - **READ** (no side effects)
   - **WRITE** (side effects)
   - Evidence targets: tool registration code, handler implementations, any resources/prompts.

4. **Resources and prompts**
   - Any resource URIs, prompt names, resource listing/reader handlers.
   - Never guess IDs/URIs; only use those evidenced in code.

5. **Entrypoint determination**
   - If multiple entrypoints exist, choose the actual server runtime based on scripts/exports/usage patterns (e.g., `package.json` scripts, module exports, CLI docs).

6. **Implicit workflows**
   - Infer safe tool-chains from `examples/`, `tests/`, `docs/`, `README*`, `scripts/*`.
   - Only describe workflows that are supported by evidenced tools/resources.

### Phase 2 — Synthesize Practical Agent Guidance (Evidence-Only)

Using only verified tools/resources/prompts:

1. Identify the server’s **domain** and **primary resources** (1 sentence + short list).
2. Build **1–2 “Golden Path” workflows** that an agent should follow (only using tools that exist).
3. For each tool, capture only high-signal nuances:
   - required fields / formats / constraints
   - side effects + when to require user confirmation
   - common failure modes + remediation (e.g., “list/search first”, narrower queries)
4. Include error-handling strategy only if explicitly evidenced (timeouts, retries, backoff); otherwise omit.

### Phase 3 — Author `instructions.md` (Exact Structure, <2KB)

Write `instructions.md` using ONLY verified details and the exact structure below. Keep it **<2KB (~2048 bytes UTF-8)**. If you’re close to the limit, tighten wording.

Use this exact structure:

---

# {SERVER NAME} INSTRUCTIONS

These instructions are available as a resource (internal://instructions) or prompt (get-help). Load them when unsure about tool usage.

---

## CORE CAPABILITY

- Domain: [One sentence summary]
- Primary Resources: [Key data types the server deals with]
- Tools: [tool-name] (READ-ONLY or WRITE)

---

## THE "GOLDEN PATH" WORKFLOWS (CRITICAL)

### WORKFLOW A: [NAME]

- Call {tool} with: { ... }
- Read the "field" from response.
- If [condition]: [action].
  NOTE: Never guess IDs/URIs. Always use the ones returned.

### WORKFLOW B: [NAME] (only if supported by tools)

- Call {tool} ...
- ...

---

## TOOL NUANCES & GOTCHAS

{tool_name}

- Purpose: [1 line]
- Input: [Only key constraints: formats, required fields, limits]
- Side effects: [None | Describe impact; require user confirmation if destructive]
- Limits: [If implied by code/tests; otherwise omit]
- Common failure modes: [What errors look like + what to do]

---

## ERROR HANDLING STRATEGY

- {ERROR_CODE}: [Description]. [Action].
- {ERROR_CODE}: [Description]. [Action].

---

## RESOURCES

- {uri}: [Description]

---

**Rules inside `instructions.md`:**

- Explicitly state: **Never guess IDs/URIs; always list/search first and use returned identifiers.**
- Do not describe write workflows if no WRITE tools exist.
- No schema dumps; focus on practical usage, constraints, pitfalls, safe patterns.
- If uncertain: omit or label **UNVERIFIED** (prefer omit).

### Phase 4 — Integration Snippet (Repo-Detected, Exactly One Approach)

Output the exact code snippet that exposes `instructions.md` per the detected repo runtime/framework:

Choose exactly ONE (based on evidence):

- **TypeScript @modelcontextprotocol/sdk `McpServer`:** expose `internal://instructions` as a Resource with `text/markdown` content loaded from the verified file path.
- **Python `FastMCP`:** inject `instructions=open(...).read()` into the evidenced `FastMCP(...)` construction site.
- **Python low-level SDK:** implement resource listing + reader for `internal://instructions` only, matching existing architecture.

Constraints:

- Use paths consistent with repo conventions (root vs `src/`), proven by evidence.
- Do NOT include code for frameworks not used by this repo.
- Do NOT invent any filenames, tool names, URIs, prompts, commands, or behaviors.

## Constraints & Standards

- **Output:** Strictly return (in order):
  1. A single Markdown code block containing the full contents of `instructions.md`
  2. A single code block with the exact integration snippet for this repo
  3. A short verification checklist (3–6 bullets) confirming:
     - No invented tools/workflows
     - `<2KB` markdown
     - READ vs WRITE classified
     - Evidence-based commands/URIs
     - No schema dumping
- **Style:** Tight, high-signal prose; operational guidance over theory.
- **Anti-Hallucination:** Do not invent data; if missing, write “Not evidenced in repo.” or omit; label **UNVERIFIED** only when absolutely necessary.
