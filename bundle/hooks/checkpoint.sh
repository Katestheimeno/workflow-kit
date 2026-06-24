#!/usr/bin/env bash
# Checkpoint protocol reminder — injected before every user prompt.
# Surfaces the active feature via wk_active_feature (shared with the other hooks)
# so the reminder is accurate and the "no active feature" sentinel is handled in
# exactly one place. (Previously this hook reimplemented the parser inline and
# mistook the default "→ none" state for a feature literally named "none".)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

ROOT="$(wk_find_root)" || exit 0

# wk_active_feature returns the bare feature folder name, or fails when Active is
# unset (→ none). flow.md writes the bare name, so this maps straight to a folder.
feat="$(wk_active_feature "$ROOT" 2>/dev/null || true)"
if [[ -n "$feat" ]]; then
  FEATURE_LINE="Active feature: ${feat} → read .claude/tasks/${feat}/MASTER_TASKS.md, find [IN_PROGRESS] subtask (or mark first [PENDING] as [IN_PROGRESS])."
else
  FEATURE_LINE="No active feature. If user requests a new feature, create a plan in .claude/tasks/{feature}/."
fi

cat <<EOF
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "CHECKPOINT PROTOCOL (mandatory before acting):\n1. Read .claude/CONTEXT_MAP.md — full project state.\n2. Read .claude/tasks/MASTER_PLAN.md — active feature and queue.\n3. ${FEATURE_LINE}\n4. Update subtask Status: [IN_PROGRESS] when starting, [COMPLETED] when done (validation must pass first).\n5. When a feature completes: update MASTER_TASKS.md status, create .claude/tasks/completed/{feature}.md summary, move feature folder to .claude/tasks/archive/, update MASTER_PLAN.md (Active → none, add to Completed), update .claude/CONTEXT_MAP.md."
  }
}
EOF
