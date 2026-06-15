# Tasks

Plan, implement, and complete trackable bodies of work. `/tasks` is a small command
router: the first word of `$ARGUMENTS` selects a subcommand; everything after it is
that subcommand's input.

## Usage

```
/tasks pln   [context]            Generate a reviewed implementation plan
/tasks impl  <plan> [rules...]    Implement an existing plan via the orchestrator
/tasks cmplt <plan> [--force]     Mark a plan complete and archive it
```

**Examples:**
- `/tasks pln Add WebSocket presence tracking to game sessions`
- `/tasks pln` (plan from the current session context alone)
- `/tasks impl game-presence stop after each phase`
- `/tasks cmplt game-presence`

### Input

```
$ARGUMENTS
```

### Router

1. Read the **first whitespace-delimited token** of `$ARGUMENTS`, lowercased, as `$SUB`.
2. Treat the remainder (everything after the first token) as `$REST`.
3. Dispatch on `$SUB` matching one of these **exact** tokens:
   - `pln` → **Subcommand: pln**
   - `impl` → **Subcommand: impl**
   - `cmplt` → **Subcommand: cmplt**
   - If `$SUB` is none of these **and** `$ARGUMENTS` is non-empty → treat the **entire**
     `$ARGUMENTS` as `pln` context (back-compat with the old `/tasks <description>` form).
   - If `$ARGUMENTS` is empty → print the Usage block above and stop.

   Only these three exact abbreviations trigger a subcommand — deliberately **not**
   English words like `implement` or `complete`, so a natural description such as
   `/tasks implement the search feature` plans (the safe default) instead of being misread
   as the `impl` subcommand with "the" as a plan name. To implement or complete, use the
   abbreviation: `/tasks impl <plan>`, `/tasks cmplt <plan>`.

---

## Subcommand: pln

Produce a complete, dependency-aware execution plan that maximizes parallelism and
ensures no two subtasks conflict on the same files — then have it independently
reviewed and amended **at least twice** before presenting.

`$REST` (or the whole `$ARGUMENTS` in the back-compat path) is optional planning
context. **Always combine it with the current session context** — decisions, files,
and constraints already established in this conversation are part of the input even
when `$REST` is empty.

### Phase 0 — Understand the work

1. **Parse the input.** Determine the work type:
   - **Feature** — a new capability described in natural language or a spec document.
   - **Remediation** — fixing findings from a sweep (`.claude/sweep/<scope>/`).
   - **Refactor** — restructuring existing code without changing behavior.
   - **Migration** — moving between patterns, versions, or architectures.

2. **Read context.** Before planning, read:
   - `.claude/CONTEXT_MAP.md` — project architecture.
   - `.claude/tasks/MASTER_PLAN.md` — what's already active (avoid conflicts).
   - `.claude/rules/foundations.md` — layering rules and conventions.
   - Any spec documents, sweep findings, or docs referenced in the input.

3. **Clarification gate.** If scope is ambiguous, ask up to 3 targeted questions before
   proceeding. If everything is clear, state your understanding in 2–3 sentences and move on.

### Phase 1 — Delegate plan generation to the `planner` agent

You've done the understanding and clarification in the main loop. Hand the actual
plan-file authoring to the **`planner` agent** — it owns the `MASTER_TASKS.md` template,
the grouping/sizing rules, file-ownership disjointness, and risk tagging (see
`.claude/agents/planner.md`). Keeping the template in one place stops `pln` and the planner
from drifting.

1. **Decide the feature name yourself** — it's the handle `impl`/`cmplt` will use:
   `kebab-case`; for remediations use `<scope>-sweep-remediation`; for features the natural
   short name.
2. **Dispatch the `planner` agent.** Its prompt must include:
   - The work type (feature / remediation / refactor / migration) and a tight scope + goal.
   - **Every decision, constraint, and file already established in Phase 0 / this session**,
     listed explicitly as locked decisions — so the planner does not re-ask what you've
     already settled.
   - The chosen feature name and target directory `.claude/tasks/<feature-name>/`.
   - The discovery it must perform: features → models, services, selectors, controllers,
     serializers, permissions, admin, URLs, migrations + affected files; remediations → read
     the CONFIRMED findings and `raw_notes/02_reviewer_summary.md`; refactors/migrations →
     trace every affected site.
   - A reminder that `MASTER_TASKS.md` **must** contain the machine-readable `## Subtasks`
     bullet list (`- [PENDING] [NNN-slug.md](NNN-slug.md) — title`) — the orchestrator and
     `cmplt` depend on it — and that file ownership must be strictly disjoint.
3. **Read the plan it wrote** (`MASTER_TASKS.md` + numbered subtask files) before reviewing.

### Phase 2 — Independent review (mandatory, ≥2 rounds)

A plan is not presented until it has survived independent review. Do **not** skip this
even if the plan looks complete.

1. **Round 1.** Dispatch the `plan-reviewer` agent at the new feature directory. It reads
   `MASTER_TASKS.md` and every subtask file and returns a structured critique
   (file-ownership conflicts, parallelism, phase ordering, sizing, missing tests/validation,
   active-feature conflicts, self-containedness).
2. **Amend.** Apply every actionable item the reviewer raised — edit `MASTER_TASKS.md` and
   the subtask files directly. Keep the Priority queue and the Subtasks bullet list in sync.
3. **Round 2.** Dispatch a **fresh** `plan-reviewer` agent against the amended plan. Apply
   its actionable items the same way.
4. **Converge.** If round 2 still surfaces material issues, run a third round. Stop once a
   review returns no material issues (minimum two rounds always run).
