# workflow-kit

Canonical repository: `git@github.com:Katestheimeno/workflow-kit.git`

**Task Checkpoint Protocol** for AI-assisted development: files under `.claude/` (entrypoint, context map, task plans) plus an optional `CLAUDE.md.example` at the project root.

Version: [VERSION](VERSION). Changelog: [CHANGELOG.md](CHANGELOG.md). License: [LICENSE](LICENSE) (MIT).

## What gets installed

| Path | Role |
|------|------|
| `.claude/WORKFLOW_KIT` | Installed version, `installed` time (UTC), source URL, and target path (written by `install.sh`) |
| `.claude/CLAUDE_ENTRYPOINT.md` | Mandatory checkpoint (read first every session) |
| `.claude/CONTEXT_MAP.md` | Project snapshot template (edit for your team) |
| `.claude/tasks/MASTER_PLAN.md` | Active feature + queue |
| `.claude/tasks/general/SESSION_LOG.md` | Append-only log for small tasks |
| `.claude/tasks/completed/`, `archive/` | Placeholders for summaries |
| `.claude/example-feature/` | README, example `MASTER_TASKS.md` and `001-example-subtask.md` |
| `.claude/hooks/` | Shell scripts: `checkpoint.sh`, `session-start.sh`, `progress-heartbeat.sh`, `guard-bash-writes.sh`, `validate-state.sh`, `archive-feature.sh`, `ensure-tasks.sh`, shared `_lib.sh`; plus the caveman Node hooks (`caveman-config.js`, `caveman-activate.js`, `caveman-mode-tracker.js`, `caveman-stats.js`) and statusline (`caveman-statusline.sh`/`.ps1`) — **Node ≥18** |
| `.claude/agents/` | 14 stack-agnostic role agents (orchestrator, planner, plan-reviewer, implementer, explorer, code-reviewer, test-writer, doc-writer, security-auditor, sweep-analyzer, sweep-reviewer, plus the caveman-compressed `cavecrew-investigator`, `cavecrew-builder`, `cavecrew-reviewer`) |
| `.claude/commands/` | `/flow` (router: `pln` plan + review, `impl` orchestrated execution, `cmplt` archive), `/sweep` (deep domain/context analysis → remediation plan), `/mem` (persistent cross-session memory), `/recover` (reconstruct in-flight work), `/pause` (checkpoint a subtask), `/pr-notes` (PR description / CHANGELOG), `/debug` (structured bug investigation), `/test` (run suite + gate `/commit`), `/commit`, `/retro`, `/weekly-summary` |
| `.claude/memory/` | `MEMORY.md` index + `<type>_<slug>.md` files — persistent project memory managed by `/mem`, bootstrapped by `ensure-tasks.sh` |
| `.claude/rules/` | `workflow.md` (orchestration protocol + task sizing + clarification gate), `quality.md` (Definition of Done), `testing.md` (testing discipline), `audit-loop.md` (tiered self-audit before review), `file-architecture.md` (250/60 size caps + split), `context7.md` (fetch current library docs via Context7 MCP), `assumptions.md` (assumption transparency + conflict detection), `output-standards.md` (response anatomy + Next Actions), `caveman.md` (caveman compression mode + precedence over output standards) |
| `.claude/prompts/` | `sweep.md` (engine behind `/sweep`), `generate-commit-script.md`, `work-journal.md` |
| `.claude/skills/` (optional) | Vendored UI/design skill library: `ui-ux-pro-max`, `impeccable`, `design-taste-frontend`, `frontend-design`, `design-system`, `design`, `ui-styling`, `slides`, `banner-design`, `brand`; plus the **caveman** token-compression family: `caveman`, `caveman-commit`, `caveman-review`, `caveman-stats`, `caveman-compress`, `caveman-help`, `cavecrew` — each self-describing via `SKILL.md`, loaded on demand. `SOURCE.md` records provenance |
| `.claude/settings.json.example` | Sample Claude Code `hooks` wiring; **you merge it** into `.claude/settings.json` to activate |
| `.claude/config.yml.example` (optional) | Sample config; copy to `.claude/config.yml` to set `exclude_line_cap` globs (size-cap exemptions) and a `test_command` for `/test` |
| `CLAUDE.md.example` (optional) | Stub pointing at the entrypoint; copy or merge into your `CLAUDE.md` |

