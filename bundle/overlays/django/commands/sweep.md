# Domain Sweep

Deep analysis sweep across a domain in this codebase. Finds bugs, security issues, performance problems, code quality violations, and architecture concerns — then generates a verified, prioritized remediation plan.

## Usage

```
/sweep <domain>
```

**Examples:** `/sweep auth`, `/sweep game`, `/sweep elearning`, `/sweep notifications`

The `<domain>` argument is the bounded context to inspect. It maps to one or more Django apps.

## Instructions

You are running a domain sweep. Follow every step of the sweep prompt at `.claude/prompts/sweep.md` exactly.

### Input

```
$ARGUMENTS
```

If `$ARGUMENTS` is empty, ask the user which domain to sweep. Suggest domains based on the Django apps in `config/settings/apps_middlewares.py` (`PROJECT_APPS`).

### Execution

1. Store `$ARGUMENTS` as `$DOMAIN` (trim whitespace, lowercase).
2. Follow `.claude/prompts/sweep.md` phases 0 through 10 in order.
3. Output directory is `.claude/sweep/$DOMAIN/` (create it fresh; if it already exists from a prior sweep, warn the user and ask whether to overwrite or create a timestamped variant like `.claude/sweep/$DOMAIN-2/`).

### Parallelization strategy

Use the agent orchestration protocol (`.claude/rules/workflow.md`):

- **Phase 1 (orientation):** Single agent reads project layout and maps the domain.
- **Phases 3–7 (analysis passes):** Launch up to 5 parallel agents — one per analysis pass (bugs, performance, security, code quality, architecture). Each agent writes to its own subdirectory, so there are no file conflicts.
- **Phase 8 (verification):** A single fresh review agent reads all findings and annotates verdicts.
- **Phase 9 (task generation):** Generate the remediation plan from confirmed findings.

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
.claude/sweep/$DOMAIN/
  bugs/BUG-001_*.md, BUG-002_*.md, ...
  performance/PERF-001_*.md, ...
  security/SEC-001_*.md, ...
  code_quality/CQ-001_*.md, ...
  architecture/ARCH-001_*.md, ...
  raw_notes/
    00_project_orientation.md
    01_domain_map.md
    02_reviewer_summary.md

.claude/tasks/$DOMAIN-sweep-remediation/
  MASTER_TASKS.md
  001-*.md, 002-*.md, ...
```

Plus an updated `.claude/tasks/MASTER_PLAN.md` with the remediation feature set as Active.
