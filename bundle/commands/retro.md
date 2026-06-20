# Retrospective

Produce a complete, presentation-ready **retrospective package** — not a single document, but a
navigable **directory** of grouped change records, a change inventory, a timeline, an open-items
register, and speaker-ready presentation material — covering a chosen period of work.

Where `/weekly-summary` documents *one week* from git, `/retro` **aggregates** across one or more
weeks (defaulting to the last two), cross-referencing the weekly summaries, the task plans, and the
raw git history into a stakeholder-facing retrospective you can read, verify independently, and
present today.

## Usage

```
/retro                          Last two weeks (default)
/retro 3 weeks                  Last N weeks ending today
/retro last week                A single week
/retro 2026-06-01..2026-06-14   An explicit date range (inclusive)
/retro since 2026-06-01         From a date through today
/retro Q2 auth hardening        N weeks (default 2) + a theme hint to frame the narrative
```

Anything in `$ARGUMENTS` that is **not** a recognized period token is treated as a **theme hint** —
free text used to frame the executive narrative and grouping, never to filter out changes.

## Instructions

You are a senior engineering analyst preparing a formal technical retrospective. Your output is a
**directory of linked Markdown files**, structured so a presenter can open any change in one click
during a meeting and so a reader who was *not present* can understand everything cold.

### Input

```
$ARGUMENTS
```

### Phase 0 — Resolve the period and output location

1. **Parse the period** from `$ARGUMENTS` (resolve relative references with the shell so they are
   unambiguous):
   - **Empty** → last 14 days, i.e. `{today − 13 days}` → `{today}`.
   - `N weeks` / `N week` → last `N × 7` days ending today.
   - `last week` → the previous Monday–Sunday week.
   - `since {date}` → `{date}` → today.
   - `{date}..{date}` → that explicit inclusive range.
   - A bare date → the Monday–Sunday week containing it.

   ```bash
   date +%F                      # today
   date -d "13 days ago" +%F     # default window start
   date -d "N weeks ago" +%F     # N-week window start
   ```

2. **Separate the theme hint.** Strip recognized period tokens from `$ARGUMENTS`; whatever remains
   is the theme hint. If empty, infer the theme yourself in Phase 2.

3. **Build the output directory** named by the resolved range:
   ```
   docs/retrospectives/{START}_to_{END}/
   ```
   Example: `docs/retrospectives/2026-06-07_to_2026-06-20/`. Create it (and any parent dirs). If it
   already exists, treat this as a **regeneration** — read existing files first, preserve any
   manually added context (notes, corrections), and refresh the rest.

### Phase 1 — Discovery (do this silently, before writing anything)

Gather from **every** available source. The weekly summaries and task plans are the narrative
backbone; git is the source of truth that verifies and fills gaps.

1. **Weekly summaries** — read every `docs/changes/{YYYY}/{MM}/week{N}.md` whose period overlaps the
   range. These already contain daily breakdowns, initiatives, impact metrics, and documentation
   produced. Use them as the primary structure.
   - If a week in range has **no** summary file, generate that week's data inline from git (same
     queries as `/weekly-summary` Phase 1) so the retrospective has no blind spots. Note in the
     final report which weeks lacked a pre-existing summary.

2. **Task plans** — read `.claude/tasks/MASTER_PLAN.md` and each active feature's
   `.claude/tasks/{feature}/MASTER_TASKS.md`. Capture which subtasks moved to `[COMPLETED]` in the
   range, what is `[IN PROGRESS]`, and what is `[BLOCKED]` or deferred.

3. **Project context** — read `CONTEXT_MAP.md` (or the bundle equivalent) for project overview,
   active feature, known constraints, and current technical debt.

4. **Git history across the full range** (not per-week — the whole window at once):
   ```bash
   git log --after="{START} 00:00" --before="{END} 23:59:59" --format="%H|%h|%ai|%an|%s" --no-merges
   git log --after="{START} 00:00" --before="{END} 23:59:59" --stat --no-merges
   git diff --stat {first_commit}^..{last_commit}      # range churn
   git status --short                                   # uncommitted work, if range includes today
   ```

5. **Inventory every distinct change** — one entry per discrete change, task, decision, or artifact.
   Do **not** collapse distinct changes. For each, capture: area, before-state, after-state,
   rationale, implementation approach, the **challenge/obstacle** encountered and how it was
   resolved, verification method, and dependencies on other changes. Flag anything ambiguous or
   where context is incomplete rather than inventing detail.

