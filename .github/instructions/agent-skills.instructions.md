---
description: "Guidelines for creating high-quality Agent Skills for GitHub Copilot"
applyTo: "**/.github/skills/**/SKILL.md, **/.claude/skills/**/SKILL.md"
---

# Agent Skill: Agent-Skill Authoring Toolkit

## Context

**Role:** GitHub Copilot Agent Skill Author + Repository Tooling Architect  
**Objective:** Create a complete, portable Agent Skill folder that teaches Copilot how to author _other_ Agent Skills correctly. The skill must codify the provided “Agent Skills File Guidelines” into an actionable workflow (checklists, templates, examples, and optional scripts) so Copilot can reliably generate new skills on demand.

## Instructions (System)

1. **Extraction (spec → requirements)**
   - Extract and normalize all MUST/SHOULD rules from the provided guidelines into a concise “Rules of the Road” section.
   - Identify the minimum required deliverables:
     - `.github/skills/<skill-name>/SKILL.md` with required YAML frontmatter
     - Optional: `LICENSE.txt`, `references/`, `templates/`, `scripts/`, `assets/`
   - Convert “description best practices” into a repeatable rubric + heuristic checklist Copilot can apply.

2. **Processing (design the skill)**
   - Define the skill’s **own** frontmatter (`name`, `description`, optional `license`) using the rules:
     - `name`: lowercase, hyphenated, ≤64 chars
     - `description`: ≤1024 chars; must include WHAT + WHEN + KEYWORDS for discovery triggers
   - Write `SKILL.md` body in imperative style with the recommended sections:
     - Title/Overview
     - When to Use This Skill (explicit triggers and keywords)
     - Prerequisites
     - Step-by-Step Workflows (at least 2 complete workflows)
     - Troubleshooting (table)
     - References (relative links)
   - Bundle resources:
     - Put long workflows (>5 steps) into `references/` and link them from `SKILL.md`
     - Provide at least one editable scaffold in `templates/` (e.g., `skill-scaffold/` containing a starter `SKILL.md` and empty folders)
     - Provide at least one static asset example in `assets/` (e.g., `report-template.md` used as-is)
     - Provide at least one script in `scripts/` (cross-platform preferred) that validates a skill folder (frontmatter presence, name rules, description length, folder layout). Include `--help` behavior and clear error messages.
   - Integrate a **few-shot prompting** section that teaches how to embed examples when generating new skills, using the bundled reference file:
     - Reference file path: `/mnt/data/Few-Shot-guide.md`
     - Summarize key tactics into a short checklist (2–5 examples, diverse, positive+negative, ordering/recency, keep under 8 examples).

3. **Output (emit repository-ready artifacts)**
   - Output a repository-ready file tree plus full contents for each file:
     - `.github/skills/agent-skill-authoring/`
       - `SKILL.md` (complete)
       - `LICENSE.txt` (Apache 2.0 placeholder text + instruction to paste official license; include “appendix owner/year” TODO)
       - `references/`
         - `authoring-workflow.md` (detailed workflow >5 steps)
         - `description-rubric.md` (rubric + examples: good vs poor)
         - `few-shot-primer.md` (derived from `/mnt/data/Few-Shot-guide.md`, concise)
       - `templates/`
         - `skill-scaffold/` (starter structure for new skills, including a parameterized `SKILL.md` template)
       - `scripts/`
         - `validate-skill.py` (or `validate-skill.ts`), with usage, exit codes, and checks
       - `assets/`
         - `skill-report-template.md` (static, used as-is)
   - Ensure all internal references in markdown use **relative paths** (e.g., `./references/authoring-workflow.md`).

## Constraints & Standards

- **Output:** Markdown containing:
  1. A file tree, then
  2. Each file labeled with its path and full content in fenced code blocks.
- **Style:** Imperative, specific, scannable. Commands must include parameters and expected outcomes where helpful.
- **Anti-Hallucination:** Do not invent external facts. If something is unspecified, write `"unknown"` or add a clear `TODO`.
- **Discovery-critical:** The skill’s `description` must include explicit triggers, scenarios, and keywords so Copilot loads it automatically.
- **Portability:** Prefer cross-platform scripting; no secrets; use relative paths.
- **Size hygiene:** Keep `SKILL.md` under 500 lines; move longer content to `references/`.

## Related Resources

- [Agent Skills Specification](https://agentskills.io/)
- [VS Code Agent Skills Documentation](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- [Reference Skills Repository](https://github.com/anthropics/skills)
- [Awesome Copilot Skills](https://github.com/github/awesome-copilot/blob/main/docs/README.skills.md)
