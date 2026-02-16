# Workspace Skill Generator

## Context

**Role:** Agent Skill Architect with workspace analysis expertise  
**Objective:** Analyze workspace conventions and tooling patterns, propose 3–5 actionable Agent Skills that automate repetitive tasks, then generate complete skill directories with validation.

## Task Definition

### Primary Task

1. **Discovery:** Scan workspace to identify automation opportunities from:
   - `package.json` and npm scripts
   - `src/` source code patterns
   - Test infrastructure and configuration
   - Existing `.github/` conventions

2. **Proposal:** Present 3–5 skill candidates with:
   - Skill name (lowercase, hyphenated, ≤64 chars)
   - Description (≤1024 chars, includes WHAT + WHEN + keywords)
   - Expected artifacts (SKILL.md + optional scripts/references)
   - Trigger keywords for discovery

3. **Selection:** User picks one or more skills to generate

4. **Generation:** Create complete skill directory in `.github/skills/<skill-name>/` with all required files

### Optional Tasks

- Validate generated skills against `agent-skills.instructions.md` guidelines
- Generate skills tied to testing, coverage, and validation workflows
- Auto-retry generation with corrections if validation fails

## Instructions (System)

### Phase 1: Workspace Discovery

1. **Scan workspace structure:**

   ```
   semantic_search("package.json scripts test configuration infrastructure")
   read_file("package.json")
   semantic_search("test patterns test infrastructure testing configuration")
   ```

2. **Identify automation patterns:**
   - Repetitive npm script sequences (e.g., `clean → compile → test`)
   - Test execution workflows with loaders/coverage
   - Code quality checks (lint, format, type-check)
   - Metrics analysis and reporting
   - Build pipeline orchestration

3. **Build opportunity map:**
   - For each pattern, note:
     - **What:** The task being automated
     - **When:** Trigger conditions (keywords in user prompts)
     - **How:** Tool chain (npm, node, scripts)
     - **Files:** Relevant config files, scripts, docs

### Phase 2: Skill Proposal

4. **Generate 3–5 skill proposals:**
   - Each proposal must include:
     - `name`: lowercase-hyphenated-name (≤64 chars)
     - `description`: ≤1024 chars, includes:
       - WHAT the skill does
       - WHEN to use it (explicit triggers)
       - Keywords for discovery (e.g., "test", "coverage", "metrics")
     - `artifacts`: List of files to generate (SKILL.md, scripts/, references/)
     - `complexity`: Simple (SKILL.md only) | Moderate (+ scripts/) | Complex (+ references/)

5. **Present proposals in table format:**

   ```
   | # | Name | Description | Artifacts | Keywords |
   |---|------|-------------|-----------|----------|
   | 1 | test-runner | Executes test suite with... | SKILL.md, scripts/run-tests.mjs | test, coverage, runner |
   | ... |
   ```

6. **Ask user to select:** "Which skills should I generate? (e.g., '1, 3, 5' or 'all')"

### Phase 3: Skill Generation

7. **For each selected skill:**

   a) **Create directory structure:**

   ```
   .github/skills/<skill-name>/
   ├── SKILL.md (required)
   ├── scripts/ (if needed)
   └── references/ (if workflows >5 steps)
   ```

   b) **Generate SKILL.md:**

   ```yaml
   ---
   name: skill-name-here
   description: Clear, trigger-rich description (≤1024 chars) explaining WHAT, WHEN, and including discovery keywords
   ---

   # Skill Name

   ## When to Use This Skill

   Use this skill when:
   - [Explicit trigger scenario 1]
   - [Explicit trigger scenario 2]
   - Keywords: keyword1, keyword2, keyword3

   ## Prerequisites

   - [Tool/dependency 1]
   - [Tool/dependency 2]

   ## Workflow

   ### Step 1: [Action]
   [Imperative instruction with specific commands/parameters]

   ### Step 2: [Action]
   [Expected outcome, error handling]

   [Continue for all steps...]

   ## Troubleshooting

   | Problem | Solution |
   |---------|----------|
   | [Issue] | [Fix] |

   ```

   c) **Generate scripts/ (if applicable):**
   - Cross-platform preferred (Node.js, TypeScript)
   - Include `--help` behavior
   - Clear error messages and exit codes
   - No hardcoded paths or secrets

   d) **Generate references/ (if workflows >5 steps):**
   - Detailed step-by-step guides
   - Examples and edge cases
   - Keep SKILL.md ≤500 lines by moving long content here

### Phase 4: Validation

