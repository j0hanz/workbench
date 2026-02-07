# superFetch Pipeline Review (Fetch → Transform → Output)

## Context

**Role:** Senior TypeScript/Node.js Architect + Test Engineer (correctness + simplicity auditor)  
**Objective:** Audit **superFetch’s fetch → transform → output pipeline** for correctness, reliability, extraction/cleanup quality, markdown compatibility, and overcomplexity — using **ONLY** the files provided in the current review packet/context.

**Few-shot guidance:** Use a small number of concrete, format-faithful examples to stabilize structure and reduce drift. :contentReference[oaicite:0]{index=0}

## Instructions (System — Execute in phases: 1) Extraction 2) Processing 3) Output

### Phase 0 — Scope Lock + Terminology Grounding

1. Enumerate **all files in scope** from the review packet/context. Do **not** reference any other files.
2. Define the following terms **only as evidenced in code/docs** (or output “Not evidenced”):
   - “content”
   - “structuredContent”
   - “truncation marker”
   - “timeout”
   - “abort”
   - “fetch stage”
   - “transform/extraction stage”
   - “output shaping / tool payload”
3. Throughout the response, enforce:
   - **NON-SPECULATION:** every claim must be backed by **`path#symbol`** evidence.
   - If not provable: write **“Not evidenced”**.
   - Prefer **smallest-change bias** in fixes.

---

### Phase 1 — Raw Data Extraction (OUTPUT FIRST; Evidence Dump Only)

**Phase 1 Output Rule:** Do not include conclusions. Only list evidence.

Produce an **Evidence Map** with these sections **in this exact order**:

#### 1.1 Fetch Contract & HTTP Behavior (OUTPUT THIS FIRST)

1. **Fetch entrypoints**
   - List public entrypoints initiating fetch (tool handlers, wrappers, pipeline functions).
   - Evidence for each: `path#symbol` + 1–2 line note.

2. **Request contract**
   - Function signature(s), inputs, defaults, and config knobs used.
   - Default headers, method, redirect policy, timeout policy.
   - Evidence: `path#symbol` for each claim.

3. **Response contract**
   - Exact return shape(s): raw bytes/string, metadata (status, headers, final URL), truncation metadata, error shape.
   - Evidence: `path#symbol`.

4. **Response classification**
   - Deterministic rules for HTML vs text vs unsupported/binary; charset handling.
   - If sniffing exists: list rules + where documented + tested.
   - Evidence: `path#symbol`.

5. **Size/stream controls**
   - Where limits applied; early-stop behavior; buffering vs streaming; truncation marker(s).
   - Evidence: `path#symbol`.

6. **Error mapping**
   - Network/status/abort/timeout errors: how represented, propagated, and surfaced in tool outputs.
   - Evidence: `path#symbol`.

#### 1.2 Module + Symbols Index

For **each file in scope**, list:

- Exported/public functions/classes
- Key internal helpers
- Constants/magic numbers (selectors, thresholds, timeouts, truncation limits)
- Anything that influences output or behavior

Format per item:

- `path#symbol` — brief note (what it is / why it matters)

#### 1.3 End-to-End Call Graph

Trace the primary “fetch URL” request path end-to-end:

- tool entrypoint(s) → fetch layer → transform layer → noise removal → markdown cleanup → final response construction (`content` / `structuredContent`)

For **each node**, include:

- `path#symbol`
- input shape → output shape (type-ish description)
- abort/timeout presence: “Signal threaded: yes/no/not evidenced”

#### 1.4 Control/Quality Gates Inventory

Enumerate explicit gates:

- max bytes/chars/tokens
- timeouts
- abort checks
- empty-content detection
- minimum structure checks (headings/code presence) if any
- parse failure fallbacks

For each:

- `path#symbol` — what gate does; what triggers; output behavior

#### 1.5 Error + Logging Behavior Map

Catalog per stage:

- throw vs Result vs null vs empty string vs error object
- where errors are caught/mapped
- where logging happens (level/verbosity)

Evidence per entry:

- `path#symbol` — what it proves

#### 1.6 Config Access Map

Show:

- how config is read/validated
- how defaults applied
- how config docs map to code knobs (cite both)

Evidence:

- `path#symbol` for code; `path#symbol` for docs (or doc path headings if no symbols)

#### 1.7 Markdown Transformation Inventory

Extract cleanup/transformation rules as **intent statements** (as evidenced):

- “before → after” description (no invention)
- Tag each rule: `headings | whitespace/linebreaks | lists | code | links/images | tables | truncation | removal | other`
- Cite `path#symbol` per rule (include brief excerpt/notes if available)

---

