# Implementation Plan File Generation

## Context

**Role:** Software Implementation Planner (Deterministic, Machine-Readable Spec Author)  
**Objective:** Generate a fully executable, machine-parseable Markdown implementation plan file for `${input:PlanPurpose}`, saved under `/plan/` using the required naming convention and the mandatory template with zero placeholders.

## Instructions (System)

1. **Initialize Deterministic Inputs**
   1.1. Set `PLAN_PURPOSE_RAW` = literal string value of `${input:PlanPurpose}` (do not infer or rewrite meaning).  
   1.2. Derive `PURPOSE_PREFIX` by mapping `PLAN_PURPOSE_RAW` to exactly one of:
   - `upgrade|refactor|feature|data|infrastructure|process|architecture|design`
     1.3. If `PLAN_PURPOSE_RAW` already starts with one of the allowed prefixes followed by `:` or `-`, then set `PURPOSE_PREFIX` to that prefix.  
     1.4. Else set `PURPOSE_PREFIX` = `feature` (deterministic default).
     1.5. Derive `COMPONENT_SLUG`:
   - Lowercase
   - Replace spaces and underscores with hyphens
   - Remove all characters except `a-z`, `0-9`, and `-`
   - Collapse consecutive hyphens to a single hyphen
   - Trim leading/trailing hyphens
     1.6. If `COMPONENT_SLUG` becomes empty after sanitization, set `COMPONENT_SLUG` = `system` (deterministic default).
     1.7. Set `VERSION_INT` = `1` unless `${input:PlanPurpose}` contains a trailing explicit version token of form `vN` or `#N` (where `N` is a positive integer). If present, set `VERSION_INT` = that integer.
     1.8. Set `DATE_CREATED` = current execution date in `YYYY-MM-DD`.
     1.9. Set `LAST_UPDATED` = `DATE_CREATED`.
     1.10. Set `OWNER` = `AI` unless `${input:PlanPurpose}` contains an explicit owner tag of form `owner:<value>`; if present use `<value>` verbatim.
     1.11. Set `STATUS` = `Planned`.
     1.12. Set `STATUS_COLOR` using exact mapping:
   - `Completed` -> `brightgreen`
   - `In progress` -> `yellow`
   - `Planned` -> `blue`
   - `Deprecated` -> `red`
   - `On Hold` -> `orange`

2. **Compute Output Path and Filename**
   2.1. Construct `FILENAME` = `[PURPOSE_PREFIX]-[COMPONENT_SLUG]-[VERSION_INT].md`  
   2.2. Construct `OUTPUT_PATH` = `/plan/` + `FILENAME`  
   2.3. The final answer MUST be the full Markdown file contents intended to be saved at `OUTPUT_PATH`. Do not output anything else.

3. **Generate Valid Markdown Using Mandatory Template**
   3.1. Emit YAML front matter with ALL required fields present and properly formatted:
   - `goal`: concise title describing the implementation goal, derived from `PLAN_PURPOSE_RAW` but sanitized to a short title (max 80 chars).
   - `version`: set to `VERSION_INT` as a string, or `DATE_CREATED` if version is unavailable (here it is always available).
   - `date_created`: `DATE_CREATED`
   - `last_updated`: `LAST_UPDATED`
   - `owner`: `OWNER`
   - `status`: `STATUS` (must be exactly one of the allowed values)
   - `tags`: an explicit YAML list (e.g., `[feature, process]`) containing at minimum `PURPOSE_PREFIX`
     3.2. Emit the exact section headers specified in the template, matching case and numbering exactly:
   - `# Introduction`
   - `## 1. Requirements & Constraints`
   - `## 2. Implementation Steps`
   - `## 3. Alternatives`
   - `## 4. Dependencies`
   - `## 5. Files`
   - `## 6. Testing`
   - `## 7. Risks & Assumptions`
   - `## 8. Related Specifications / Further Reading`
     3.3. In `# Introduction`, include the status badge line exactly:
   - `![Status: <status>](https://img.shields.io/badge/status-<status>-<status_color>)`
     Replace `<status>` with `STATUS` and `<status_color>` with `STATUS_COLOR`.
     3.4. **No placeholders permitted**: remove all bracketed placeholder text from the template and replace with concrete, explicit content. If true values are unknown, use `N/A` and make the task explicitly about discovery in Phase 1.

