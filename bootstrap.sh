#!/usr/bin/env bash
# Shallow-clone Katestheimeno/workflow-kit at a tag and run install.sh against a target project.
# Use when you do not have the kit checked out (e.g. one-line install from a clean machine with git + network).
set -euo pipefail

REPO_DEFAULT="git@github.com:Katestheimeno/workflow-kit.git"
REPO="${WORKFLOW_KIT_REPO:-${REPO_DEFAULT}}"

TAG="v1.1.0"
TARGET_ARG=""

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [OPTIONS] <TARGET_PROJECT_DIR>

  Clones the workflow-kit repository at a tag into a temporary directory, runs
  install.sh against TARGET_PROJECT_DIR, then removes the clone.

Options:
  -t, --tag TAG   Git tag to clone (default: v1.1.0). Must exist on the remote.
  -h, --help      Show this help.

Environment:
  WORKFLOW_KIT_REPO   Override the git URL (default: git@github.com:Katestheimeno/workflow-kit.git).

Requires: git, bash, and network access to GitHub.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -t | --tag)
      if [[ -z "${2:-}" ]]; then
        echo "bootstrap: --tag requires a value." >&2
        exit 1
      fi
      TAG="$2"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "${TARGET_ARG}" ]]; then
        echo "bootstrap: multiple targets specified." >&2
        exit 1
      fi
      TARGET_ARG="$1"
      shift
      ;;
  esac
done

if [[ -z "${TARGET_ARG}" ]]; then
  echo "bootstrap: TARGET_PROJECT_DIR is required." >&2
  usage >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "bootstrap: git is not installed or not in PATH." >&2
  exit 1
fi

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/workflow-kit-bootstrap.XXXXXX")"
cleanup() { rm -rf "${TMPROOT}"; }
trap cleanup EXIT

CLONE_DIR="${TMPROOT}/workflow-kit"
# Non-interactive clone: fail if tag is missing
export GIT_TERMINAL_PROMPT=0
git clone --depth 1 --branch "${TAG}" "${REPO}" "${CLONE_DIR}"

if [[ ! -x "${CLONE_DIR}/install.sh" ]]; then
  echo "bootstrap: install.sh not found or not executable in clone." >&2
  exit 1
fi

echo "bootstrap: using tag ${TAG}, running ${CLONE_DIR}/install.sh ${TARGET_ARG}"
exec "${CLONE_DIR}/install.sh" "${TARGET_ARG}"
