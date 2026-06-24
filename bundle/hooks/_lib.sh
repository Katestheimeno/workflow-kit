#!/usr/bin/env bash
# Shared helpers for workflow-kit hooks. Sourced, not executed directly.

wk_find_root() {
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" && -f "${CLAUDE_PROJECT_DIR}/.claude/CLAUDE_ENTRYPOINT.md" ]]; then
    echo "${CLAUDE_PROJECT_DIR}"
    return 0
  fi
  local d="$PWD"
  while [[ "$d" != "/" && -n "$d" ]]; do
    if [[ -f "$d/.claude/CLAUDE_ENTRYPOINT.md" ]]; then
      echo "$d"
      return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}

wk_strict() {
  [[ "${WORKFLOW_KIT_STRICT:-0}" == "1" ]]
}

# Print a warning to stderr. In strict mode, also exit 2 (blocks the tool call).
wk_warn() {
  echo "workflow-kit: $1" >&2
  if wk_strict; then
    exit 2
  fi
}

# Echo the active feature name, or return 1 if none.
wk_active_feature() {
  local plan="$1/.claude/tasks/MASTER_PLAN.md"
  [[ -f "$plan" ]] || return 1
  local v
  v="$(awk '
    /^## Active$/ {flag=1; next}
    /^## / {flag=0}
    flag && /^→/ {
      sub(/^→[[:space:]]*/, "")
      sub(/[[:space:]]*$/, "")
      print
      exit
    }
  ' "$plan")"
  [[ -z "$v" || "$v" == "none" ]] && return 1
  echo "$v"
}

wk_today() { date -u +%Y-%m-%d; }

# wk_over_cap <root> <file> — echo the line count if <file> exceeds the 250-line
# size cap (rules/file-architecture.md) AND is not exempt; otherwise echo nothing.
# Exemptions: kit-internal (.claude/), a built-in generated-file set, and any glob
# under `exclude_line_cap:` in .claude/config.yml. Always returns 0.
wk_over_cap() {
  local root="$1" file="$2"
  [[ -f "$file" ]] || return 0
  case "$file" in
    */.claude/*) return 0 ;;
    *.lock|*-lock.*|*.min.*|*.snap|*/migrations/*|*.generated.*|*_pb2.py|*.g.dart) return 0 ;;
  esac
  local lines
  lines=$(wc -l < "$file" 2>/dev/null || echo 0)
  (( lines > 250 )) || return 0
  local cfg="${root}/.claude/config.yml"
  if [[ -f "$cfg" ]]; then
    local rel="${file#"$root/"}" pat
    while IFS= read -r pat; do
      [[ -z "$pat" ]] && continue
      # shellcheck disable=SC2254
      case "$rel" in $pat) return 0 ;; esac
    # The print rule mutates $0 (sub/gsub), so it MUST `next` — otherwise the
    # following f=0 rule sees the rewritten bare glob (a non-space first char) and
    # ends the list after the first entry.
    done < <(awk '/^exclude_line_cap:/{f=1;next} f&&/^[[:space:]]*-/{sub(/^[[:space:]]*-[[:space:]]*/,"");gsub(/["'"'"']/,"");print;next} f&&/^[^[:space:]-]/{f=0}' "$cfg" 2>/dev/null || true)
  fi
  echo "$lines"
}
