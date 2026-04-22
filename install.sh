#!/usr/bin/env bash
# Installs the workflow-kit bundle into <target>/.claude/ and optionally CLAUDE.md.example at <target>/.
# Canonical source: https://github.com/Katestheimeno/workflow-kit
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="${SCRIPT_DIR}/bundle"
VERSION_FILE="${SCRIPT_DIR}/VERSION"
CANONICAL_SOURCE="https://github.com/Katestheimeno/workflow-kit"

DRY_RUN=0
FORCE=0
NO_CLAUDE_EXAMPLE=0
ONLY_PROTOCOL=0
TARGET_ARG=""

usage() {
  cat <<EOF
Usage: install.sh [OPTIONS] [TARGET_DIR]

  TARGET_DIR   Root of the project to install into (default: current directory).

Options:
  --dry-run            Print actions only; do not modify the filesystem.
  --force              If .claude/ already exists, move it to .claude.bak.<epoch> then full install.
  --no-claude-example  Do not copy CLAUDE.md.example to TARGET_DIR.
  --only-protocol      Refresh only CLAUDE_ENTRYPOINT.md and example-feature/ from the bundle.
                       Requires an existing install (.claude/CLAUDE_ENTRYPOINT.md). Does not modify
                       tasks/, CONTEXT_MAP.md, or CLAUDE.md.example. Writes/updates .claude/WORKFLOW_KIT.
  -h, --help           Show this help.
  --version            Print kit version and exit.

Full install refuses if .claude/CLAUDE_ENTRYPOINT.md already exists (use --force to replace).
Protocol-only: use after cloning or upgrading the kit to refresh the entrypoint without touching tasks/.


EOF
}

print_version() {
  local v
  v="$(tr -d ' \t\n\r' < "${VERSION_FILE}" 2>/dev/null || echo unknown)"
  echo "workflow-kit ${v}"
}

write_workflow_marker() {
  local claude_dir="$1"
  local target_dir="$2"
  local v="$3"
  local iso
  iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local path="${claude_dir}/WORKFLOW_KIT"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[dry-run] write ${path} (version, installed, source)"
    return 0
  fi
  cat >"${path}" <<EOF
# Written by workflow-kit install.sh; safe to commit for team visibility.
version=${v}
source=${CANONICAL_SOURCE}
installed=${iso}
target=${target_dir}
EOF
  echo "workflow-kit: wrote ${path}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --version)
      print_version
      exit 0
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --no-claude-example)
      NO_CLAUDE_EXAMPLE=1
      shift
      ;;
    --only-protocol)
      ONLY_PROTOCOL=1
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "${TARGET_ARG}" ]]; then
        echo "Multiple target directories specified." >&2
        exit 1
      fi
      TARGET_ARG="$1"
      shift
      ;;
  esac
done

if [[ ! -d "${BUNDLE_DIR}" ]]; then
  echo "workflow-kit: bundle directory not found: ${BUNDLE_DIR}" >&2
  exit 1
fi

TARGET="${TARGET_ARG:-.}"
if [[ ! -d "${TARGET}" ]]; then
  echo "workflow-kit: target is not a directory: ${TARGET}" >&2
  exit 1
fi
TARGET="$(cd "${TARGET}" && pwd)"

CLAUDE_DIR="${TARGET}/.claude"
ENTRYPOINT="${CLAUDE_DIR}/CLAUDE_ENTRYPOINT.md"
EXAMPLE_DST="${TARGET}/CLAUDE.md.example"
KIT_VER="$(tr -d ' \t\n\r' < "${VERSION_FILE}" 2>/dev/null || echo unknown)"

if [[ "${ONLY_PROTOCOL}" -eq 1 ]]; then
  if [[ "${FORCE}" -eq 1 ]]; then
    echo "workflow-kit: --force is ignored with --only-protocol (tasks/ and CONTEXT_MAP are never replaced)." >&2
  fi
  if [[ ! -f "${ENTRYPOINT}" ]]; then
    echo "workflow-kit: --only-protocol requires an existing install: ${ENTRYPOINT} not found." >&2
    echo "  Run a full install first: ./install.sh ${TARGET}" >&2
    exit 1
  fi
  echo "workflow-kit: protocol-only update (version ${KIT_VER}) → ${TARGET}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[dry-run] cp ${BUNDLE_DIR}/CLAUDE_ENTRYPOINT.md ${CLAUDE_DIR}/"
    if [[ -d "${BUNDLE_DIR}/example-feature" ]]; then
      echo "[dry-run] rm -rf ${CLAUDE_DIR}/example-feature && cp -a ${BUNDLE_DIR}/example-feature ${CLAUDE_DIR}/"
    fi
  else
    mkdir -p "${CLAUDE_DIR}"
    cp "${BUNDLE_DIR}/CLAUDE_ENTRYPOINT.md" "${CLAUDE_DIR}/"
    if [[ -d "${BUNDLE_DIR}/example-feature" ]]; then
      rm -rf "${CLAUDE_DIR}/example-feature"
      cp -a "${BUNDLE_DIR}/example-feature" "${CLAUDE_DIR}/"
    fi
  fi
  write_workflow_marker "${CLAUDE_DIR}" "${TARGET}" "${KIT_VER}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[dry-run] done (protocol-only)."
  else
    echo "workflow-kit: updated entrypoint and example-feature/ under ${CLAUDE_DIR}"
  fi
  exit 0
