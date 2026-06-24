# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-06-24

### Added

- **Persistent cross-session memory** (`/mem`): new `.claude/commands/mem.md` router with `save|apply|list|delete` subcommands, storing project facts/preferences/constraints as `<type>_<slug>.md` files under `.claude/memory/` (indexed by `MEMORY.md`).
  - `apply` runs automatically at session start — `session-start.sh` surfaces the memory index and directs Claude to load it.
  - `save` runs automatically at `/flow cmplt` — completion now scans the session for memory-worthy items.
  - `ensure-tasks.sh` bootstraps `.claude/memory/MEMORY.md` idempotently alongside the task scaffolding.
- **Discipline layer** (stack-agnostic rules, ported and adapted from claude-workflow-kit):
  - `rules/audit-loop.md` — tiered post-implementation self-audit (Architecture → Size/Perf → Types/Validation → Dependencies), scaled by diff size (Micro/Small/Medium+). The implementer runs it as the first gate before reporting; the `code-reviewer` agent remains the independent second gate. Wired into `agents/implementer.md` (self-pass + report the summary) and `agents/orchestrator.md` (confirm `✅ READY` before review).
  - `rules/file-architecture.md` — 250-line file / 60-line function caps + a stack-agnostic split procedure. `hooks/progress-heartbeat.sh` now warns (blocks in strict mode) when an edited source file exceeds 250 lines, honoring `exclude_line_cap` globs from `.claude/config.yml` and skipping generated files.
  - `rules/context7.md` — fetch current library/framework docs via the Context7 MCP before answering API/SDK/CLI questions.