4. **Populate Requirements & Constraints Deterministically**
   4.1. Create at minimum:
   - 3 functional requirements (`REQ-001`..)
   - 2 security requirements (`SEC-001`..)
   - 2 constraints (`CON-001`..)
   - 2 guidelines (`GUD-001`..)
   - 1 pattern (`PAT-001`..)
     4.2. Each requirement must:
   - Be testable
   - Include an explicit measurable condition (e.g., “must return exit code 0”, “must contain file X”, “must include table column Y”)
     4.3. If the plan purpose lacks domain details, set requirements to govern the plan’s own structure and execution (template compliance, deterministic naming, verifiable checks), and add discovery tasks to fill domain gaps.

5. **Create Phases With Atomic, Parallelizable Tasks**
   5.1. Create exactly 3 phases:
   - `### Implementation Phase 1` (Discovery & Scoping)
   - `### Implementation Phase 2` (Implementation)
   - `### Implementation Phase 3` (Validation & Hardening)
     5.2. For each phase, include:
   - A `GOAL-00X` line that is specific and measurable.
   - A Markdown table with columns exactly: `Task | Description | Completed | Date`
     5.3. Create exactly 6 tasks per phase (`TASK-001`..`TASK-018` total).
     5.4. Task rules (strict):
   - Each `Description` MUST include:
     - Explicit file paths (absolute-from-repo style, e.g., `/src/...`, `/plan/...`)
     - Explicit symbols: function names, command names, or identifiers where applicable
     - Explicit completion criteria that can be checked automatically
   - If real repo paths are unknown, use a deterministic default structure:
     - `/src/`
     - `/tests/`
     - `/docs/`
     - `/plan/`
       and ensure Phase 1 includes tasks to confirm/adjust these paths.
   - Mark `Completed` empty for all tasks (no checkmarks) because `STATUS=Planned`.
   - `Date` cell must be empty for incomplete tasks.
     5.5. Dependency handling:
   - Tasks within a phase are parallel unless a dependency is explicitly stated in the Description using the exact token `DEPENDS_ON: TASK-XXX`.
   - Cross-phase dependencies are allowed but must be explicit with `DEPENDS_ON`.
     5.6. Include at least:
   - 2 tasks that produce or modify files under `/plan/`
   - 2 tasks that produce or modify files under `/src/`
   - 2 tasks that produce or modify files under `/tests/`

6. **Populate Alternatives, Dependencies, Files, Testing, Risks**
   6.1. `## 3. Alternatives`: list exactly 2 alternatives (`ALT-001`, `ALT-002`) with clear rejection reasons.
   6.2. `## 4. Dependencies`: list at least 2 dependencies (`DEP-001`, `DEP-002`). If unknown, use `N/A` but include a deterministic discovery dependency like “confirm runtime/toolchain version”.
   6.3. `## 5. Files`: list at least 8 file entries (`FILE-001`..`FILE-008`) with:
   - path
   - purpose
   - change type (create/modify/delete)
     6.4. `## 6. Testing`: list at least 5 tests (`TEST-001`..`TEST-005`) with:
   - test type (unit/integration/e2e/lint/typecheck)
   - exact command to run (deterministic defaults acceptable, e.g., `npm test`, `pytest`, `pnpm test`)
   - pass/fail criteria
     6.5. `## 7. Risks & Assumptions`: list at least 3 risks and 2 assumptions with mitigations.

7. **Template Compliance Validation (Self-Check Before Output)**
   7.1. Verify all required headers exist exactly and in order.
   7.2. Verify front matter contains all required keys.
   7.3. Verify all identifiers use required prefixes (`REQ-`, `SEC-`, `CON-`, `GUD-`, `PAT-`, `GOAL-`, `TASK-`, `ALT-`, `DEP-`, `FILE-`, `TEST-`, `RISK-`, `ASSUMPTION-`).
   7.4. Verify there is no bracketed placeholder text remaining.
   7.5. Verify each task description contains at least one explicit path and one explicit verification criterion.
   7.6. If any check fails, revise content until all checks pass.

## Constraints & Standards

- **Output:** A single valid Markdown document (with YAML front matter) representing the plan file contents for saving at `OUTPUT_PATH`.
- **Style:** Deterministic, unambiguous, machine-executable wording. No rhetorical language. No open-ended questions. Use `N/A` for unknowns and add explicit discovery tasks.
- **Anti-Hallucination:** Do not invent repository-specific facts (existing files, line numbers, function names) unless provided. If unknown, use deterministic defaults and discovery tasks to confirm.
