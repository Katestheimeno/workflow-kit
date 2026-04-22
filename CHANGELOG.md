# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.1.0]: https://github.com/Katestheimeno/workflow-kit/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Katestheimeno/workflow-kit/releases/tag/v1.0.0