- **Lifecycle commands** (ported and adapted from claude-workflow-kit to this kit's task-state model):
  - `/recover` (`commands/recover.md`) — reconstruct in-flight work after a session ended without finishing. Inventories the dirty tree, reconciles it against the `[IN_PROGRESS]` subtask + active feature, and proposes resume (`/flow impl`) / reconstruct-plan (`/flow pln`) / clean-commit (`/commit`) / manual-triage. `--triage` prints the inventory only.
  - `/pause` (`commands/pause.md`) — intentional mid-task suspension. Writes a `## ⏸ Pause checkpoint` into the active `[IN_PROGRESS]` subtask (status unchanged) and logs to `SESSION_LOG.md`, so the next session resumes from the next step.
  - `/pr-notes` (`commands/pr-notes.md`) — generate a PR description or CHANGELOG entry from `completed/*.md` feature summaries + branch git history (distinct from `/commit`, `/retro`, `/weekly-summary`).
  - `hooks/validate-state.sh` now suggests `/recover` when the source tree is dirty with no `[IN_PROGRESS]` subtask, and `/pause` when collapsing multiple in-progress subtasks.
- **More discipline + investigation** (ported and adapted from claude-workflow-kit):
  - `rules/assumptions.md` — assumption transparency (Type A/B/C/D classification + disclosure block) and conflict detection against locked decisions.
  - `rules/output-standards.md` — response anatomy, code-block file labeling, and the mandatory Next Actions block, calibrated to task size.
  - `rules/workflow.md` gains a **task-sizing** section (Micro/Small/Medium/Large/Epic → how much planning ceremony, with a reclassification rule) and a deeper **clarification gate** (must-ask triggers, max-5-question discipline, what/why/how check).
  - `/debug` (`commands/debug.md`) — structured bug investigation (Reproduce → Isolate → Hypothesize → Test → Fix → Verify) that compiles a debug log for `/commit`.
  - `/test` (`commands/test.md`) — discover the project's test command, run it, and gate `/commit` on the result; "no suite" is a documented skip, not a silent pass.
- **`hooks/guard-bash-writes.sh`** — new `PostToolUse(Bash)` hook that catches in-place writes (`sed -i`, `awk -i inplace`, `tee`, `truncate`, `>` redirection) which bypass the `Edit`/`Write` hook, and enforces the 250-line size cap on the files they touch. Closes the gap where shell rewrites escaped `progress-heartbeat.sh`. The shared cap/exemption logic now lives in `_lib.sh` (`wk_over_cap`), reused by both hooks. Wired in `settings.json.example`.
- **UI/design skill library** (`bundle/skills/`, optional, stack-agnostic): vendored `ui-ux-pro-max`, `impeccable`, `design-taste-frontend`, `frontend-design`, `design-system`, `design`, `ui-styling`, `slides`, `banner-design`, and `brand`, each with its own `SKILL.md` (loaded on demand) and `SOURCE.md` provenance. `install.sh`/`install.ps1` now copy `skills/` as a content dir, and their merge step handles nested subdirectories (so a skill's `data/`/`scripts/`/`templates/` install intact and re-installs idempotently).
- **`plan-reviewer` agent** (`agents/plan-reviewer.md`) — independent critique of a freshly generated `MASTER_TASKS` plan; `/flow pln` runs it ≥2× to amend the plan before presenting. Brings the agent roster to 11.
- **`config.yml.example`** (`bundle/config.yml.example`) — documents the two optional knobs the kit already reads: `exclude_line_cap:` (globs exempt from the 250-line size cap, consumed by `_lib.sh`/the hooks) and `test_command:` (used first by `/test` before auto-discovery). `install.sh`/`install.ps1` copy it into `.claude/` alongside `settings.json.example`; the entrypoint and README document it. Previously these knobs were read by code but never shipped or documented.

### Changed

- **Active-feature pointer is now a single, pinned contract.** `/flow` (and the django overlay) write the active feature under `## Active` as a **bare folder name** (`→ <feature>`), not a markdown link — which is what every consumer (`_lib.sh`'s `wk_active_feature`, `session-start.sh`, `checkpoint.sh`) already parsed. `CONTEXT_MAP.md` guidance updated to match.
- `/commit` gained a **Phase 0.5 test gate**: it confirms `/test` passed (or that the absence of a suite was documented) before generating `commit-all.sh`, and refuses otherwise unless explicitly overridden. Previously `/test` claimed to gate `/commit` but nothing enforced it.

### Fixed

- **`hooks/checkpoint.sh` mistook the default "no active feature" state for a feature named `none`.** It stripped `→` from the canonical `→ none` sentinel and compared only against `(none)`, so on every fresh install and after every feature archival it injected `Active feature: none → read .claude/tasks/none/MASTER_TASKS.md` into *every* prompt. It now sources `_lib.sh` and reuses `wk_active_feature` (the same parser the other hooks use), so the sentinel is handled in one place; also aligns its shebang to `#!/usr/bin/env bash` and gains the `wk_find_root` PWD fallback.
- **`hooks/_lib.sh` (`wk_over_cap`) dropped every `exclude_line_cap` glob after the first.** The awk print rule mutated `$0` via `sub`/`gsub`, after which the list-terminator rule saw the rewritten bare glob (a non-space first char) and ended the list. The print rule now `next`s. Surfaced when `config.yml.example` shipped a multi-entry exemption list; with a single entry the bug was invisible.
- **`hooks/archive-feature.sh` used inconsistent matching** to reset `## Active` to `none`: the MASTER_PLAN rewrite required an exact match while the CONTEXT_MAP rewrite used a substring match. Both now match exactly, so completing a feature reliably clears the active pointer in both files.
- `hooks/checkpoint.sh` now emits `additionalContext` under `hookSpecificOutput` with `hookEventName: "UserPromptSubmit"`, matching the current Claude Code hook contract. Previously the checkpoint reminder used a top-level `additionalContext` field that Claude Code does not read, so the protocol injection was being dropped.
- All slash commands (`/flow`, `/sweep`, `/commit`, `/retro`, `/weekly-summary`, plus the django-overlay `/flow` and `/sweep`) now declare YAML frontmatter (`description`, and `argument-hint` where they take arguments), so they show proper text and argument hints in the `/` menu.

## [1.2.0] - 2026-06-13

### Added

- **Orchestration layer** (stack-agnostic) installed alongside the checkpoint protocol:
  - `.claude/agents/` — 10 role agents: `orchestrator`, `planner`, `implementer`, `explorer`, `code-reviewer`, `test-writer`, `doc-writer`, `security-auditor`, `sweep-analyzer`, `sweep-reviewer`.
  - `.claude/commands/` — `/tasks` (parallelized task-plan generator) and `/sweep` (deep domain analysis → verified remediation plan).
  - `.claude/rules/` — `workflow.md` (agent orchestration protocol), `quality.md` (Definition of Done), `testing.md` (testing discipline).
  - `.claude/prompts/` — `sweep.md` (engine behind `/sweep`), `generate-commit-script.md`, `work-journal.md`.
- `hooks/checkpoint.sh` — `UserPromptSubmit` hook that injects the checkpoint protocol and the active feature into every prompt; wired in `settings.json.example`.
- **Stack overlays** under `bundle/overlays/`. `install.sh --overlay django` applies a Django/DRF-flavored version of the agents, commands, rules, and prompts over the generic core (see `bundle/overlays/django/README.md`).
- `install.ps1` — PowerShell port of `install.sh` (same flags and behavior) for Windows PowerShell 5.1+ / PowerShell 7+.

### Changed

- `install.sh` now installs the kit-owned content dirs (`agents/ commands/ rules/ prompts/`) on full install and `--only-protocol`, merging file-by-file so user-added files are preserved. New `--overlay NAME` flag.
- `CLAUDE_ENTRYPOINT.md` documents the optional orchestration layer.
- README documents the orchestration layer, the checkpoint hook, and overlays.

## [1.1.0] - 2026-04-22

### Added

- `.claude/WORKFLOW_KIT` marker file written on install and protocol upgrade (version, `installed` ISO-8601 UTC, canonical source URL).
- `install.sh --version` to print the kit version.
- `install.sh --only-protocol` to refresh `CLAUDE_ENTRYPOINT.md` and `example-feature/` from the bundle without touching `tasks/` or `CONTEXT_MAP.md`.
- `bootstrap.sh` to shallow-clone this repository at a tag and run `install.sh` (supports remote one-liner installs with a real `bundle/`).
- `example-feature/MASTER_TASKS.md` and `001-example-subtask.md` in the bundle as copy-paste examples.
- `CONTEXT_MAP.md` “When to update this file” section.
- `LICENSE` (MIT) for the published repository.

### Changed

- README: canonical home [https://github.com/Katestheimeno/workflow-kit](https://github.com/Katestheimeno/workflow-kit); upgrading section; remove misleading `curl` of `install.sh` alone; document bootstrap and `--only-protocol`.
- `CLAUDE.md.example` notes upstream URL and the `WORKFLOW_KIT` marker.

## [1.0.0] - 2026-04-22

### Added

- Initial kit: `CLAUDE_ENTRYPOINT.md`, `CONTEXT_MAP` template, `tasks/` skeleton, `install.sh`, `CLAUDE.md.example`, `example-feature` README.

[1.3.0]: https://github.com/Katestheimeno/workflow-kit/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Katestheimeno/workflow-kit/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Katestheimeno/workflow-kit/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Katestheimeno/workflow-kit/releases/tag/v1.0.0
