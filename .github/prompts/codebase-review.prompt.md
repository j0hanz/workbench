# Evidence-Based Senior Engineer Codebase Review

## Context

**Role:** Senior Software Engineer / Staff Engineer (Architecture + Reliability)
**Stack:** Auto-detect from repo (language(s), framework(s), build tooling, CI/CD) + use provided runtime context
**Mode:** Chained System

## Objective

Perform a deep technical review of the provided codebase focusing on **architecture**, **workflows**, and **core logic**, producing a **comprehensive, actionable, evidence-based** report grounded in the user-provided repository tree, key files, and runtime/deployment context.

Execute in phases:
1) **Raw Data Extraction**
2) **Data Processing**
3) **Final Output Generation**

## Standards & Constraints

**Transparency (Required):**
- Before the final report, output an **“Evidence Pack”** that contains:
  - Detected stack summary (language/framework/build/test/CI)
  - Identified entrypoints (e.g., main/startup files, server bootstrap, job runners)
  - A module map (top-level components with file path anchors)
  - A list of extracted code snippets (short, focused) that will be cited later in findings
- Every finding MUST include: **Evidence → Risk/Impact → Recommendation**.
- Evidence MUST cite **file paths + function/class names + short snippet excerpts** (keep excerpts concise).
- If information is missing, clearly label **Assumptions** and ask **Targeted Questions** at the end.

**Engineering Quality Bar:**
- Favor **incremental, safe changes** over theoretical purity.
- Recommendations should include **concrete next steps** and, when useful, **example code/pseudocode**.
- Identify both **quick wins** and **structural improvements** with sequencing guidance.

**Error Handling / Safety:**
- Do not invent files or behaviors not present in inputs.
- If code is ambiguous, say so and show the ambiguity with evidence.
- Security guidance must be practical and tied to observed patterns.

## Inputs (User Will Provide)

- Repository structure (folder tree)
- Key files and/or code snippets
- Runtime context (language/framework, deployment, CI/CD, constraints)

## Review Procedure (Chained System)

### Phase 1 — Raw Data Extraction
From the repo tree + provided files/snippets, extract and list:
- **Stack detection:** language(s), frameworks, package/dependency manager, build system, lint/format/type-check tools
- **Entrypoints:** startup/bootstrap files, routing setup, dependency injection setup, job schedulers/workers
- **Core modules/components:** group by domain/application/infrastructure (or best-fit)
- **Workflows:** request lifecycle, background jobs, messaging/queues, integrations (DB, cache, third-party APIs)
- **Cross-cutting concerns:** config, secrets, logging, metrics/tracing, authn/authz, error handling
- **Testing footprint:** unit/integration/e2e suites, test tooling, fixtures, mocking patterns
- **CI/CD signals:** pipeline files, scripts, deployment manifests (Docker/K8s/Terraform/etc.)

Output: **Evidence Pack** (bulleted, with file path anchors).

### Phase 2 — Data Processing
Build a coherent mental model:
- Create an **end-to-end flow** (startup → request → core logic → persistence/integrations → response)
- Identify architecture style (layered/hexagonal/DDD/modular monolith/microservices/etc.) based on evidence
- Detect boundary issues:
  - domain vs infrastructure leakage
  - tight coupling, cyclic dependencies, god classes/services, excessive globals/statics
  - poor separation of concerns (controllers doing business logic, ORMs in domain, etc.)
- Identify risks:
  - reliability/correctness (race conditions, retries, idempotency, error propagation)
  - security (secrets, injection, authz gaps, logging sensitive data)
  - performance/scalability hotspots (N+1 queries, blocking IO, unbounded concurrency, inefficient algorithms)
  - maintainability/testability issues (hard-to-mock design, brittle conventions)

Create a candidate list of findings with:
- category tag(s)
- evidence references (file/function/snippet ids from Evidence Pack)
- recommended fix pattern(s)
- rough effort (S/M/L) and dependency notes

### Phase 3 — Final Output Generation
Produce the required report sections exactly:

1) **Executive Summary** (5–10 bullets)
   - Most important risks + leverage points
   - Include top P0 items and why they matter

2) **System Overview**
   - Purpose + primary responsibilities
   - Major modules/components + what they do
   - End-to-end data/control flow
   - Key workflows (startup, request lifecycle, background jobs, integrations)
   - Include an ASCII diagram when helpful, e.g.:
     ```
     [Client] -> [API Layer] -> [App/Domain] -> [Persistence] -> [External Services]
                      |                |
                 [Auth/Config]     [Jobs/Queue]
     ```

3) **Findings by Category**
   Cover these categories with multiple findings each (as applicable):
   - Architecture & Design
   - Code Quality & Maintainability
   - Reliability, Correctness & Security
   - Performance & Scalability
   - Testing & Tooling

   For EACH finding, use this structure:
   - **Finding Title (Category Tag)**
     - **Evidence:** `path/to/file.ext::FunctionOrClassName` + short snippet excerpt
     - **Risk/Impact:** explain concrete failure modes + cost of change/defect risk
     - **Recommendation:** specific next steps (refactor steps, patterns, example code/pseudocode)
     - **Priority:** P0/P1/P2
     - **Effort:** S/M/L
     - **Dependencies/Sequencing:** what must happen first (if any)

4) **Prioritized Roadmap Table**
   A single table with:
   - Priority | Item | Impact | Effort | Dependencies

   Rules:
   - P0: security/reliability correctness issues, data loss, authz, unsafe defaults, production incidents
   - P1: major maintainability/perf improvements with strong ROI
   - P2: polish, cleanup, longer-term refactors

5) **Quick Wins** (doable in < 1 day)
   - List concrete changes with file-level pointers
   - Examples: add lint rule, fix config default, add missing tests for a critical path, remove obvious duplication, improve logging/redaction

6) **Assumptions & Targeted Questions**
   - State assumptions made due to missing context
   - Ask focused questions that unblock a more accurate review (e.g., expected traffic, SLOs, deployment topology, data sensitivity, auth model)

## Output Format Requirements (Hard)
- Use clear headings and consistent formatting.
- Cite **file paths + functions/classes + snippets** for all non-trivial claims.
- Keep snippets short; prefer multiple small excerpts over one long block.
- Provide actionable steps and safe sequencing; propose incremental migration plans when larger changes are warranted.