fi

if [[ -f "${ENTRYPOINT}" && "${FORCE}" -eq 0 ]]; then
  echo "workflow-kit: ${ENTRYPOINT} already exists." >&2
  echo "  Use --force to move existing .claude/ to .claude.bak.<epoch> and reinstall," >&2
  echo "  or --only-protocol to refresh entrypoint and example-feature/ only." >&2
  exit 1
fi

if [[ -d "${CLAUDE_DIR}/tasks" && "${FORCE}" -eq 0 && ! -f "${ENTRYPOINT}" ]]; then
  echo "workflow-kit: ${CLAUDE_DIR}/tasks already exists (no kit entrypoint). Refusing to overwrite." >&2
  echo "  Remove or move that directory, or use --force to back up the whole .claude/ and install." >&2
  exit 1
fi

if [[ "${FORCE}" -eq 1 && -d "${CLAUDE_DIR}" ]]; then
  BACKUP="${TARGET}/.claude.bak.$(date +%s)"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[dry-run] mv ${CLAUDE_DIR} ${BACKUP}"
  else
    mv "${CLAUDE_DIR}" "${BACKUP}"
    echo "workflow-kit: backed up existing .claude to ${BACKUP}"
  fi
fi

install_claude_tree() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[dry-run] mkdir -p ${CLAUDE_DIR}"
    echo "[dry-run] cp ${BUNDLE_DIR}/CLAUDE_ENTRYPOINT.md ${CLAUDE_DIR}/"
    echo "[dry-run] cp ${BUNDLE_DIR}/CONTEXT_MAP.md ${CLAUDE_DIR}/"
    echo "[dry-run] cp -a ${BUNDLE_DIR}/tasks ${CLAUDE_DIR}/"
    if [[ -d "${BUNDLE_DIR}/example-feature" ]]; then
      echo "[dry-run] cp -a ${BUNDLE_DIR}/example-feature ${CLAUDE_DIR}/"
    fi
    return
  fi

  mkdir -p "${CLAUDE_DIR}"
  cp "${BUNDLE_DIR}/CLAUDE_ENTRYPOINT.md" "${CLAUDE_DIR}/"
  cp "${BUNDLE_DIR}/CONTEXT_MAP.md" "${CLAUDE_DIR}/"
  rm -rf "${CLAUDE_DIR}/tasks"
  cp -a "${BUNDLE_DIR}/tasks" "${CLAUDE_DIR}/"
  if [[ -d "${BUNDLE_DIR}/example-feature" ]]; then
    rm -rf "${CLAUDE_DIR}/example-feature"
    cp -a "${BUNDLE_DIR}/example-feature" "${CLAUDE_DIR}/"
  fi
}

install_example() {
  [[ "${NO_CLAUDE_EXAMPLE}" -eq 1 ]] && return 0
  if [[ -f "${EXAMPLE_DST}" ]]; then
    echo "workflow-kit: ${EXAMPLE_DST} already exists; skipping (remove it or merge manually)." >&2
    return 0
  fi
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[dry-run] cp ${BUNDLE_DIR}/CLAUDE.md.example ${EXAMPLE_DST}"
    return 0
  fi
  cp "${BUNDLE_DIR}/CLAUDE.md.example" "${EXAMPLE_DST}"
  echo "workflow-kit: wrote ${EXAMPLE_DST}"
}

echo "workflow-kit: installing kit version ${KIT_VER} into ${TARGET}"

install_claude_tree
write_workflow_marker "${CLAUDE_DIR}" "${TARGET}" "${KIT_VER}"
install_example

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[dry-run] done."
else
  echo "workflow-kit: installed .claude/ task checkpoint under ${CLAUDE_DIR}"
  echo "workflow-kit: read ${ENTRYPOINT} first for every AI-assisted session."
fi
