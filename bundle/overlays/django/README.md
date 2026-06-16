# Django overlay

The generic core that workflow-kit installs (`.claude/agents/`, `.claude/commands/`,
`.claude/rules/`, `.claude/prompts/`) is **stack-agnostic** — it describes *how* work
flows through agents without committing to any language or framework.

This overlay replaces those generic files with **Django / DRF–flavored** versions: the
same orchestration structure, but written in concrete Django terms (controllers →
services → selectors → models, `uv run pytest --ds=config.django.test`, DRF serializers
and permissions, Celery, Channels, OpenAPI/`drf-spectacular`, etc.). It also adds Django
rules and prompts the generic core deliberately omits.

## What's in here

| Path | Replaces / adds |
|------|-----------------|
| `agents/` | Django versions of all 10 agents (orchestrator, planner, implementer, explorer, code-reviewer, test-writer, doc-writer, security-auditor, sweep-analyzer, sweep-reviewer) |
| `commands/` | Django versions of `/sweep` and `/flow` |
| `prompts/` | Django `sweep.md`, plus `api-contract-validation.md`, `docs-alignment-audit.md`, `parallel-django-app-audit.md` |
| `rules/` | `foundations.md`, `django.md`, `layers.md`, `api.md`, `quality.md`, `testing.md`, `workflow.md`, `docs.md` |

## How to apply it

During install:

```bash
./install.sh --overlay django /path/to/your-project
```

This installs the generic core first, then copies the overlay files over it (overlay
files win). The checkpoint protocol, task system, and hooks are unchanged.

To apply the overlay to an already-installed project, copy the trees manually:

```bash
cp -r bundle/overlays/django/agents/*   /path/to/your-project/.claude/agents/
cp -r bundle/overlays/django/commands/* /path/to/your-project/.claude/commands/
cp -r bundle/overlays/django/rules/*    /path/to/your-project/.claude/rules/
cp -r bundle/overlays/django/prompts/*  /path/to/your-project/.claude/prompts/
```

## Caveats

These files came from a real Django project. A few references are project-specific and
should be adapted to yours:

- Settings module names (`config.django.test`, `config/settings/`).
- Helper imports (`config.logger`, `read_from_primary` from `config/db_utils.py`).
- Skill references in `rules/quality.md` and `rules/foundations.md` (e.g.
  `.claude/skills/run-tests-skill.md`, `.cursor/changes/`) — these are not shipped by the
  kit. Either remove the references or add your own equivalents.
- `rules/foundations.md` cross-references `rules/django.md`, `rules/layers.md`, and
  `rules/api.md`, all of which are included here.

The agents are written to read `.claude/rules/*.md` as the source of truth, so once the
overlay rules match your project, the agents follow them.