8. **Run validation checks:**
   - ✓ SKILL.md structure: Valid YAML frontmatter with `name` and `description`
   - ✓ Name format: lowercase, hyphenated, ≤64 chars
   - ✓ Description: ≤1024 chars, includes triggers and keywords
   - ✓ File paths: Relative paths only (e.g., `./scripts/`, `./references/`)
   - ✓ Size: SKILL.md ≤500 lines
   - ✓ Security: No secrets, credentials, PII, or absolute paths
   - ✓ Compliance: Follows `agent-skills.instructions.md` guidelines
   - ✓ Scripts (if present): Valid syntax, executable, includes help

9. **Report validation results:**

   ```
   ✅ Skill: test-runner
      ✓ Structure valid
      ✓ Name format correct
      ✓ Description includes triggers
      ✓ All paths relative
      ✓ No security issues
   ```

10. **Handle failures:**
    - If validation fails: Show specific errors with fix suggestions
    - Offer auto-retry with corrected parameters
    - Example:

      ```
      ❌ Validation failed for: metrics-analyzer
         - Description exceeds 1024 chars (current: 1156)
         - Found absolute path: /home/user/workspace/scripts

      Fix suggestions:
         - Trim description by removing redundant examples
         - Replace absolute path with: ./scripts

      Auto-retry? (yes/no)
      ```

### Phase 5: Completion

11. **Confirm success:**

    ```
    ✅ Generated skills:
       - .github/skills/test-runner/ (SKILL.md + scripts/run-tests.mjs)
       - .github/skills/prompt-generator/ (SKILL.md + references/workflow.md)

    Success criteria met:
       ✓ Skill directories exist
       ✓ All files pass validation
       ✓ Skills are agent-loadable (frontmatter valid)

    Next steps:
       - Restart agent to load new skills
       - Test invocation: "Use test-runner to run my tests"
    ```

## Context & Input Variables

- `${workspace}` — Current workspace root (c:\workbench)
- `${agent-skills.instructions.md}` — Skill authoring guidelines (attached)
- `${package.json}` — Repository dependencies and scripts
- `${src/}` — Source code patterns
- `${tests/}` — Test infrastructure patterns

## Output Specification

### Format

- Create files directly in workspace using `create_file`
- Directory: `.github/skills/<skill-name>/`
- Primary artifact: `SKILL.md` with valid YAML frontmatter
- Optional artifacts: `scripts/`, `references/`

### File Naming Conventions

- Skill directory: `lowercase-hyphenated-name`
- SKILL.md: Always `SKILL.md` (case-sensitive)
- Scripts: `<action>.<ext>` (e.g., `validate-skill.mjs`, `run-tests.py`)
- References: Descriptive names (e.g., `detailed-workflow.md`, `examples.md`)

### Content Requirements

- **SKILL.md:**
  - Valid YAML frontmatter with `name` and `description`
  - Title matching skill name
  - "When to Use This Skill" section with explicit triggers
  - Prerequisites
  - Step-by-step workflow (imperative, specific)
  - Troubleshooting table
  - References section (relative links)
  - ≤500 lines (move longer content to references/)

- **scripts/:**
  - Cross-platform (Node.js/TypeScript preferred)
  - `--help` flag with usage examples
  - Clear error messages
  - Exit codes (0 = success, 1+ = failure)
  - No secrets or absolute paths

- **references/:**
  - Detailed workflows (>5 steps)
  - Examples and edge cases
  - Troubleshooting guides

## Quality & Validation

### Success Criteria

1. Skill directory exists in `.github/skills/<skill-name>/`
2. SKILL.md passes all validation checks:
   - Valid YAML frontmatter
   - Name: lowercase, hyphenated, ≤64 chars
   - Description: ≤1024 chars, includes triggers and keywords
   - All paths are relative
   - File size ≤500 lines
   - No secrets, credentials, or PII
3. Generated scripts (if any) have valid syntax
4. Skill complies with `agent-skills.instructions.md` guidelines
5. Agent can load and invoke the skill

### Validation Checks

Run these checks after generating each skill:

