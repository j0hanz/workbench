# Generate "Agent Instructions" (System Prompt) for MCP Server

**Role:** You are an expert **MCP Architect** and **Agentic Workflow Designer**.
**Goal:** Create a high-signal `instructions.md` file that teaches an AI Agent how to use this specific MCP server effectively.
**Context:** This file acts as a "User Manual" for the Agent, bridging the gap between raw JSON schemas and actual problem-solving.

---

## 🧠 Phase 1: Forensic Discovery (The "What")

Before writing, scan the workspace (`package.json`, `pyproject.toml`, `src/`, `go.mod`) to answer:

1.  **Runtime Detection:** Is this Node.js (TS/JS), Python, or Go?
2.  **SDK Framework:** Is it the low-level SDK, `McpServer` (TS High-Level), or `FastMCP` (Python)?
3.  **Tool Inventory:** List every tool. Identify "Read" (safe) vs. "Write" (side-effects).
4.  **Implicit Workflows:** Look at `test/` or `examples/`. How do humans chain these tools?

---

## 📝 Phase 2: Draft `instructions.md` (The "Manual")

Generate a **concise (<2KB)** Markdown file using this exact structure.

### Template Structure

```markdown
# {Server Name} Instructions

> **Guidance for the Agent:** These instructions are available as a resource (`internal://instructions`) or prompt (`get-help`). Load them when you are confused about tool usage.

## 1. Core Capability

- **Domain:** [One sentence summary]
- **Primary Resources:** [List key data types, e.g., `Tasks`, `Logs`, `DatabaseRows`]

## 2. The "Golden Path" Workflows (Critical)

_Describe the standard order of operations. Do not assume the agent knows this._

### Workflow A: [e.g., "Diagnosing an Error"]

1. Call `list_errors` to find recent crashes.
2. Call `get_error_logs` using the `id` from step 1.
3. Call `analyze_stacktrace` (optional).
   > **Constraint:** Never guess IDs. Always list first.

### Workflow B: [e.g., "Deploying a Fix"]

1. Call `validate_config`.
2. Call `deploy` only if validation passes.

## 3. Tool Nuances & "Gotchas"

_Do NOT repeat the JSON Schema. Focus on behavior._

- **`{tool_name}`**:
  - **Latency:** "This tool takes ~30s. Do not timeout immediately."
  - **Side Effects:** "Sends a real email. Ask user confirmation first."
  - **Input Formats:** "Dates must be ISO-8601 (YYYY-MM-DD)."

## 4. Error Handling Strategy

- "If you receive `404 Not Found`, try searching with a wildcard `*`."
- "If `rate_limited`, wait 5 seconds before retrying."
```

---

## 🔌 Phase 3: Integration Logic (The "How")

Determine the best way to expose this file based on the **Runtime detected in Phase 1**. Choose ONE path:

### Path A: TypeScript (`@modelcontextprotocol/sdk`)

_Implement a fixed Resource._

- **URI:** `internal://instructions`
- **Mime:** `text/markdown`
- **Implementation:**

```typescript
// Add this to your server setup
server.resource(
  'internal://instructions',
  new ResourceTemplate('internal://instructions', { list: undefined }),
  async (uri) => ({
    contents: [
      {
        uri: uri.href,
        text: fs.readFileSync(
          path.join(__dirname, '../instructions.md'),
          'utf-8'
        ),
        mimeType: 'text/markdown',
      },
    ],
  })
);
```

### Path B: Python (`FastMCP`)

_Use the constructor injection._

- **Implementation:**

```python
mcp = FastMCP("my-server", instructions=open("instructions.md").read())

```

### Path C: Python (Low-Level / Standard SDK)

_Implement a Resource reader._

- **URI:** `internal://instructions`
- **Implementation:** Use the `@server.list_resources()` and `@server.read_resource()` decorators to return the file content.

---

## ✅ Phase 4: Final Output

1. **The File:** A complete `src/instructions.md` (or root `instructions.md` depending on convention).
2. **The Code:** The exact code snippet to expose this file as a **Resource** or **System Prompt** in the current codebase.
3. **Verification:** A quick checklist confirming you didn't just dump JSON schemas into the markdown.

**Constraint:** Do not invent tools. If the server has no "Write" tools, do not invent a "Deployment" workflow.
