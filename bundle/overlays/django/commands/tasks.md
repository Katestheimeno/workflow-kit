# Task Planner

Generate a structured, parallelized implementation plan from a feature description, audit findings, or any body of work that needs to be broken into trackable subtasks.

## Usage

```
/tasks <description or context>
```

**Examples:**
- `/tasks Add WebSocket presence tracking to game sessions`
- `/tasks Remediate all confirmed findings in .claude/sweep/auth/`
- `/tasks Implement the drill feature from docs/DRILL_SPEC.md`

## Instructions

You are a task planner. Your job is to produce a complete, dependency-aware execution plan that maximizes parallelism and ensures no two subtasks conflict on the same files.

### Input

```
$ARGUMENTS
```

If `$ARGUMENTS` is empty, ask the user what they want to plan.

### Phase 0 — Understand the work

1. **Parse the input.** Determine what kind of work this is:
   - **Feature:** a new capability described in natural language or a spec document
   - **Remediation:** fixing findings from a sweep (`.claude/sweep/<domain>/`)
   - **Refactor:** restructuring existing code without changing behavior
   - **Migration:** moving between patterns, versions, or architectures

2. **Read context.** Before planning, read:
   - `.claude/CONTEXT_MAP.md` — project architecture
   - `.claude/tasks/MASTER_PLAN.md` — what's already active (avoid conflicts)
   - `.claude/rules/foundations.md` — layering rules and conventions
   - Any spec documents, sweep findings, or docs referenced in `$ARGUMENTS`

3. **Clarification gate.** If the scope is ambiguous, ask up to 3 targeted questions before proceeding. If everything is clear, state your understanding in 2–3 sentences and move on.

### Phase 1 — Discover the work

Depending on work type:

**For features:**
- Identify all files that need to be created or modified
- Identify models, services, selectors, controllers, serializers, permissions, tests, admin, URLs, migrations
- Note which existing code will be affected (read it first)

**For remediations:**
- Read all CONFIRMED finding files from the sweep directory
- Read `raw_notes/02_reviewer_summary.md` for the reviewer's prioritization
- Group findings by file and concern

**For refactors/migrations:**
- Identify all sites that need changes (grep, read, trace imports)
- Determine the before/after pattern
- Note which files are safe to change in parallel

### Phase 2 — Design the plan

1. **Create the feature directory:**
   ```
   .claude/tasks/<feature-name>/
     MASTER_TASKS.md
     001-<slug>.md
     002-<slug>.md
     ...
   ```

2. **Name the feature** using `kebab-case`. For remediations, use `<domain>-sweep-remediation`. For features, use the natural short name.

3. **Write `MASTER_TASKS.md`** with this structure:

   ```markdown
   # <Feature Name>

   **Date:** YYYY-MM-DD
   **Source:** <where this work came from — user request, sweep, spec doc>
   **Goal:** <one sentence — what does "done" look like>

   ---

   ## Locked decisions

   <numbered list of architectural and scope decisions that subtasks must not re-litigate>

   ---

   ## Priority queue

   | ID | Subtask | Status | Phase | Group | Scope |
   |----|---------|--------|-------|-------|-------|
   | 001 | <title> | [TODO] | 0 | — | <brief> |
   | 002 | <title> | [TODO] | 1 | A | <brief> |
   | 003 | <title> | [TODO] | 1 | A | <brief> |
   | 004 | <title> | [TODO] | 1 | B | <brief> |
   | 005 | <title> | [TODO] | 2 | — | <brief> |

   ---

   ## Dependency graph

   ```
   001 (Phase 0 — runs first, alone)
    |
    v
   A ──┐
   B ──┼──► 005 (Phase 2 — validation + cross-review)
   C ──┘
   ```

   ---

   ## File ownership (strictly disjoint)

   ### 001
   - path/to/file1.py
   - path/to/file2.py

   ### 002 (Group A)
   - path/to/file3.py
   - path/to/file4.py

   <...>

   ---

   ## Validation gate (Definition of Done)

   ```bash
   uv run pytest --ds=config.django.test
   # + any feature-specific validation
   ```
   ```

4. **Grouping rules:**
   - **Same file → same subtask.** Two subtasks must never modify the same file.
   - **Same concern → same group.** Related subtasks that don't share files go in the same parallel group.
   - **Infrastructure first.** Models, migrations, shared utilities are Phase 0.
   - **Core logic next.** Services, selectors, permissions are Phase 1.
   - **Integration last.** Controllers, serializers, URLs, admin are Phase 2 (or later).
   - **Tests co-locate with their code** unless they're standalone integration tests.
   - **Cross-review is always the final phase.**

5. **Subtask sizing:**
   - Each subtask should take 10–60 minutes for an agent to implement.
   - 1–5 files per subtask is ideal. More than 8 files means the subtask is too broad.
   - 1–5 findings per subtask for remediations.

### Phase 3 — Write subtask files

For each subtask, create a numbered file (`001-<slug>.md`, `002-<slug>.md`, ...):

```markdown
# NNN — <title>

**Status:** [TODO]
**Phase:** <N>
**Group:** <letter or "—" for solo phases>
**Dependencies:** <list of subtask IDs that must complete first, or "none">

## Goal
<one sentence — what does this subtask accomplish>

## Context
<2-3 sentences — why this matters, what the current state is>

## Files Owned
<exact paths this subtask may create or modify — MUST be disjoint with all other subtasks>

## Implementation Steps

### Step 1 — <description>
<what to do, where to do it>

### Step 2 — <description>
<...>

## Tests
<what tests to add or modify, what they verify>

## Validation
```bash
<specific test commands to verify this subtask>
```

## Acceptance Criteria
- [ ] <criterion 1>
- [ ] <criterion 2>
- [ ] <...>
```

### Phase 4 — Register the plan

1. **Update `.claude/tasks/MASTER_PLAN.md`:**
   - Add the new feature under `## Active` with a link to `MASTER_TASKS.md`
   - Include a brief description and "0/N subtasks done"

2. **Report to the user:**
   - Total subtasks created
   - Number of parallel groups
   - Estimated phases
   - Top priority subtask(s)
   - Any open questions or decisions that need user input

### What this command does NOT do

- It does NOT implement any code changes.
- It does NOT create branches or PRs.
- It does NOT modify production code.
- It produces planning artifacts only. Implementation is done by executing the subtasks (manually or via agents).

### Principles

- **Maximize parallelism.** Every subtask that doesn't depend on another's output belongs in a concurrent group. The dependency graph should be wide, not deep.
- **File ownership is sacred.** If two subtasks could touch the same file, either merge them or split the file's changes so each subtask owns a disjoint section. Parallel agents editing the same file is a conflict.
- **Plans are self-contained.** An engineer (or agent) should be able to pick up any subtask file and execute it without reading the original request or this conversation.
- **No premature abstraction.** Don't create helper utilities, shared modules, or abstraction layers unless the plan actually needs them. Three similar implementations are better than one premature abstraction.
- **Test co-location.** Unless tests are truly cross-cutting, they belong in the same subtask as the code they verify.
- **Locked decisions prevent re-litigation.** When you make an architectural choice in the plan, document it in "Locked decisions" so subtask agents don't second-guess it.