5. Keep a one-line note per round in the user-facing report (what each round changed). Do
   not pause for the user between rounds — present the final, twice-reviewed plan.

### Phase 3 — Register the plan

1. **Update `.claude/tasks/MASTER_PLAN.md`:**
   - Add the new feature under `## Active` with a link to its `MASTER_TASKS.md`.
   - Include a brief description and "0/N subtasks done".

2. **Report to the user:**
   - Total subtasks created, number of parallel groups, estimated phases.
   - Top-priority subtask(s).
   - What each review round changed.
   - The exact next command: `/tasks impl <feature-name>`.
   - Any open questions or decisions that need user input.

### What pln does NOT do

- It does NOT implement any code changes, create branches/PRs, or modify production code.
- It produces planning artifacts only. Implementation is `/tasks impl`.

### Principles

- **Maximize parallelism.** Every subtask that doesn't depend on another's output belongs in a concurrent group. The dependency graph should be wide, not deep.
- **File ownership is sacred.** If two subtasks could touch the same file, merge them or split the file's changes so each owns a disjoint section.
- **Plans are self-contained.** An agent should be able to pick up any subtask file and execute it without reading the original request or this conversation.
- **No premature abstraction.** Don't create helpers or abstraction layers unless the plan needs them.
- **Test co-location.** Unless tests are truly cross-cutting, they belong in the same subtask as the code they verify.
- **Locked decisions prevent re-litigation.** Document architectural choices in "Locked decisions" so subtask agents don't second-guess them.

---

## Subcommand: impl

Execute an existing plan by dispatching the `orchestrator` agent. `impl` does not write
production code itself — the orchestrator plans each parallel group, dispatches
implementers, reviews, and drives correction loops.

### Resolve the plan

1. The **first token** of `$REST` is the plan name (`<feature-name>`). Everything after
   it is the optional **rules** string `$RULES`.
2. Resolve to `.claude/tasks/<feature-name>/MASTER_TASKS.md`.
   - If it doesn't exist, list the directories under `.claude/tasks/` (excluding
     `archive/`, `completed/`, `general/`) and ask which one. Do not guess.
3. If `$REST` is empty, ask which plan to implement (offer the active features from
   `MASTER_PLAN.md`).

### Optional rules

`$RULES` is free-form English the user appends to shape execution. Parse intent and pass
it verbatim to the orchestrator as binding constraints. Common forms:
- **"stop after each phase"** / "checkpoint after each phase" → after every parallel group
  completes and validation passes, the orchestrator **pauses and reports**, then waits for
  the user's go-ahead before starting the next phase.
- **"stop after each subtask"** → pause after every subtask, not just every phase.
- **"don't run tests"** / "skip validation" → honor it but warn that the completion gate
  in `cmplt` still expects subtasks marked `[COMPLETED]`.
- **"only phase 0"** / "only group A" → implement just that slice, then stop.
If `$RULES` is empty, the orchestrator runs all phases to completion without pausing.

### Dispatch

1. Dispatch the `orchestrator` agent. Its prompt must include:
   - The plan path `.claude/tasks/<feature-name>/`.
   - The full `$RULES` string as binding execution constraints (quote it).
   - A reminder to update the **`## Subtasks` bullet list** in `MASTER_TASKS.md` to
     `[COMPLETED]` (or `[SKIPPED]`) per subtask as validation passes — this is the
     canonical status the `cmplt` gate reads.
2. When the orchestrator returns (or pauses at a checkpoint), relay its summary: which
   subtasks completed, validation results, anything escalated.
3. When all subtasks are `[COMPLETED]`/`[SKIPPED]`, tell the user the next command:
   `/tasks cmplt <feature-name>`.

**Resume is the default.** `impl` is idempotent: re-running it on a partially-done plan
(after a checkpoint pause, an escalation, or a new session) resumes from the first subtask
that is not yet `[COMPLETED]`/`[SKIPPED]`. The orchestrator reads the `## Subtasks` status
list and skips finished work — never re-implement a completed subtask. Tell the user where
it's resuming from before dispatching.

### What impl does NOT do

- It does NOT archive the plan — that's `cmplt`.
- It does NOT make product decisions — unclear scope is surfaced to the user.

---

## Subcommand: cmplt

Mark a plan complete and retire it. This wraps the kit hook
`.claude/hooks/archive-feature.sh`, which (atomically):
- writes a summary to `.claude/tasks/completed/<feature>.md`,
- moves `.claude/tasks/<feature>/` to `.claude/tasks/archive/<feature>/`,
- rewrites `MASTER_PLAN.md` (Active → none, append to Completed) and `CONTEXT_MAP.md`.

### Run

1. The **first token** of `$REST` is the plan name; pass through any flags the user added
   (`--force`, `--dry-run`).
2. Run:
   ```bash
   .claude/hooks/archive-feature.sh [--dry-run] [--force] <feature-name>
   ```
3. The hook refuses unless **every** subtask in the `## Subtasks` list is `[COMPLETED]` or
   `[SKIPPED]`. If it reports unfinished subtasks:
   - List the unfinished subtask IDs it printed.
   - Offer to either finish them (`/tasks impl <feature-name>`) or archive anyway with
     `--force`. Do **not** pass `--force` yourself unless the user explicitly asks.
4. On success, relay the summary and archive paths the hook prints.

### What cmplt does NOT do

- It does NOT implement or verify anything — it only retires a finished plan.
- It does NOT delete the work — the full folder is preserved under `tasks/archive/`.