The checkpoint protocol and orchestration layer are **stack-agnostic** — they describe *how* work flows through agents and defer stack-specific conventions to `.claude/rules/` and `.claude/CONTEXT_MAP.md`, which you fill in for your project. For a ready-made stack flavor, apply an [overlay](#stack-overlays).

## Hooks (enforce the protocol)

After install, merge `.claude/settings.json.example` into your `.claude/settings.json` to wire up:

- **UserPromptSubmit** → `hooks/checkpoint.sh` — injects the checkpoint protocol and the active feature (read from `MASTER_PLAN.md`) before every prompt.
- **SessionStart** → `hooks/session-start.sh` — prints active feature + `[IN_PROGRESS]` subtask so Claude opens aligned.
- **PostToolUse** (Edit|Write|MultiEdit) → `hooks/progress-heartbeat.sh` — warns on scope drift vs. the active subtask's `Allowed:` list; announces when a feature's subtasks are all `[COMPLETED]` and suggests archiving.
- **Stop** → `hooks/validate-state.sh` — checks invariants (at most one `[IN_PROGRESS]`, `MASTER_PLAN.md` Active matches reality).

Archive a finished feature with `.claude/hooks/archive-feature.sh <feature>`: writes `tasks/completed/<feature>.md`, moves the folder to `tasks/archive/<feature>/`, and rewrites the pointers in `MASTER_PLAN.md` and `CONTEXT_MAP.md`. `--dry-run` previews; `--force` archives incomplete features.

`/flow` self-heals its data scaffolding: each subcommand first runs `.claude/hooks/ensure-tasks.sh`, which idempotently recreates `tasks/MASTER_PLAN.md`, the `completed/`/`archive/` buckets, and `general/SESSION_LOG.md` if they're missing (e.g. a fresh clone). It only ever creates absent files — never overwrites — and refuses (exit 1) when the kit isn't installed, since it can't synthesize the agents or hooks that `install.sh` owns. Run it directly with `--dry-run` to preview.

Hooks are **soft by default** (warnings on stderr). Set `WORKFLOW_KIT_STRICT=1` to make them exit 2 and block the tool call on violations.

## Orchestration layer (agents, commands)

On top of the checkpoint protocol, the kit ships a multi-agent orchestration layer. It is **stack-agnostic**: the agents read your project's conventions from `.claude/rules/*.md` and `.claude/CONTEXT_MAP.md` rather than hard-coding a language or framework.

- **Agents** (`.claude/agents/`) — the `orchestrator` plans an implementation, writes precise instructions, and dispatches `implementer` / `test-writer` agents in parallel groups with **disjoint file ownership**, then runs `code-reviewer` agents as fresh eyes. `planner` designs `MASTER_TASKS` plans and `plan-reviewer` critiques them before any code is written; `explorer` does fast codebase navigation; `doc-writer` keeps docs in sync; `security-auditor`, `sweep-analyzer`, and `sweep-reviewer` power deep analysis.
- **`/flow`** — a router with three subcommands: `pln [context]` breaks a feature, remediation, or refactor into a dependency-aware, maximally parallel plan under `.claude/tasks/<feature>/` (with strictly disjoint file ownership) and has `plan-reviewer` critique and amend it at least twice before presenting; `impl <plan> [rules]` dispatches the orchestrator to execute the plan, honoring rules like "stop after each phase"; `cmplt <plan>` archives a finished plan. Bare `/flow <description>` still works as a shortcut for `pln`.
- **`/sweep <domain | free-text context>`** — runs five parallel analysis passes (bugs, performance, security, code quality, architecture) over a domain **or** any free-text theme you describe, verifies findings with an adversarial reviewer pass to kill false positives, and emits a prioritized remediation plan.
- **`/mem`** — persistent cross-session memory (`save|apply|list|delete`). Stores project facts, preferences, corrections, and non-obvious decisions as `<type>_<slug>.md` files under `.claude/memory/`, indexed by `MEMORY.md`. It **applies** automatically at session start (the `session-start.sh` hook surfaces the index and Claude loads it) and **saves** at `/flow cmplt`, so the kit stops re-deriving the same constraints every chat.
- **`/pause`, `/recover`, `/pr-notes`** — lifecycle helpers. `/pause` writes a resume checkpoint into the active `[IN_PROGRESS]` subtask so the next session continues cleanly. `/recover` reconstructs work after a session that ended without finishing — it inventories the dirty tree, reconciles it against task state, and proposes resume / reconstruct-plan / clean-commit / manual-triage (the `validate-state.sh` Stop hook points here when it sees uncommitted changes with no in-flight subtask). `/pr-notes` turns completed-feature summaries + branch git history into a PR description or CHANGELOG entry.
- **`/debug`, `/test`** — `/debug` drives a structured bug investigation (Reproduce → Isolate → Hypothesize → Test → Fix → Verify) and compiles a debug log that feeds `/commit`. `/test` discovers the project's test command, runs it, and gates `/commit` on the result — a failing run blocks; "no suite" is a documented skip.
- **`rules/workflow.md`** is the protocol all of this follows: task sizing → clarification gate → parallel work → confirmation → plan → parallel implementation → cross-review. `assumptions.md` and `output-standards.md` govern how assumptions are surfaced and how responses are structured.

To make the agents match your stack, fill in `.claude/rules/` with your layering/quality conventions (the kit ships generic `workflow.md`, `quality.md`, `testing.md`), or apply an overlay.

### UI/design skills (optional)

The bundle also vendors a stack-agnostic UI/design **skill library** under `.claude/skills/` — `ui-ux-pro-max` (a searchable database of styles, palettes, font pairings, and charts), the anti-slop `impeccable` and `design-taste-frontend`, plus `frontend-design`, `design-system`, `design`, `ui-styling`, `slides`, `banner-design`, and `brand`. Each is self-describing via its `SKILL.md`, so Claude loads them on demand for frontend/design work; per-skill `SOURCE.md` files record provenance. They install with the rest of the content dirs and carry no dependency on the orchestration layer.

### Caveman compression mode (optional)

The bundle also vendors [**caveman**](https://github.com/JuliusBrussee/caveman) (MIT) — a token-compression mode that makes Claude answer in terse "caveman speak", cutting **~65–75% of output tokens** while keeping full technical accuracy. It ships as a skill family (`caveman`, `caveman-commit`, `caveman-review`, `caveman-stats`, `caveman-compress`, `caveman-help`, `cavecrew`), three caveman-compressed subagents (`cavecrew-*`), and Node hooks that activate it from message one.

- **Activation** — the `SessionStart`/`UserPromptSubmit` hooks (`caveman-*.js`, **Node ≥18**) plus a `statusLine` badge are wired in `settings.json.example`. Caveman is **opt-in but auto-on** once merged: leave its three hook entries (and the `statusLine` block) out of your `.claude/settings.json` to keep it manual — the `/caveman` skills still load on demand.
- **Control** — `/caveman lite|full|ultra|wenyan` switches intensity; `/caveman off`, "stop caveman", or "normal mode" disables it. Pin a per-project default with a checked-in `.caveman/config.json`. The mode flag lives in your user config dir, so it applies across projects.
- **Precedence** — caveman deliberately overrides the verbose `output-standards.md` anatomy for *prose* only. Code, commits, exact error strings, and safety-critical confirmations are never compressed. The reconciliation rule is `rules/caveman.md`.
- **Not vendored** — `caveman-shrink` (MCP middleware compressing tool descriptions) is published separately on npm; install it directly if you want it. Per-skill `SOURCE.md` files record what was imported.

## Stack overlays

Overlays under `bundle/overlays/<name>/` replace the generic agents/commands/rules/prompts with a stack-specific flavor. The kit ships a **Django/DRF** overlay:

```bash
./install.sh --overlay django /path/to/your-project
```

This installs the generic core first, then overlays the Django versions (concrete layering — controllers → services → selectors → models, DRF serializers/permissions, `pytest`, Celery, Channels, OpenAPI) plus extra Django rules and prompts. See `bundle/overlays/django/README.md` for what to adapt to your project. Without `--overlay`, you get the stack-agnostic core.

## Install (recommended): clone, then run `install.sh`

```bash
git clone git@github.com:Katestheimeno/workflow-kit.git
cd workflow-kit
chmod +x install.sh bootstrap.sh
./install.sh /path/to/your-project
# or from inside the project (absolute path to install.sh is fine):
/path/to/workflow-kit/install.sh .
```

### Windows (PowerShell)

`install.ps1` is a port of `install.sh` with the same flags and behavior (works on Windows PowerShell 5.1+ and PowerShell 7+):

```powershell
git clone git@github.com:Katestheimeno/workflow-kit.git
cd workflow-kit
.\install.ps1 C:\path\to\your-project
# with the Django overlay:
.\install.ps1 --overlay django C:\path\to\your-project
# refresh an existing install:
.\install.ps1 --only-protocol C:\path\to\your-project
```

If scripts are blocked by execution policy, run it for the current process only:
`powershell -ExecutionPolicy Bypass -File .\install.ps1 C:\path\to\your-project`. The
installed hook scripts (`*.sh`) need a bash runtime such as Git Bash to execute.

## Install with bootstrap (no local clone of the kit first)

If you have **git** and **network** access, `bootstrap.sh` shallow-clones this repo at a tag and runs `install.sh` in one step.

```bash
chmod +x bootstrap.sh
./bootstrap.sh /path/to/your-project
# Pin a tag (default: v1.3.0):
./bootstrap.sh -t v1.3.0 /path/to/your-project
```

Override the remote with `WORKFLOW_KIT_REPO` (forks or mirrors).

### Windows (PowerShell) — no local clone first

`bootstrap.ps1` is a port of `bootstrap.sh` with the same behavior: it shallow-clones this repo at a tag and runs `install.ps1` in one step (works on Windows PowerShell 5.1+ and PowerShell 7+).

```powershell
.\bootstrap.ps1 C:\path\to\your-project
# Pin a tag (default: v1.3.0):
.\bootstrap.ps1 -t v1.3.0 C:\path\to\your-project
# Forward install.ps1 flags (e.g. the Django overlay):
.\bootstrap.ps1 --overlay django C:\path\to\your-project
```

Any options other than `-t`/`--tag` are forwarded to `install.ps1` unchanged. Override the remote with `$env:WORKFLOW_KIT_REPO`. If scripts are blocked by execution policy, run it for the current process only: `powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 C:\path\to\your-project`. The installed hook scripts (`*.sh`) need a bash runtime such as Git Bash to execute.

**Do not** run `install.sh` via `curl` from `raw.githubusercontent.com` **alone** — the script must sit next to a `bundle/` directory. Use **clone** or **bootstrap** instead.

**Optional one-liner** (fetches the whole bootstrap script, then it clones the repo):

```bash
curl -fsSL https://raw.githubusercontent.com/Katestheimeno/workflow-kit/v1.3.0/bootstrap.sh -o /tmp/wk-bootstrap.sh
chmod +x /tmp/wk-bootstrap.sh
/tmp/wk-bootstrap.sh /path/to/your-project
```

PowerShell one-liner equivalent (downloads `bootstrap.ps1`, then it clones the repo):

```powershell
irm https://raw.githubusercontent.com/Katestheimeno/workflow-kit/v1.3.0/bootstrap.ps1 -OutFile $env:TEMP\wk-bootstrap.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\wk-bootstrap.ps1 C:\path\to\your-project
```

Review any script before executing it. Prefer `git clone` for auditable installs.

## Options: `install.sh`

| Flag | Meaning |
|------|---------|
| `--dry-run` | Print actions only; no writes. |
| `--force` | If `.claude/CLAUDE_ENTRYPOINT.md` already exists, move the entire `.claude/` to `.claude.bak.<unix_epoch>` and do a full reinstall. |
| `--no-claude-example` | Do not copy `CLAUDE.md.example` to the target. |
| `--only-protocol` | Refresh `CLAUDE_ENTRYPOINT.md`, `example-feature/`, and the kit-owned content dirs (`agents/ commands/ rules/ prompts/`) from the bundle. **Does not** change `tasks/`, `CONTEXT_MAP.md`, or `CLAUDE.md.example`. Updates `.claude/WORKFLOW_KIT`. Use after upgrading a local copy of this repo. |
| `--overlay NAME` | After the generic core, apply the `bundle/overlays/NAME/` overlay (e.g. `--overlay django`). Overlay files override the generic agents/commands/rules/prompts. |
| `--version` | Print the kit version and exit. |
| `--help` | Help. |

If `CLAUDE.md.example` already exists at the target, it is **not** overwritten (a message is printed).

## Upgrading

- **Entrypoint and examples only** (keep your `tasks/` and edited `CONTEXT_MAP.md`): from a checked-out, up-to-date `workflow-kit` clone, run `./install.sh --only-protocol /path/to/your-project`.
- **Full replace** of `.claude/`: use `./install.sh --force /path/to/your-project` (backs up the previous tree). Merge any custom files from the backup if needed.
- Re-installing a **published** version: run `bootstrap.sh` with a newer `-t` tag after a release, or `git pull` in your kit clone and run `--only-protocol` or a full install as above.

## Publishing / initial push to GitHub (maintainers)

The default remote for this project is `git@github.com:Katestheimeno/workflow-kit.git` (GitHub: Katestheimeno/workflow-kit). To populate an empty remote from a working tree:

1. Create the repository on GitHub (if empty, no commits yet).
2. At the **root of the content** to publish, include: `README.md`, `VERSION`, `CHANGELOG.md`, `LICENSE`, `install.sh`, `install.ps1`, `bootstrap.sh`, `bootstrap.ps1`, `bundle/`.
3. From that directory:

```bash
git init
git add .
git commit -m "chore: workflow-kit v1.3.0"
git remote add origin git@github.com:Katestheimeno/workflow-kit.git
git branch -M main
git push -u origin main
git tag v1.3.0
git push origin v1.3.0
```

Tags enable `bootstrap.sh -t v1.3.0` and stable `raw.githubusercontent` URLs.

## Mirroring in another monorepo

You may keep a `workflow-kit/` subfolder in a larger project as a **copy** of this repository; after each release, sync via copy PR, subtree, or manual merge. The published repo remains the **canonical** home.

## Verification

```bash
./install.sh --version
./install.sh --dry-run /tmp/workflow-kit-test
./install.sh /tmp/workflow-kit-test
test -f /tmp/workflow-kit-test/.claude/WORKFLOW_KIT
./install.sh /tmp/workflow-kit-test   # should fail: entrypoint exists
./install.sh --only-protocol /tmp/workflow-kit-test
./install.sh --force /tmp/workflow-kit-test
```

## `raw.githubusercontent.com` references

Replace `v1.3.0` with the tag you published:

- Bootstrap: `https://raw.githubusercontent.com/Katestheimeno/workflow-kit/v1.3.0/bootstrap.sh`
- `install.sh` (only useful next to a full checkout or inside a release tarball, not by itself): `.../v1.3.0/install.sh`
