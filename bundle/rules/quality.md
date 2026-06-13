# Quality gates

Stack-agnostic Definition of Done. A change is **done** when every *applicable* row is
green. Rows apply conditionally by change class. Add project-specific rows in your own
`.claude/rules/` files (or replace this file with a stack-specific version).

---

## 1. Definition of Done (DoD)

### Always

- [ ] Functionality matches the acceptance criteria.
- [ ] No debug leftovers (prints, debugger statements, commented-out code).
- [ ] No `TODO` / `FIXME` without a tracked issue link.
- [ ] No silently swallowed errors — every catch logs with context or re-raises.
- [ ] Tests added for every new branch (`testing.md`).
- [ ] The project's validation command is green (see `CONTEXT_MAP.md`).
- [ ] Docs updated for user-visible or contract changes; CHANGELOG entry for substantive work.
- [ ] Session log / traceability written if the project keeps one.

### Changes to auth / payment / PII / other sensitive endpoints

- [ ] Object-level authorization verified (an IDOR test is present).
- [ ] Authorization is explicit; no "allow all" without a written rationale.
- [ ] No secrets in code or logs.
- [ ] Threat checklist completed (see `security-auditor` agent).

### Changes to list / query-heavy code

- [ ] List endpoints are paginated / bounded.
- [ ] No N+1 / repeated work in loops (verify, don't assume).
- [ ] Caching applied or intentionally omitted with a written reason.

### Changes to public API (schema, fields, enums, response shapes)

- [ ] API schema / contract updated.
- [ ] Schema validation passes (if the project validates it).
- [ ] Error codes/conventions followed and registered where the project tracks them.
- [ ] Deprecations marked in schema + CHANGELOG.
- [ ] Additive-only within a major version (no field removal/rename/type change).

### Changes to services / background jobs / external integrations

- [ ] Important outcomes logged with structured context.
- [ ] Correlation/trace ID propagated (request → job → log) where the project supports it.
- [ ] No PII / secrets in logs.
- [ ] Idempotency analyzed (payments, notifications, external state).
- [ ] Retry/backoff configured for jobs that can fail transiently.

### Architecture

- [ ] Layer/module boundaries respected per the project's rules.
- [ ] Transactions scoped at the right layer.
- [ ] Reads and writes separated as the project's conventions require.

### Merge readiness

- [ ] PR title + description explain *why*, not just *what*.
- [ ] Linked to an issue / tracker entry.
- [ ] Review feedback addressed or deferred with a written reason.

---

## 2. Pre-review checklist (verify before you hand off)

Run the "Always" rows plus the relevant conditional subsets against your own diff
**before** requesting review. If a row is red, fix it rather than flagging it in the PR.

---

## 3. What makes a PR easy to review

- **Small.** One concern per PR. Refactor-only changes separated from behavior changes.
- **Diff-readable.** Rename → same file. Move → separate commit from edit.
- **Tests alongside the change** — not a follow-up PR.
- **Doc + CHANGELOG updates in the same PR** — this is the record a release cares about.