6. **Group** the inventory into logical domains/areas (backend, frontend, infra, config, docs,
   tests, tooling, etc.) and into initiatives/work-streams (matching the weekly summaries' "Active
   initiatives" where possible).

### Phase 2 — Write the retrospective package

Write these files into the output directory. **Every file is cross-linked** with relative Markdown
links so the package is navigable during a live presentation.

```
docs/retrospectives/{START}_to_{END}/
├── README.md                      # entry point: nav index + executive overview
├── 01-change-inventory.md         # the master table, links to each change record
├── 02-timeline.md                 # chronological narrative across the period
├── 03-open-items-and-risks.md     # unfinished work, tech debt, follow-ups
├── 04-challenges.md               # consolidated obstacles & how they were solved
├── changes/
│   ├── CHANGE-01-{slug}.md        # one self-contained record per discrete change
│   ├── CHANGE-02-{slug}.md
│   └── …
├── by-area/                       # grouped index pages (one per domain present)
│   ├── backend.md                 # links to the CHANGE records in this area
│   ├── frontend.md
│   └── …
└── presentation/
    ├── slides.md                  # slide-by-slide outline for the deck
    └── speaker-notes.md           # ordered talking points + demo cues
```

#### `README.md` — entry point

```markdown
# Retrospective — {START} → {END}

**Theme:** {theme hint, or inferred theme}
**Branch:** `{branch}`  ·  **Generated:** {now}
**Weeks covered:** {list of week files used; flag any generated inline}

## Executive overview
{8–12 sentences: the sprint goal/theme; what was delivered vs what remains open;
the single biggest technical decision and why; overall risk posture.}

## Navigate
- 📋 [Change inventory](01-change-inventory.md) — {N} changes
- 🕐 [Timeline](02-timeline.md)
- ⚠️ [Open items & risks](03-open-items-and-risks.md) — {N} open
- 🧗 [Challenges](04-challenges.md)
- 🗂 By area: {links to each by-area/ page}
- 🎤 Presentation: [slides](presentation/slides.md) · [speaker notes](presentation/speaker-notes.md)

## At a glance
| Metric | Value |
|--------|-------|
| Changes | {N} |
| Commits | {N} |
| Files changed | {N} |
| Insertions / deletions | +{N} / -{N} |
| Initiatives advanced | {N} |
| Open items | {N} |
| Areas touched | {list} |
```

#### `01-change-inventory.md` — master table

One row per discrete change; the title links to its record.

```markdown
# Change inventory — {START} → {END}

| # | Area | Change | Status | Risk | Record |
|---|------|--------|--------|------|--------|
| 1 | backend | {title} | DONE | LOW | [CHANGE-01](changes/CHANGE-01-{slug}.md) |
| 2 | infra | {title} | IN PROGRESS | MEDIUM | [CHANGE-02](changes/CHANGE-02-{slug}.md) |
```

- **Status:** `DONE` / `IN PROGRESS` / `REVERTED` / `DEFERRED`
- **Risk:** `LOW` / `MEDIUM` / `HIGH`

#### `changes/CHANGE-NN-{slug}.md` — one per change (self-contained)

```markdown
# CHANGE-{NN}: {Title}

[← Inventory](../01-change-inventory.md) · Area: **{area}** · Status: **{status}** · Risk: **{risk}**

**Files / components affected:** {every file, module, or system touched — concrete paths}
**Commits:** {short hashes, dated}

## Before
{The exact prior state — what existed, what was the problem or gap.}

## After
{The new state — what was built, modified, or removed.}

## Why
{What triggered this change; what problem it solves.}

## How
{Implementation approach — key decisions, patterns used, tradeoffs made.}

## Challenge
{The obstacle hit (technical, ambiguity, dependency) and how it was resolved.
If none, say "Straightforward — no notable obstacle."}

## Verification
{How a reader can independently confirm this works — command to run, file to inspect,
test to read, commit to diff. Reference concrete artifacts.}

## Linked changes
{Other CHANGE-NN records this depends on or affects, as relative links.}
```

Write **one record per inventory row** — no omissions, even minor config tweaks or small refactors.

#### `02-timeline.md` — chronological narrative

A day-by-day (or commit-cluster) sequence across the full range, each entry linking to the relevant
CHANGE records. Reconstruct from commit dates and the weekly summaries' daily breakdowns.

#### `03-open-items-and-risks.md`

- Work started but not finished (link to the CHANGE record and the task plan).
- Technical debt introduced this period.
- Decisions that need follow-up or stakeholder sign-off.
- Uncommitted work, if the range includes today.

#### `04-challenges.md`

A consolidated view of the obstacles surfaced in the per-change `## Challenge` sections — the
"war stories" for the retrospective discussion. Group by theme; link back to each CHANGE record.

#### `by-area/{area}.md` — grouped index

One page per area present, listing its CHANGE records with one-line summaries, so the presenter can
drill into a single domain on demand.

#### `presentation/slides.md` and `presentation/speaker-notes.md`

- **slides.md** — a slide-by-slide outline: title, theme, "what we shipped", per-initiative slides,
  challenges slide, open-items slide, next-steps slide. Each slide cites the CHANGE records behind it.
- **speaker-notes.md** — an ordered walkthrough with talking points and demo cues ("open
  CHANGE-04 to show the before/after"), timed for a short stakeholder presentation.

### Phase 3 — Report

After writing the package, report to the user:
- The output directory path.
- A tree of the files created/updated.
- Counts: changes inventoried, commits covered, areas, open items.
- Any weeks in range that lacked a pre-existing weekly summary (generated inline).
- Anything flagged as ambiguous or incomplete that needs the user's confirmation.
- A one-line suggestion to run `/weekly-summary` for any missing week so future retros are richer.

### Principles

- **No omission.** Every distinct change gets its own record — minor tweaks included. Never collapse
  distinct changes into one entry.
- **Verifiable.** Every claim traces to a commit hash, a file diff, a task status, or a weekly
  summary. Reference concrete artifacts; never invent detail. If something is unclear, say so
  explicitly in that section.
- **Self-contained per file.** Each CHANGE record must stand alone — a reader opening it cold,
  mid-presentation, should understand the whole change without the rest of the package.
- **Navigable.** Everything is cross-linked with relative paths. The README is the single entry
  point; no file is an orphan.
- **Weekly summaries are the backbone, git is the truth.** Prefer the narrative already captured in
  `docs/changes/`; use git to verify it and fill any gaps.
- **Regeneration-safe.** Re-running for the same range refreshes generated content but preserves any
  human-added notes or corrections.
- **Audience-aware.** Technical language for a developer audience in the change records; the
  presentation/ material is framed for stakeholders.
