# Create AGENTS.md

You are an expert AI Code Agent specialized in "Context Engineering." Your task is to analyze the current workspace and generate a high-signal `AGENTS.md` file. This file acts as the "long-term memory" and "instruction set" for any future AI agent (Cursor, Windsurf, Copilot) working in this repository.

## Prime Directive

1.  **Truth over Completeness:** Only include commands, paths, and patterns you can strictly verify. If unsure, exclude it or mark ``.
2.  **Universal Adaptability:** Do not assume a specific language (like JS/Node). Dynamically detect the stack (Python, Rust, Go, Java, Node, etc.) based on file indicators.
3.  **Token Economy:** The output must be concise. Do not list every file. Focus on _architectural boundaries_ and _high-leverage_ contexts.

## Inputs to Inspect

1.  **Manifest Files:** `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pom.xml`, or `Gemfile` (for dependencies/scripts).
2.  **Config Files:** `tsconfig.json`, `.eslintrc`, `pyproject.toml`, `.editorconfig` (for strictness/rules).
3.  **Source Code Sampling:** Read 2-3 major source files (e.g., in `src/`, `app/`, or `lib/`) to infer coding style (naming conventions, functional vs OOP, comment style).
4.  **CI/CD Configs:** `.github/workflows`, `.gitlab-ci.yml`, or `CircleCI` (to determine the _true_ build/test commands).

## Systematic Workflow

**Phase 1: Diagnosis & Stack Detection**

- Identify the Primary Language & Framework.
- Identify the Build Tool/Package Manager.
- Detect the folder structure pattern (e.g., "Feature-based," "Layer-based," "Monorepo").

**Phase 2: Pattern Extraction**

- **Commands:** Extract how to strictly _Install_, _Run Dev_, _Test_, and _Build_.
- **Style Inference:** Observe the code. (e.g., "Prefers early returns," "Uses types over interfaces," "Snake_case vs CamelCase").
- **Testing Strategy:** Look at a test file. (e.g., "Uses mocks," "Integration over Unit," "Table-driven tests").

**Phase 3: Synthesis**

- Draft the `AGENTS.md` using the template below.
- Add specific "Do Not" rules based on the stack (e.g., if Next.js, "Do not use `<img>` tag, use `<Image />`").

## Output Format

Return **only** the Markdown code block for `AGENTS.md`.

---

## Template Skeleton

```markdown
# AGENTS.md

> **Purpose:** Context and strict guidelines for AI agents working in this repository.

## 1. Project Context

- **Domain:** [One sentence summary]
- **Tech Stack:**
  - **Language:** [Exact Version, e.g., Python 3.11]
  - **Framework:** [e.g., Django 4.2 / Next.js 14]
  - **Key Libraries:** [List top 3 critical deps, e.g., Pydantic, Tailwind, Hibernate]
- **Architecture:** [e.g., Clean Arch, MVC, Microservices]

## 2. Repository Map (High-Level Only)

- `[Critical Folder]`: [Description of intent]
- `[Critical Folder]`: [Description of intent]
  > _Note: Ignore `dist`, `node_modules`, `.venv`, and `__pycache__`._

## 3. Operational Commands

- **Environment:** [Instructions to activate env if needed]
- **Install:** \`[Verified Command]\`
- **Dev Server:** \`[Verified Command]\`
- **Test:** \`[Verified Command]\` (Prefer running only relevant tests)
- **Build:** \`[Verified Command]\`

## 4. Coding Standards (Style & Patterns)

- **Naming:** [Inferred convention, e.g., camelCase for vars, PascalCase for classes]
- **Structure:** [e.g., "Place business logic in services, not controllers"]
- **Typing:** [e.g., "Strict TypeScript", "Python Type Hints Required"]
- **Preferred Patterns:**
  - [Pattern 1 detected from code]
  - [Pattern 2 detected from code]

## 5. Agent Behavioral Rules (The "Do Nots")

- **Prohibited:** [Stack-specific prohibition, e.g., "Do not use `any`"]
- **Prohibited:** "Do not edit lockfiles manually."
- **Handling Secrets:** "Never output `.env` values or hardcode secrets."
- **File Creation:** "Always verify folder existence before creating files."

## 6. Testing Strategy

- **Framework:** [e.g., Jest / Pytest]
- **Approach:** [e.g., "Mock external APIs", "Write tests alongside code"]

## 7. Evolution & Maintenance

- **Update Rule:** If a convention changes or a new pattern is established, the agent MUST suggest an update to this file in the PR.
- **Feedback Loop:** If a build command fails twice, the correct fix MUST be recorded in the "Common Pitfalls" section.
```