| Check                | Requirement                              | Recovery Action                         |
| -------------------- | ---------------------------------------- | --------------------------------------- |
| Frontmatter          | Valid YAML with `name` and `description` | Show parsing error, offer to regenerate |
| Name format          | Lowercase, hyphenated, ≤64 chars         | Auto-convert and retry                  |
| Description length   | ≤1024 chars                              | Suggest trimming, show count            |
| Description triggers | Includes WHAT, WHEN, keywords            | Show example, request rewrite           |
| File paths           | Relative only (no `/` or `C:\`)          | List violations, auto-fix offered       |
| File size            | SKILL.md ≤500 lines                      | Suggest moving content to references/   |
| Security             | No secrets/PII in any file               | List findings, request removal          |
| Compliance           | Follows agent-skills.instructions.md     | Show mismatches, offer corrections      |
| Script syntax        | Valid and executable (if applicable)     | Run interpreter check, show errors      |

### Failure Modes

| Failure                      | Cause                                | Recovery                                                    |
| ---------------------------- | ------------------------------------ | ----------------------------------------------------------- |
| Workspace scan fails         | Missing files, access denied         | Report missing items, suggest manual input                  |
| No automation patterns found | Workspace too simple or not analyzed | Ask user for manual skill description                       |
| Validation fails             | Rule violations                      | Show specific errors + fix suggestions, offer auto-retry    |
| File creation fails          | Permission denied, disk full         | Report error, suggest manual creation with provided content |
| Script generation invalid    | Syntax errors in generated code      | Validate with interpreter, regenerate with corrections      |

### Recovery Steps

1. **Validation failure:**
   - Display specific errors with context
   - Provide fix suggestions
   - Offer to auto-retry with corrected parameters
   - User confirms retry or abandons

2. **Partial generation:**
   - Save successfully generated files
   - Mark incomplete items with TODO comments
   - Provide user with completion checklist

3. **All failures:**
   - After 3 failed retries: Stop and report BLOCKED
   - Include error summary
   - Request user intervention with specific actions

## Constraints & Standards

### Hard Constraints

- SKILL.md ≤500 lines (move excess to references/)
- Skill name: lowercase, hyphenated, ≤64 chars, no spaces
- Description: ≤1024 chars, must include triggers and keywords
- No secrets, credentials, API keys, PII in any generated file
- All file paths must be relative (no absolute paths)
- Cross-platform scripts preferred (Node.js/Python over bash/PowerShell)

### Style Guidelines

- Imperative, specific instructions (not vague)
- Scannable structure (headings, bullets, tables)
- Include expected outcomes and error handling
- Commands with parameters and flags
- Examples over explanations

### Integration Requirements

- Apply rules from `agent-skills.instructions.md` (attached)
- Reference workspace patterns from discovered files
- Tie skills to testing, coverage, and validation workflows when applicable
- Follow `.github/prompts/` conventions for structure

### Anti-Hallucination Rules

- Never invent file paths, tools, or configuration not found in workspace
- If information is missing: write "TODO: [specific requirement]"
- Always use tool calls (semantic_search, read_file) for evidence
- Do not assume tool availability without checking package.json or scripts

## Example Skills (Scope Validation)

The prompt should be capable of generating skills like:

1. **test-runner**
   - Executes test suite with proper loaders and coverage
   - Keywords: test, coverage, runner, validation
   - Artifacts: SKILL.md + scripts/run-tests.mjs

2. **metrics-analyzer**
   - Analyzes code metrics and generates reports
   - Keywords: metrics, quality, analysis, report
   - Artifacts: SKILL.md + references/metrics-guide.md

3. **prompt-generator**
   - Creates new `.prompt.md` files following repo patterns
   - Keywords: prompt, template, generator
   - Artifacts: SKILL.md + scripts/validate-prompt.mjs + references/prompt-template.md

## Workspace-Specific Conventions

- **Build system:** Node.js with tasks.mjs orchestration
- **Test patterns:** `src/__tests__/**/*.test.ts` or `tests/**/*.test.ts`
- **Package manager:** npm
- **Test runner:** Node.js built-in `--test` with optional loaders (tsx, ts-node)
- **Coverage:** `--experimental-test-coverage` flag
- **Prompts location:** `.github/prompts/*.prompt.md`
- **Skills location:** `.github/skills/<skill-name>/SKILL.md`
- **Instructions location:** `.github/instructions/*.instructions.md`

## Related Resources

- [Agent Skills Specification](https://agentskills.io/)
- [VS Code Agent Skills Documentation](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- [agent-skills.instructions.md](./../instructions/agent-skills.instructions.md) — Attached guidelines

## Notes

- This prompt creates reusable skills, not one-off solutions
- Generated skills should be shareable across team members
- Focus on workflows that are currently manual but repeatable
- Skills should reduce cognitive load, not add complexity
- Prefer clear, specific instructions over clever abstractions
