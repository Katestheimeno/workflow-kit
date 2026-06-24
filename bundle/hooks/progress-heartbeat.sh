#!/usr/bin/env bash
# PostToolUse hook for Edit|Write|MultiEdit: flags feature completion and scope drift.
# Reads tool JSON on stdin; warns on stderr. In strict mode, warnings exit 2 (block).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

ROOT="$(wk_find_root)" || exit 0

INPUT="$(cat || true)"
FILE=""
if [[ -n "$INPUT" ]]; then
  if command -v jq >/dev/null 2>&1; then
    FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
  fi
  if [[ -z "$FILE" ]]; then
    FILE="$(printf '%s' "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')"
  fi
fi
[[ -z "$FILE" ]] && exit 0

# Size cap: warn when a non-generated source file exceeds 250 lines.
# (see .claude/rules/file-architecture.md). Honors exclude_line_cap globs from
# .claude/config.yml if present; otherwise skips a built-in generated-file set.
if [[ -f "$FILE" ]]; then
  case "$FILE" in
    */.claude/*) ;;  # kit-internal files are exempt
    *.lock|*-lock.*|*.min.*|*.snap|*/migrations/*|*.generated.*|*_pb2.py|*.g.dart) ;;
    *)
      lines=$(wc -l < "$FILE" 2>/dev/null || echo 0)
      if (( lines > 250 )); then
        excluded=0
        cfg="${ROOT}/.claude/config.yml"
        if [[ -f "$cfg" ]]; then
          rel="${FILE#"$ROOT/"}"
          while IFS= read -r pat; do
            [[ -z "$pat" ]] && continue
            # shellcheck disable=SC2254
            case "$rel" in $pat) excluded=1; break ;; esac
          done < <(awk '/^exclude_line_cap:/{f=1;next} f&&/^[[:space:]]*-/{sub(/^[[:space:]]*-[[:space:]]*/,"");gsub(/["'"'"']/,"");print} f&&/^[^[:space:]-]/{f=0}' "$cfg" 2>/dev/null || true)
        fi
        if (( excluded == 0 )); then
          wk_warn "Size cap: ${FILE} is ${lines} lines (>250). See rules/file-architecture.md — split before continuing."
        fi
      fi
      ;;
  esac
fi

# Case 1: the edit is a MASTER_TASKS.md — check for feature completion.
if [[ "$FILE" == */.claude/tasks/*/MASTER_TASKS.md ]]; then
  feat="$(basename "$(dirname "$FILE")")"
  total="$(grep -cE '^- \[(PENDING|IN_PROGRESS|BLOCKED|COMPLETED|SKIPPED|DEFERRED)\]' "$FILE" || true)"
  done="$(grep -cE '^- \[COMPLETED\]' "$FILE" || true)"
  if [[ "${total:-0}" -gt 0 && "${done:-0}" -eq "${total:-0}" ]]; then
    echo "workflow-kit: feature '${feat}' — all ${total} subtasks [COMPLETED]." >&2
    echo "  → archive with: ${ROOT}/.claude/hooks/archive-feature.sh ${feat}" >&2
  fi
  exit 0
fi

# Case 2: edits inside .claude/ are bookkeeping; skip scope checks.
case "$FILE" in
  */.claude/*) exit 0 ;;
esac

# Case 3: scope drift against the active [IN_PROGRESS] subtask.
feat="$(wk_active_feature "$ROOT" 2>/dev/null || true)"
[[ -z "$feat" ]] && exit 0
mt="${ROOT}/.claude/tasks/${feat}/MASTER_TASKS.md"
[[ -f "$mt" ]] || exit 0

sub_rel="$(awk '
  /\[IN_PROGRESS\]/ {
    if (match($0, /\[[^]]+\]\(([^)]+)\)/, a)) { print a[1]; exit }
    if (match($0, /\(([^)]+\.md)\)/, b)) { print b[1]; exit }
  }
' "$mt" 2>/dev/null || true)"
[[ -z "$sub_rel" ]] && exit 0

sub_path="${ROOT}/.claude/tasks/${feat}/${sub_rel}"
[[ -f "$sub_path" ]] || exit 0

allowed="$(awk '
  /^Allowed:[[:space:]]*$/ {f=1; next}
  /^Forbidden:/ {f=0}
  /^##[[:space:]]/ {f=0}
  f && /^- / {sub(/^- /,""); sub(/[[:space:]]*$/,""); print}
' "$sub_path")"

[[ -z "$allowed" ]] && exit 0

match=0
while IFS= read -r pat; do
  [[ -z "$pat" ]] && continue
  case "$pat" in
    /*) abs="$pat" ;;
    *)  abs="${ROOT}/${pat}" ;;
  esac
  # shellcheck disable=SC2254
  case "$FILE" in
    $abs) match=1; break ;;
  esac
done <<< "$allowed"

if [[ "$match" -eq 0 ]]; then
  wk_warn "Drift: edited ${FILE} is outside subtask Scope (${sub_rel} under '${feat}'). Update the subtask's Scope: block before continuing, or stop."
fi

exit 0
