---
description: Deep analysis sweep of a domain or theme — finds bugs/security/perf/quality issues, emits a verified remediation plan
argument-hint: <domain | free-text context>
---

# Sweep

Deep analysis sweep across a slice of this codebase. Finds bugs, security issues, performance problems, code-quality violations, and architecture concerns — then generates a verified, prioritized remediation plan.

The slice can be a **domain** (a bounded context that maps to modules/packages) **or** any **free-text context/theme** ("race conditions in the payment writers", "everything that touches the public API surface", "error handling across background jobs").

## Usage

```
/sweep <domain | free-text context>
```

**Examples:** `/sweep auth`, `/sweep billing`, `/sweep race conditions in the payment writers`, `/sweep anything that reads from the legacy cache`

## Instructions

You are running a sweep. Follow every step of the sweep prompt at `.claude/prompts/sweep.md` exactly.

### Input

```
$ARGUMENTS
```

If `$ARGUMENTS` is empty, ask the user what to sweep — suggest top-level modules/packages (see `.claude/CONTEXT_MAP.md`) for a domain sweep, or accept a free-text theme.

### Resolve the scope

Decide which of two modes you're in:

- **Domain mode** — `$ARGUMENTS` is a single short token (one word, no spaces) that names
  or maps to a module/package. Set `$SCOPE = lowercased token`, `$LABEL = $SCOPE`,
  `$CONTEXT = ""` (the domain name is the whole scope).
- **Context mode** — `$ARGUMENTS` is free text / a described theme (multiple words, or a
  token that matches no module). Set `$CONTEXT = $ARGUMENTS` (verbatim — this drives the
  sweep), then **ask the user for a short kebab-case label** for the output directory
  (suggest one derived from the text, e.g. "race conditions in the payment writers" →
  `payment-writer-races`). Set `$LABEL` to their answer (slugified). The full `$CONTEXT`
  text is what gets analyzed; `$LABEL` only names the folder.

### Execution

1. Pass `$LABEL` and `$CONTEXT` to the sweep prompt. In domain mode `$CONTEXT` is empty and
   `$LABEL` is the domain name; the prompt treats `$LABEL` as `$DOMAIN`.
2. Follow `.claude/prompts/sweep.md` phases 0 through 10 in order.
3. Output directory is `.claude/sweep/$LABEL/` (create it fresh; if it already exists from a prior sweep, warn the user and ask whether to overwrite or create a timestamped variant like `.claude/sweep/$LABEL-2/`).

### Parallelization strategy

Use the agent orchestration protocol (`.claude/rules/workflow.md`):

- **Phase 1 (orientation):** a single agent reads the project layout and maps the scope (the domain's modules, or every file relevant to the free-text context).
- **Phases 3–7 (analysis passes):** launch up to 5 parallel `sweep-analyzer` agents — one per pass (bugs, performance, security, code quality, architecture). Each writes to its own subdirectory, so there are no file conflicts.
- **Phase 8 (verification):** a single fresh `sweep-reviewer` agent reads all findings and annotates verdicts.
- **Phase 9 (task generation):** generate the remediation plan from confirmed findings.

### Quality gates

- Every finding file must include a `## Confidence` field (HIGH / MEDIUM / LOW).
- The reviewer agent must cite specific code or docs in every verdict — no hand-waving.
- False positives must be explicitly dismissed with reasoning, not silently deleted.
- The final task plan must have strictly disjoint file ownership between subtasks.

### What this command does NOT do

- It does NOT modify production code.
- It does NOT run tests or linters (those are verification tools, not analysis).
- It does NOT create PRs or commits.
- It produces analysis artifacts only. Implementation is a separate step.

### Deliverables

When complete, the user will have:

```
.claude/sweep/$LABEL/
  bugs/BUG-001_*.md, BUG-002_*.md, ...
  performance/PERF-001_*.md, ...
  security/SEC-001_*.md, ...
  code_quality/CQ-001_*.md, ...
  architecture/ARCH-001_*.md, ...
  raw_notes/
    00_project_orientation.md
    01_domain_map.md
    02_reviewer_summary.md

.claude/tasks/$LABEL-sweep-remediation/
  MASTER_TASKS.md
  001-*.md, 002-*.md, ...
```

Plus an updated `.claude/tasks/MASTER_PLAN.md` with the remediation feature set as Active.
