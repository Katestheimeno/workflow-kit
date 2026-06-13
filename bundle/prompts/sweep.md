# Domain Sweep — Deep Analysis Prompt

> **Usage:** `@.claude/prompts/sweep.md <domain>`
> **Command shortcut:** `/sweep <domain>`
> **Example:** `/sweep auth` or `@.claude/prompts/sweep.md billing`
>
> The `<domain>` argument drives the entire sweep — the top-level bounded context you
> are about to inspect (e.g. `auth`, `payments`, `notifications`, `reporting`, `search`).
> All output lives under `.claude/sweep/<domain>/`.
>
> Stack-agnostic. The checklists below are framework-neutral; adapt the search idioms
> to the project's language(s). Read `.claude/CONTEXT_MAP.md` and `.claude/rules/*.md`
> first — they define what "correct" looks like here.

---

## 0 — Bootstrap

1. Read the argument passed after the prompt reference and store it as `$DOMAIN`.
2. Create the output tree **before** writing anything:

```
.claude/sweep/$DOMAIN/
  bugs/
  performance/
  security/
  code_quality/
  architecture/
  raw_notes/
```

3. Remind yourself: you are a **first-pass analyst**, not a fixer. Observe, document, and hand off — do not change production code.
4. Record the sweep start time in `raw_notes/00_project_orientation.md`.

---

## 1 — Understand the Project Layout

Before touching `$DOMAIN`-specific code, orient yourself:

- Read `README.md`, the docs index, any ADRs, and `.claude/CONTEXT_MAP.md`.
- Read `.claude/rules/*.md` to learn the architecture conventions: where business logic is expected to live, the layering/import direction, and what must NOT leak where.
- Note the language(s), framework(s), and major libraries in use.
- Identify the data-access strategy and any read/write routing.
- Write a 10–20 line orientation summary to `raw_notes/00_project_orientation.md`.

---

## 2 — Map the Domain

Locate every file that belongs to or is consumed by `$DOMAIN`:

- Modules/packages whose name or purpose relates to `$DOMAIN`.
- Cross-cutting files that reference `$DOMAIN`'s types, events, jobs, or constants (search imports and string literals).
- Routing, middleware, and config tied to this domain.
- Background jobs and schedules for this domain.
- Realtime/streaming handlers and channels.
- Tests: unit, integration, e2e — note coverage gaps immediately.
- Schema migrations: flag risky data migrations or missing indexes/constraints on hot fields.

