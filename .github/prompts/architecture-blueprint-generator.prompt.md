# Comprehensive Project Architecture Blueprint Generator

## Context

**Role:** Principal Software Architect + Architecture Documentation Specialist  
**Objective:** Create a definitive `Project_Architecture_Blueprint.md` that reverse-engineers the _actual_ architecture from the codebase (not idealized), capturing patterns, boundaries, dependency rules, cross-cutting concerns, deployment topology, and extension/evolution guidance—at the requested detail level and with optional diagrams, code examples, implementation patterns, and ADRs.

## Instructions (System — Execute in phases: 1) Extraction 2) Processing 3) Output)

### 0) Configuration (inputs)

Use these configuration variables to control behavior. If a value is `Auto-detect`, infer it from the codebase evidence.

- `PROJECT_TYPE`: `Auto-detect | .NET | Java | React | Angular | Python | Node.js | Flutter | Other`
- `ARCHITECTURE_PATTERN`: `Auto-detect | Clean Architecture | Microservices | Layered | MVVM | MVC | Hexagonal | Event-Driven | Serverless | Monolithic | Other`
- `DIAGRAM_TYPE`: `C4 | UML | Flow | Component | None`
- `DETAIL_LEVEL`: `High-level | Detailed | Comprehensive | Implementation-Ready`
- `INCLUDES_CODE_EXAMPLES`: `true | false`
- `INCLUDES_IMPLEMENTATION_PATTERNS`: `true | false`
- `INCLUDES_DECISION_RECORDS`: `true | false`
- `FOCUS_ON_EXTENSIBILITY`: `true | false`

> If any configuration value is missing, assume:
>
> - `PROJECT_TYPE=Auto-detect`, `ARCHITECTURE_PATTERN=Auto-detect`, `DIAGRAM_TYPE=C4`, `DETAIL_LEVEL=Comprehensive`,
> - `INCLUDES_CODE_EXAMPLES=true`, `INCLUDES_IMPLEMENTATION_PATTERNS=true`, `INCLUDES_DECISION_RECORDS=true`, `FOCUS_ON_EXTENSIBILITY=true`

---

### Phase 1 — Extraction (evidence gathering)

1. **Inventory the repo**
   - Identify top-level folders, key modules, packages, services, apps, libraries.
   - Extract build/runtime entrypoints and configuration sources.
2. **Detect technology stack(s)**
   - Inspect framework indicators via files such as:
     - Node: `package.json`, lockfiles, `tsconfig.json`, bundler configs, `vite/webpack`, `eslint`, `jest`, `pnpm/yarn/npm`.
     - .NET: `*.sln`, `*.csproj`, `Program.cs`, `Startup.cs`, `appsettings*.json`, `Directory.Build.props`.
     - Java: `pom.xml`, `build.gradle`, Spring annotations/config, `application.yml`.
     - Python: `pyproject.toml`, `requirements.txt`, `setup.cfg`, framework configs.
     - Flutter: `pubspec.yaml`, `lib/main.dart`.
     - Infra: `Dockerfile`, `docker-compose`, `k8s` manifests, Terraform, GitHub Actions, Azure DevOps pipelines.
   - Record **evidence** (file paths + what was observed).
3. **Detect architecture pattern(s)**
   - Infer from folder names, namespaces, dependency direction, interface boundaries, ports/adapters, layering conventions, module boundaries.
   - Build a lightweight **dependency map**:
     - Package/module dependency graph (at least at subsystem level).
     - Identify directionality and boundary enforcement mechanisms.
4. **Locate cross-cutting concerns**
   - AuthN/AuthZ, logging, monitoring, config, secrets, validation, error handling, resilience, caching.
   - Record where these live and how they are applied.
5. **Locate data architecture artifacts**
   - Entities/models, DTOs, mappers, repositories, ORMs, schema/migrations, event stores, caches.
6. **Locate tests + tooling**
   - Test types, frameworks, folder layout, fixtures, mocks, integration test harnesses.
7. **Locate deployment + ops**
   - CI/CD pipelines, containerization, runtime config injection, environment overlays, helm/kustomize, cloud resources.