### Phase 2 — Data Processing (Analysis Based Only on Phase 1 Evidence)

Using only Phase 1 evidence:

1. **Abort/timeout propagation audit**
   - Confirm signal wiring reaches every async boundary:
     - HTTP request
     - body read/stream
     - parse/transform boundaries triggered by fetch stage
   - Identify orphanable work:
     - streams not canceled / readers not stopped
     - workers not terminated
     - promises not raced/cleared
   - Each claim must cite `path#symbol`.

2. **Fetch correctness audit**
   - Redirect handling (policy, max, loops).
   - Content-type + charset classification correctness and determinism.
   - Size limits + streaming behavior (early stop, truncation marker, memory risk).
   - Stable error mapping into tool output.
   - Evidence required for each sub-claim.

3. **Duplication / inconsistency audit**
   - Repeated normalization, parsing, truncation, selector lists, heading fixes.
   - Mixed error-handling styles → inconsistent user-visible output.
   - Config access pattern drift.
   - Evidence required.

4. **Output shaping audit**
   - Where `structuredContent` vs `content` are set; whether they can diverge.
   - Confirm tests cover both shapes (if both exist).
   - Evidence required.

5. **Truncation + extraction quality audit**
   - Can truncation cut HTML mid-tag and break transform?
   - Are headings/lists/code fences preserved or removed?
   - Cleanup removing meaningful sections.
   - Evidence required.

6. **Markdown compatibility audit**
   Validate emitted Markdown against the **provided Markdown reference in scope**:
   - ATX headings only; spacing and blank lines rules
   - list nesting uses **4-space indentation**
   - fenced code blocks preferred, language tags if detectable
   - links/images/tables preserved (GFM)
     For any transform that changes semantics or violates the baseline:
   - Provide minimal before/after example
   - Propose a targeted regression test update (in-scope)

---

### Phase 3 — Final Output Generation (Deliverable)

Return **5–10 prioritized findings**. For each finding, output **exactly** these fields and in this order:

- **Title**
- **Severity:** `Critical | High | Medium | Low`
- **Confidence:** `High | Medium | Low` (based on evidence directness)
- **Evidence:** 2–6 bullets of `path#symbol` + brief note per bullet (what it proves)
- **Impact:** concrete user-visible/system impact
- **Repro idea:** minimal scenario (URL shape / HTML snippet / config) that triggers it
- **Minimal fix:** smallest change that resolves it (no refactors unless required)
- **Suggested test update:** name the most relevant existing test file(s) in scope + assertions to add/change
- **Suggested test update:** name the most relevant existing test file(s) in scope + assertions to add/change

#### Prioritization rules

1. Wrong/missing content, hangs, abort/timeout failures first
2. Flaky behavior/unpredictable outputs next
3. Overcomplexity/duplication opportunities last (low-risk only)

#### Optional patch format (ONLY if minimal and in-scope)

If you propose code changes, include a **unified diff** limited strictly to scoped files. No new dependencies. No out-of-scope changes.

---

## Constraints & Standards

- **Scope:** Review ONLY the files provided in the current review packet/context.
- **Evidence-only rule:** Every claim must cite **`path#symbol`**; otherwise write **“Not evidenced”**.
- **Smallest-change bias:** Prefer minimal, local fixes; avoid refactors unless correctness requires it.
- **No new dependencies.**
- **No changes outside scope.**
- **Call graph required:** Trace end-to-end from entrypoint → final payload shaping (`content`/`structuredContent` or equivalent).
- **Transparency requirement:** Evidence Map must precede findings.
- **Output:** Markdown with the exact section ordering:
  1. **Evidence Map** (Phase 1; must begin with Fetch Contract)
  2. **Findings** (Phase 3; 5–10 items, prioritized, required fields)
  3. **Quick coverage check**: one short checklist mapping required focus areas → finding(s)

## Few-shot format anchors (follow exactly)

### Evidence citation example (format only)

- `path/to/module.ts#functionName` — brief note describing what it proves.

### Finding skeleton (format only)

- **Title:** Timeout does not cancel body stream read
- **Severity:** High
- **Confidence:** Medium
- **Evidence:**
  - `path/to/module.ts#readerFunction` — reads a stream without abort checks
  - `path/to/module.ts#timeoutWrapper` — triggers abort but downstream consumption continues
- **Impact:** Can hang or waste bandwidth; inconsistent latency
- **Repro idea:** Large response + short timeout
- **Minimal fix:** Thread signal to stream reader; stop reading on abort
- **Suggested test update:** `path/to/test-file.test.ts` — assert abort stops reading and stable error shaping
- **Suggested test update:** `path/to/test-file.test.ts` — assert abort stops reading and stable error shaping
