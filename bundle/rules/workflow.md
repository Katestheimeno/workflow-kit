# Agent orchestration protocol

The shared workflow that all commands and multi-step tasks follow: clarification gate,
parallel execution, confirmation, plan generation, parallel agents, and cross-review.
This is stack-agnostic — it governs *how* work flows through agents, not *what* the
code looks like.

---

## 0. Task sizing — how much ceremony

Classify the task before doing anything else. The size sets how much planning is
required; it refines the "Simple task vs Feature" split in `CLAUDE_ENTRYPOINT.md`.

| Size | Criteria | Requirement |
|------|----------|-------------|
| **Micro** | one file, one function, no cross-module impact | just do it; log a line in `general/SESSION_LOG.md` |
| **Small** | 1–3 files, single module/layer | 3–5 bullet inline plan, then proceed |
| **Medium** | 2–5 files, 2 layers, or touches shared code | `/flow pln` — reviewed `MASTER_TASKS` plan |
| **Large** | 5+ files, 3+ layers, new module, or new shared primitive | `/flow pln` + explicit scope confirmation |
| **Epic** | multi-session; auth / data-schema / navigation changes | decompose into sub-features, one per `/flow` run |

When ambiguous, classify **one level higher** — never downgrade to skip planning.

**Reclassification.** If a task outgrows its size mid-flight, stop and say so explicitly
(`RECLASSIFICATION: <old> → <new> — <what forced it>`), then escalate ceremony to match
(Small→Medium means stop and run `/flow pln`, carrying progress forward). Silent scope
expansion is a protocol violation.

## 1. Clarification gate — ask before you build

After reading context and understanding the task:

1. **Identify unknowns.** List anything ambiguous: scope boundaries, naming choices, architectural decisions, dependencies on unfinished work, unclear acceptance criteria.
2. **Must ask** (don't guess) when any of these hold:
   - **Scope ambiguity** — the request has 2+ meaningfully different readings.
   - **Architectural impact** — it crosses module/layer boundaries, adds an entity, or changes a data contract.
   - **Requirement gap** — *what* is clear but *why/how* is missing and would change the approach.
   - **Conflicting decision** — it contradicts a locked decision (see `assumptions.md` conflict block).
   - **Destructive / irreversible** operation, or a **new external dependency**.
3. **Question discipline:** one block, **max 5 questions**, ranked by how blocking they are; prefer binary/enumerated over open-ended. Do not ask after you've already started writing code.
4. **Completeness check** — *what, why, how* must all be answerable before implementation.
5. **If everything is clear:** state your understanding in 2–3 sentences and move to parallel execution immediately. Do not ask for permission to start — clarity is the gate, not approval.

## 2. Parallel-first execution

Once the task is understood:

- **Identify independent work streams.** Any reads, audits, analyses, or implementations that touch different files or domains can run simultaneously.
- **Spawn one agent per independent stream.** Use a `subagent_type` appropriate to the work (`explorer` for search, `implementer` for code, `planner` for architecture, `sweep-analyzer` for analysis).
- **Never serialize what can parallelize.** If three modules need auditing, three agents launch in one message.
- **Agents that share write targets must be serialized.** Two agents editing the same file is a conflict — queue them.

## 3. Confirmation gate — present findings, get go-ahead

After parallel work completes (audit, research, analysis):

1. **Consolidate results** into a brief summary for the user: key findings, decisions needed, proposed approach.
2. **Ask for confirmation** before generating the implementation plan. The user may want to adjust scope, reprioritize, or skip items.
3. **Do not auto-generate a plan without confirmation.** The transition from "understanding" to "building" requires explicit user approval.

## 4. Plan generation — `.claude/tasks/` pattern

On user confirmation, generate a plan following the established task structure:

1. **Create** `.claude/tasks/<feature>/MASTER_TASKS.md` with:
   - `Priority:`/`Status:` header lines, goal, and locked decisions.
   - Priority queue table: `ID | Subtask | Phase | Parallel group` (no status column).
   - The machine-readable `## Subtasks` bullet list — `- [PENDING] [NNN-slug.md](NNN-slug.md) — title`
     (status token: `PENDING | IN_PROGRESS | BLOCKED | COMPLETED | SKIPPED | DEFERRED`).
     This is the canonical status source the orchestrator, the progress hooks, and
     `/flow cmplt` all read — it is mandatory.
   - Execution dependency graph showing which subtasks can run concurrently.
   - Affected-files inventory (strictly disjoint between subtasks).
   - Validation gate (Definition of Done for the feature).
2. **Create subtask files** (`001-*.md`, `002-*.md`, ...) per the subtask template in `CLAUDE_ENTRYPOINT.md` (or via the `/flow pln` command).
3. **Update** `.claude/tasks/MASTER_PLAN.md` — set the new feature as Active.
4. **Maximize parallel groups.** Every subtask that does not depend on another's output belongs in a concurrent group. Label groups (A, B, C, ...) and document the dependency edges.

## 5. Parallel implementation agents

During execution of the plan:

- **Each parallel group** spawns one agent per subtask (or per logical cluster if subtasks share a file).
- **Agents receive** their subtask file path, the MASTER_TASKS context, and any locked decisions they need.
- **On completion**, each agent updates its subtask status to `[COMPLETED]` and reports what it changed.
- **Serialized subtasks** wait for their dependency to complete before spawning.

## 6. Cross-review agents

After each parallel group's implementation agents finish:

1. **Spawn a review agent per completed subtask.** The reviewer is a fresh agent that:
   - Re-reads the changed files from scratch (does not inherit the implementer's context).
   - Checks for bugs, logic errors, convention violations, missing edge cases, and consistency with project rules (`.claude/rules/*`).
   - Verifies the subtask's validation command passes.
   - Reports: `PASS` (no issues) or `ISSUES FOUND` with specific file:line references and fix descriptions.
2. **If issues are found:** fix them inline (if minor) or flag to the user (if architectural). Then re-run the subtask's validation.
3. **Review agents can run in parallel** when reviewing different subtasks that don't share files.
4. **One review round is the default.** A second round happens only if the first triggered non-trivial fixes. Cap at 2 review rounds per subtask.

## 7. Completion

After all subtasks pass implementation + review:

1. Run the feature-level validation gate from MASTER_TASKS.md.
2. Update MASTER_PLAN.md status.
3. Report the final state to the user.
