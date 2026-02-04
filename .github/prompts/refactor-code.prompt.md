# Refactor Code with Clean Code + SOLID (Aggressive Architectural Refactor)

## Context

**Role:** Strict Senior Software Architect (no sentimentality about existing structure)  
**Mode:** Chained System (phase-based processing)  
**Stack (fill in):** Language: {{language}} | Runtime: {{runtime}} | Framework: {{framework}} | Build: {{build_tool}}  
**Primary Goal:** Decouple, scale, modernize, and make the codebase easier to change safely.

**Input Code (paste exactly, include all relevant files):**

```text
{{code_or_repo_snippets_here}}
```

**Constraints / Requirements (fill in):**

- Must preserve external behavior/APIs? {{yes_no_unknown_if_unknown_assume_yes}}
- Performance constraints: {{none_or_details}}
- Allowed dependencies/libraries: {{list_or_none}}
- Target version (e.g., Java 21 / .NET 8 / Node 20 / Python 3.12): {{version}}
- Testing expectations (existing tests? required coverage?): {{details}}
- Style/lint rules (if any): {{details}}
- Deployment/runtime constraints (e.g., serverless, embedded, mobile): {{details}}
- **File scope:** Refactor ONLY the provided/selected files; do NOT create new files unless explicitly requested by user.

---

## Objective

Aggressively refactor the provided code to align with **Clean Code** and **SOLID** principles.

### Strategy Injection (mandatory)

Execute in phases:

1. **Extraction** (diagnose & map responsibilities)
2. **Transformation** (new architecture & refactor plan)
3. **Generation** (production-ready refactored code + minimal necessary glue)
4. **Validation** (behavioral parity checks, edge cases, test strategy)

---

## Standards & Constraints

### Clean Code (non-negotiable)

- **Self-documenting naming**: rename everything that is unclear; avoid comments that explain _what_ code does.
- **Small functions**: functions do one thing; prefer early returns / guard clauses.
- **Explicit dependencies**: no hidden globals/singletons unless justified and encapsulated.
- **Readable control flow**: eliminate deep nesting; replace `if/else` chains with polymorphism/strategy where appropriate.
- **Error handling**: consistent strategy; no swallowed exceptions; actionable errors.

### SOLID (enforce ruthlessly)

- **SRP**: split large classes/modules; each unit has exactly one reason to change.
- **OCP**: enable extension without modification (strategies, interfaces, composition).
- **LSP**: no subtype surprises; enforce contracts.
- **ISP**: narrow interfaces; avoid “fat” abstractions.
- **DIP**: depend on abstractions; inject dependencies; avoid concrete coupling.

### Architectural directives

- You may **replace the entire structure** if it's flawed **within the provided files only**.
- Prefer **composition over inheritance**.
- Use appropriate patterns only when they earn their keep (e.g., Strategy, Factory, Adapter, Repository, Hexagonal/Ports & Adapters).
- Separate **domain logic** from **I/O**, **framework**, and **infrastructure**.
- **CRITICAL:** Do NOT create new files or suggest splitting into multiple files unless the user explicitly requests it. All refactoring must happen within the provided/selected file(s).

---

## Required Output

### 1) Refactored Code (production-ready)

Provide:

- Fully updated code in modern syntax for {{language}} **for the selected file(s) only**.
- Any new interfaces/types introduced for DIP/OCP **within the same file(s)**.
- Minimal glue code to preserve the public API/entrypoints.
- If tests exist: update them only as needed; if not, provide a small high-value test scaffold.
- **Do NOT create new files or split code across multiple files** unless the user explicitly requested it.

### 2) Brief Explanation (bullets)

Explain **what changed** and **why**, explicitly mapping to:

- SOLID principles (SRP/OCP/LSP/ISP/DIP)
- Clean Code rules (naming, function size, control flow, error handling)
- Architectural improvements (boundaries, dependency direction, scalability)

---

## Transparency Requirements (show your work)

Before generating final code, output:

1. **Code Smell Report**: top issues with examples (quote short snippets).
2. **Responsibility Map**: what each current class/function is doing (and why it violates SRP if it does).
3. **Target Architecture**: concise design overview + dependency direction.
4. **Refactor Plan**: ordered steps + risk notes.

Then output the final code + explanation.

---

## Guardrails / Assumptions Handling

- If requirements are missing, state assumptions explicitly and proceed with the safest default.
- If behavior is ambiguous, preserve existing behavior unless it is clearly a bug; if likely a bug, flag it and isolate changes.
- Avoid “clever” abstractions; optimize for maintainability.

---

## Response Format

Return exactly in this order:

1. **Smell Report**
2. **Responsibility Map**
3. **Target Architecture**
4. **Refactor Plan**
5. **Refactored Code** (for selected file(s) only, no new files)
6. **Brief Explanation** (bullet list, mapped to principles)
