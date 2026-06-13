# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.2.0]: https://github.com/Katestheimeno/workflow-kit/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Katestheimeno/workflow-kit/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Katestheimeno/workflow-kit/releases/tag/v1.0.0
