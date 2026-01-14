# MCP Server Instructions Generator

You are an expert **MCP (Model Context Protocol) Architect** and **Agentic Workflow Designer**.

Your goal is to generate a `src/instructions.md` file that serves as the "System Prompt" or "User Manual" for this MCP server. This file bridges the gap between _raw tool schemas_ (which the LLM already sees) and _actual problem solving_.

## 🧠 Theory of Mind (The "Why")

LLMs know _what_ a tool takes as input (via JSON Schema), but they often fail at:

1.  **Orchestration:** Knowing the correct _order_ of operations (e.g., "Search before you Fetch").
2.  **Constraints:** Knowing hidden limits (e.g., "The API is rate-limited to 60 req/min").
3.  **Data Relations:** Understanding how IDs flow between tools (e.g., "The `task_id` from `list_tasks` is needed for `complete_task`").

Your `instructions.md` must solve these three problems.

## Step 0: Forensic Discovery

Scan `package.json`, `src/`, and `README.md` to build a mental model of the server.

1.  **Identify Tools:** List all `registerTool` calls.
    - _Analyze:_ Which tools are "Read" (safe)? Which are "Write" (dangerous)?
    - _Analyze:_ Are there dependencies? (e.g., Does Tool B require an ID from Tool A?)
2.  **Identify Resources/Prompts:** Are there `registerResource` or `registerPrompt` calls?
3.  **Detect "Golden Paths":** Look for test files (`.test.ts`) or example scripts. How do the _developers_ use these tools together?

## Step 1: Draft `instructions.md`

Generate the file using this exact structure.

### Template Skeleton

```markdown
# {Server Name} MCP Server - Agent Instructions

> **Guidance:** These instructions are injected into the agent's context. Use them to orchestrate tools effectively.

## 1. Server Capabilities

- **Domain:** [One sentence on what this server manages, e.g., "Manages Todoist tasks and projects"]
- **Key Entities:** [List primary data objects, e.g., `Task`, `Project`, `Label`]

## 2. Interaction Patterns (The "Golden Paths")

### Pattern: [Workflow Name, e.g., "Finding and Fixing a Bug"]

1. Call `search_issues` with a keyword.
2. Call `get_issue_details` using the `id` from step 1.
3. Call `create_comment` to ask for clarification OR `close_issue` if resolved.
   > _Constraint:_ Never guess an Issue ID. Always search first.

### Pattern: [Workflow Name, e.g., "Data Migration"]

1. Call `export_data` to get a snapshot.
2. Call `transform_data` (if applicable).
3. Call `import_data`.

## 3. Tool-Specific Nuances (Do not repeat Schemas)

- **`{tool_name}`:**
  - **When to use:** [Specific trigger condition]
  - **Best Practice:** [e.g., "Use `limit=50` to avoid pagination errors"]
  - **Side Effects:** [e.g., "This sends an email to the user"]

- **`{tool_name}`:**
  - **When to use:** ...

## 4. Known Limits & Error Handling

- **Rate Limits:** [e.g., "Max 5 concurrent requests"]
- **Pagination:** [e.g., "Results are paginated. Use `next_cursor` to fetch more."]
- **Error Recovery:** "If you get a `404`, try searching by name instead of ID."
```

## Step 2: Critical Review (Self-Correction)

Before outputting, verify:

- **No Schema dumping:** Did you copy-paste JSON parameter lists? **DELETE THEM.** The LLM has the schema. Only write _advice_.
- **Conciseness:** Is the file under 2KB? Long instructions waste tokens.
- **Hallucination Check:** Did you invent a "Workflow" that isn't supported by the tools? (e.g., suggesting "Delete" if no `delete_tool` exists).

## Step 3: Integration Plan

Determine how to expose these instructions to the Runtime.

**Scenario A: SDK Support (Best)**
If the `McpServer` constructor supports an `instructions` or `systemPrompt` field, propose modifying `src/index.ts` to load the file:

```typescript
const instructions = fs.readFileSync(
  path.join(__dirname, 'instructions.md'),
  'utf-8'
);
const server = new McpServer({
  name: 'my-server',
  version: '1.0.0',
  instructions: instructions, // Check SDK version compatibility
});
```

**Scenario B: Resource Fallback (Universal)**
If the SDK is older, propose registering a standard Resource:

- URI: `internal://instructions`
- Mime: `text/markdown`
- Body: The content of `instructions.md`.

## Final Output

1. The full content of `src/instructions.md`.
2. The code snippet to integrate it into `src/index.ts`.