Write the full file list to `raw_notes/01_domain_map.md`, organized by layer (adapt the
headings to the project's architecture), e.g.:
```
## Models / Schema
## Services / Use-cases
## Data access
## Entry points (routes/handlers/commands)
## Serialization / Schemas
## Authorization
## Events / Handlers
## Jobs
## Config / Wiring
## Tests
## Migrations
## Cross-cutting references (other modules importing from $DOMAIN)
```

---

## 3 — Bug Pass

Read every file in the domain map carefully. For each potential bug, create a **separate
file** inside `bugs/` named `BUG-<NNN>_<short-slug>.md` using the finding template (see
**Finding template** below). Hunt for (not exhaustive — use judgment):

- Incorrect queries (wrong filter/lookup, fetch-one vs fetch-many, bad boolean precedence).
- Missing atomicity on multi-step writes.
- Error handlers that silently swallow failures.
- Retried work that isn't idempotent.
- Validators with incorrect logic.
- Permission checks present at the boundary but missing in shared logic with multiple entry points.
- Missing locking on concurrently updated state (read-check-write races).
- Hardcoded secrets/tokens/environment strings in source.
- Over-broad exception handling that hides real errors.
- Unhandled not-found / multiple-result cases.
- Realtime/message handlers not validating payload shapes.
- Side effects fired before the gating transaction commits.
- Off-by-one in pagination, slicing, or ranges.

---

## 4 — Performance Pass

For each issue, create a file in `performance/` named `PERF-<NNN>_<short-slug>.md`
(finding template, with an `## Impact Estimate` field instead of `## Severity`). Inspect:

- Eager-loading / batching on relations traversed in loops (classic N+1).
- Unbounded list endpoints (no pagination, very high default page size).
- Missing indexes on filtered/ordered/aggregated fields.
- Synchronous external calls in the request cycle without offload.
- Heavy aggregation in the request cycle that should be precomputed.
- Over-fetching (full hydration where a projection would do).
- Cache misuse: missing where warranted, stale where invalidation is absent.

---

## 5 — Security Pass

For each issue, create a file in `security/` named `SEC-<NNN>_<short-slug>.md` (finding
template plus `## CWE / OWASP Reference`, `## Attack Scenario`, `## Proof of Concept`).
Security checklist (framework-neutral):

- **Authentication & session:** token/session lifetime, rotation, invalidation on logout/password-change; secure cookie flags; transport security in production.
- **Authorization:** IDOR (object-level permission missing in the service/data layer), horizontal/vertical privilege escalation, missing authn on non-public endpoints.
- **Input validation:** injection via string-built queries, unvalidated sort/field parameters, mass assignment / missing field allowlists.
- **Secrets:** keys in source, config files committed.
- **File uploads:** unrestricted types/sizes, path traversal, serving user uploads unsafely.
- **Rate limiting:** brute force on login/reset/OTP; throttling on expensive and write endpoints.
- **Dependencies:** flag known-vulnerable packages in the lockfile/manifest.
- **Realtime:** auth on connect, no anonymous access to protected channels, payload validation.
- **Output exposure:** privileged fields writable or readable through public input.
- **Background jobs:** user-controlled arguments accepted without validation.

---

## 6 — Code Quality Pass

Create files in `code_quality/` named `CQ-<NNN>_<short-slug>.md` (finding template with a
`## Category` field: ARCH_VIOLATION | DEAD_CODE | DUPLICATION | TEST_GAP | ERROR_HANDLING |
TYPING | NAMING | COMPLEXITY, and a `## Convention Violated` field citing `.claude/rules/`).
Inspect:

- Business logic leaking into the wrong layer (entry points, serializers, event handlers).
- Read layer performing writes (wrong direction).
- Dead code: unused imports, unreachable branches, commented-out blocks.
- Duplicated logic that should be extracted to a shared helper.
- Missing test coverage for critical branches.
- Over-broad exception handling that swallows context.
- Missing type annotations on public signatures (where the language has them).
- Inconsistent naming within the domain.
- Overly complex functions (high nesting, many branches).

---

## 7 — Architecture Pass

Create files in `architecture/` named `ARCH-<NNN>_<short-slug>.md` (finding template with
`## Severity` = STRUCTURAL | MODERATE | MINOR and `## Affected Layer(s)`). Look for:

- Layer / import-direction violations per the project's rules.
- Circular dependencies between modules.
- God services/objects doing too much.
- Modules reaching into another module's internals instead of its public interface.
- Transaction boundaries at the wrong layer.
- Transport/request coupling leaking into business logic.
- Missing abstraction boundaries for external integrations.

---

## Finding template

Every finding file follows this structure (passes add the extra fields noted above):

```markdown
# <TYPE>-<NNN>: <one-line title>

## Severity
<!-- CRITICAL | HIGH | MEDIUM | LOW (or the pass-specific scale) -->

## File & Line(s)
<!-- exact path(s) and line range -->

## Code Snapshot
<!-- paste the relevant snippet verbatim — do NOT paraphrase -->

## Context
<!-- What the surrounding code is trying to do; which layer/module it lives in -->

## Observed Problem
<!-- Specific: wrong query, missing check, race condition, etc. -->

## Reproduction Path
<!-- How a caller would trigger this. Step by step if possible -->

## Why This Is NOT a False Positive
<!-- Pre-argue your case for the reviewer. Cite framework docs or project conventions -->

## Impact
<!-- What breaks or leaks if this fires in production -->

## Confidence
<!-- HIGH | MEDIUM | LOW -->
```

---

## 8 — Verification by Fresh Agent

When all finding files are written, hand off to a **fresh subagent** (the `sweep-reviewer`)
with these instructions (fill in `$DOMAIN`):

---

**REVIEWER SUBAGENT INSTRUCTIONS**

You are a skeptical senior engineer performing a quality gate on automated findings.
Your job is to **verify**, **dismiss false positives**, and **promote real issues**.

1. Read `raw_notes/00_project_orientation.md` and `raw_notes/01_domain_map.md` to orient.
2. For every finding file across `bugs/`, `performance/`, `security/`, `code_quality/`, `architecture/`:
   - Re-read the **Code Snapshot** against the **actual file on disk** at the cited lines.
   - Verify the code actually does what the finding claims.
   - Check whether the issue is mitigated elsewhere (middleware, base class, decorator, framework default).
   - Check whether it was recently fixed (`git log --oneline -10 -- <file>`).
   - Decide: **CONFIRMED** | **FALSE_POSITIVE** | **NEEDS_MORE_INFO**.
   - Append a `## Reviewer Verdict` section (Status / Reasoning / Adjusted Severity / Confidence Override).
3. Write a summary to `raw_notes/02_reviewer_summary.md`: totals by category, confirmed/dismissed/needs-more-info counts, the top 5 confirmed findings (severity × confidence), systemic patterns, false-positive rate and root causes, and remediation recommendations.
4. Stop. Do not fix anything. Do not modify production code.

---

## 9 — Task Generation

After `02_reviewer_summary.md` is written, read all **CONFIRMED** findings plus the
summary, then generate a remediation plan (this mirrors the `/tasks` command):

1. **Create** `.claude/tasks/<domain>-sweep-remediation/MASTER_TASKS.md` with goal, locked decisions, a priority-queue table, a dependency graph, a strictly-disjoint file-ownership table, and a validation gate.
2. **Group findings** into work packages (same file → same subtask; same concern → same group where files don't conflict; 1–5 findings per subtask).
3. **Order by risk-adjusted priority:** CRITICAL security > CRITICAL bugs > HIGH bugs > HIGH security > MEDIUM everything else > LOW/CQ/ARCH.
4. **Create numbered subtask files** (`001-*.md`, ...) with problem, files owned, fixes, tests, and validation.
5. **Update** `.claude/tasks/MASTER_PLAN.md` — add the remediation feature as Active.

---

## 10 — Stop

Once the task plan is generated and `MASTER_PLAN.md` updated, **stop**. Do not implement
fixes, open PRs, or modify any production file. Deliverables: the finding files, the
reviewer verdicts, the reviewer summary, the task plan, and the updated `MASTER_PLAN.md`.

---

*Prompt version: 2.0 (stack-agnostic) — confidence scoring, reviewer quality gate, structured task generation, file-ownership disjointness.*