**Output of Phase 1:** A structured evidence log (not user-facing) you will use to justify every claim in the blueprint.

---

### Phase 2 — Processing (synthesis + validation)

1. **Confirm the primary `PROJECT_TYPE`**
   - If multiple stacks exist, classify them: primary app(s) vs supporting services/tools.
2. **Confirm the primary `ARCHITECTURE_PATTERN`**
   - If hybrid, name the hybrid and explain deviations from “textbook” patterns.
3. **Define architectural boundaries**
   - Identify subsystems/services/modules and their responsibilities.
   - Identify allowed dependency directions and enforcement mechanisms (DI, interfaces, build rules, lint rules).
4. **Identify violations and risks**
   - Circular dependencies, layer violations, anemic boundaries, cross-cutting leakage, “god modules,” tight coupling, hidden shared state.
   - For each, include: location, impact, and pragmatic remediation options.
5. **Extract extension/evolution mechanics**
   - Plugin points, registries, dependency injection containers, event buses, configuration-driven behaviors, hooks/middleware.
6. **Decide diagram strategy**
   - If `DIAGRAM_TYPE != None`, generate diagrams using **text-based** diagramming:
     - Prefer **Mermaid** for Flow/Component/C4-like diagrams; use PlantUML syntax if repo already uses it.
     - Keep diagrams consistent and reference real components.
7. **Decide code example strategy**
   - If `INCLUDES_CODE_EXAMPLES=true`, select minimal, representative excerpts:
     - Include file path and brief context.
     - Redact secrets/tokens and any sensitive values.

---

### Phase 3 — Output (write `Project_Architecture_Blueprint.md`)

Produce a single Markdown document with this exact filename and a clean, navigable structure.

#### Document requirements

- Start with: project name (if detectable), repo root, and **generation timestamp**.
- Include a short “How to keep this updated” section (what to re-scan when changes happen).
- Every non-trivial statement must be grounded in evidence:
  - Reference **specific file paths**, directories, module names, config keys, or code artifacts.
- If something is not found, say **`N/A (not found in codebase)`**.

---

## Constraints & Standards

- **Output:** A single Markdown document: `Project_Architecture_Blueprint.md`
- **Style:** Precise, technical, maintainers’ reference. Prefer tables, bullets, and stable headings. Avoid fluff.
- **Anti-Hallucination:** Do not invent components, technologies, or flows. If uncertain, label as “Inferred” and cite the evidence that motivated the inference. Otherwise return `N/A`.
- **Security:** Do not output secrets. Redact tokens/keys/connection strings.
- **Diagrams:** If `DIAGRAM_TYPE != None`, include text-based diagrams (Mermaid preferred) and ensure they reflect actual dependencies.
- **Scalability:** If repo is large, prioritize:
  1. Entry points + main apps/services
  2. Shared libraries + domain/core modules
  3. Cross-cutting + infrastructure
  4. Tests + deployment  
     Ensure coverage is still architecture-complete at the subsystem level.

---

# Required Blueprint Outline (generate all sections; omit only when `N/A`)

## 1. Architecture Detection and Analysis

- Detected `PROJECT_TYPE` (and secondary stacks)
- Detected `ARCHITECTURE_PATTERN` (or hybrid)
- Evidence table:
  | Claim | Evidence (paths/artifacts) |
  |------|-----------------------------|
  | ... | ... |

## 2. Architectural Overview

- Guiding principles inferred from implementation
- Boundaries and enforcement mechanisms
- Major constraints (legacy, performance, platform, build tooling)

## 3. Architecture Visualization

- If `DIAGRAM_TYPE != None`: include multiple abstraction levels:
  - High-level system/subsystem overview
  - Component interaction & dependency direction
  - Data flow (requests/events) end-to-end
- If `DIAGRAM_TYPE == None`: provide textual relationship mapping with clear dependency directions.

## 4. Core Architectural Components (repeat per component/subsystem)

For each component/subsystem:

- Purpose & responsibility
- Internal structure (folders, key abstractions)
- Interaction patterns (sync/async, interfaces, DI, events)
- Evolution/extension patterns (variation points, plugin mechanisms)

## 5. Architectural Layers and Dependencies

- Layer map as implemented (with table)
- Dependency rules and how enforced
- DI/container usage patterns
- Violations/risks (with remediation options)

## 6. Data Architecture

- Domain model organization
- Entity/aggregate relationships (as inferred)
- Data access pattern(s) (repos/ORM/mappers)
- Transformations (DTOs, mapping layers)
- Caching and validation patterns

## 7. Cross-Cutting Concerns

- Authentication & Authorization
- Error handling & resilience (retries, circuit breakers, fallbacks)
- Logging & monitoring/observability
- Validation patterns
- Configuration management (env overlays, secrets, feature flags)

## 8. Service Communication Patterns

- Service boundaries (if applicable)
- Protocols/formats (HTTP, gRPC, messaging, events)
- Sync vs async, API versioning
- Discovery mechanisms and resilience at boundaries

## 9. Technology-Specific Architectural Patterns

- If `.NET` detected: host model, middleware, DI, ORM, API patterns
- If `Java` detected: container/bootstrap, DI, AOP, transactions, ORM, services
- If `React` detected: composition, state, effects, routing, fetching/caching, perf
- If `Angular` detected: modules, DI/services, state, Rx patterns, guards
- If `Python` detected: modules, dependency mgmt, async, framework integration
- If multiple stacks: cover each with clear scoping.

## 10. Implementation Patterns

- If `INCLUDES_IMPLEMENTATION_PATTERNS=true`:
  - Interface design patterns
  - Service patterns (lifetime/composition/templates)
  - Repository patterns (queries/transactions/concurrency)
  - Controller/API patterns (validation/versioning/formatting)
  - Domain model patterns (entities/VOs/events/rules)
- Else: briefly note that patterns vary and point to representative areas.

## 11. Testing Architecture

- Testing strategy by layer (unit/integration/system)
- Mocking/test doubles
- Fixtures/test data
- Tooling/frameworks and how they integrate with builds

## 12. Deployment Architecture

- Topology inferred from configs
- Environment adaptations
- Container/orchestration
- Config/secrets distribution
- Cloud/service integration patterns

## 13. Extension and Evolution Patterns

- If `FOCUS_ON_EXTENSIBILITY=true`:
  - Feature addition playbook (where to add what)
  - Safe modification patterns (compat, deprecation, migration)
  - Integration patterns (adapters, ACLs, facades)
- Else: list key extension points only.

## 14. Architectural Pattern Examples (conditional)

- If `INCLUDES_CODE_EXAMPLES=true`:
  - Layer separation example(s)
  - Component communication example(s)
  - Extension point example(s)
  - Each example must include: file path, excerpt, and “Why this matters” explanation.

## 15. Architectural Decision Records (conditional)

- If `INCLUDES_DECISION_RECORDS=true`:
  - Create ADR-like entries for key decisions _evident in code_:
    - Context, decision, alternatives (if inferable), consequences, future constraints
  - Mark clearly what is inferred vs explicit (e.g., commit messages, docs).

## 16. Architecture Governance

- How consistency is maintained (lint rules, tests, build gates, code review templates, conventions)
- Automated checks for compliance
- Documentation practices

## 17. Blueprint for New Development

- Workflow for adding features (by type)
- Implementation templates (describe, don’t invent entire frameworks)
- Common pitfalls and how to avoid them
- Include: “Generated on: <timestamp>” and a maintenance recommendation checklist

---

## Output Checklist (before finalizing)

- [ ] All claims have evidence references (paths/artifacts)
- [ ] Diagrams match actual components/dependencies
- [ ] Violations/risks are called out with actionable remediation
- [ ] Extension guidance is concrete and aligned with current architecture
- [ ] No secrets are exposed; redactions applied
- [ ] Document is readable, stable headings, includes TOC if long

> Now generate `Project_Architecture_Blueprint.md` in full, following this outline and honoring the configuration variables.
