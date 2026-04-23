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
| `.claude/hooks/` | Shell scripts: `session-start.sh`, `progress-heartbeat.sh`, `validate-state.sh`, `archive-feature.sh`, shared `_lib.sh` |
| `.claude/settings.json.example` | Sample Claude Code `hooks` wiring; **you merge it** into `.claude/settings.json` to activate |
| `CLAUDE.md.example` (optional) | Stub pointing at the entrypoint; copy or merge into your `CLAUDE.md` |

This kit does **not** ship language- or product-specific rules; add your own in-repo docs or tool-specific config (e.g. `.cursor/`, `AGENTS.md`).

## Hooks (enforce the protocol)

After install, merge `.claude/settings.json.example` into your `.claude/settings.json` to wire up:

- **SessionStart** → `hooks/session-start.sh` — prints active feature + `[IN_PROGRESS]` subtask so Claude opens aligned.
- **PostToolUse** (Edit|Write|MultiEdit) → `hooks/progress-heartbeat.sh` — warns on scope drift vs. the active subtask's `Allowed:` list; announces when a feature's subtasks are all `[COMPLETED]` and suggests archiving.
- **Stop** → `hooks/validate-state.sh` — checks invariants (at most one `[IN_PROGRESS]`, `MASTER_PLAN.md` Active matches reality).

Archive a finished feature with `.claude/hooks/archive-feature.sh <feature>`: writes `tasks/completed/<feature>.md`, moves the folder to `tasks/archive/<feature>/`, and rewrites the pointers in `MASTER_PLAN.md` and `CONTEXT_MAP.md`. `--dry-run` previews; `--force` archives incomplete features.

Hooks are **soft by default** (warnings on stderr). Set `WORKFLOW_KIT_STRICT=1` to make them exit 2 and block the tool call on violations.


## Install (recommended): clone, then run `install.sh`

```bash
git clone git@github.com:Katestheimeno/workflow-kit.git
cd workflow-kit
chmod +x install.sh bootstrap.sh
./install.sh /path/to/your-project
# or from inside the project (absolute path to install.sh is fine):
/path/to/workflow-kit/install.sh .
```

## Install with bootstrap (no local clone of the kit first)

If you have **git** and **network** access, `bootstrap.sh` shallow-clones this repo at a tag and runs `install.sh` in one step.

```bash
chmod +x bootstrap.sh
./bootstrap.sh /path/to/your-project
# Pin a tag (default: v1.1.0):
./bootstrap.sh -t v1.1.0 /path/to/your-project
```

Override the remote with `WORKFLOW_KIT_REPO` (forks or mirrors).

**Do not** run `install.sh` via `curl` from `raw.githubusercontent.com` **alone** — the script must sit next to a `bundle/` directory. Use **clone** or **bootstrap** instead.

**Optional one-liner** (fetches the whole bootstrap script, then it clones the repo):

```bash
curl -fsSL https://raw.githubusercontent.com/Katestheimeno/workflow-kit/v1.1.0/bootstrap.sh -o /tmp/wk-bootstrap.sh
chmod +x /tmp/wk-bootstrap.sh
/tmp/wk-bootstrap.sh /path/to/your-project
```

Review any script before executing it. Prefer `git clone` for auditable installs.

## Options: `install.sh`

| Flag | Meaning |
|------|---------|
| `--dry-run` | Print actions only; no writes. |
| `--force` | If `.claude/CLAUDE_ENTRYPOINT.md` already exists, move the entire `.claude/` to `.claude.bak.<unix_epoch>` and do a full reinstall. |
| `--no-claude-example` | Do not copy `CLAUDE.md.example` to the target. |
| `--only-protocol` | Refresh only `CLAUDE_ENTRYPOINT.md` and `example-feature/` from the bundle. **Does not** change `tasks/`, `CONTEXT_MAP.md`, or `CLAUDE.md.example`. Updates `.claude/WORKFLOW_KIT`. Use after upgrading a local copy of this repo. |
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
2. At the **root of the content** to publish, include: `README.md`, `VERSION`, `CHANGELOG.md`, `LICENSE`, `install.sh`, `bootstrap.sh`, `bundle/`.
3. From that directory:

```bash
git init
git add .
git commit -m "chore: workflow-kit v1.1.0"
git remote add origin git@github.com:Katestheimeno/workflow-kit.git
git branch -M main
git push -u origin main
git tag v1.1.0
git push origin v1.1.0
```

Tags enable `bootstrap.sh -t v1.1.0` and stable `raw.githubusercontent` URLs.

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

Replace `v1.1.0` with the tag you published:

- Bootstrap: `https://raw.githubusercontent.com/Katestheimeno/workflow-kit/v1.1.0/bootstrap.sh`
- `install.sh` (only useful next to a full checkout or inside a release tarball, not by itself): `.../v1.1.0/install.sh`
