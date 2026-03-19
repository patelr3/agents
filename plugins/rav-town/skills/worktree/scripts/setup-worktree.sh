#!/bin/bash
# Setup Git Worktree - Create a branch and worktree without changing HEAD
#
# Usage:
#   ./setup-worktree.sh --branch <name> [--base-ref <ref>] [--worktree-dir <path>]
#                       [--existing-branch] [--plan-file <path>] [--plan-status <status>]
#
# Creates a new branch from base-ref (default: HEAD) using git update-ref so the
# current working tree is never disturbed, then adds a worktree for that branch.

set -e

BRANCH=""
BASE_REF="HEAD"
WORKTREE_DIR=""
EXISTING_BRANCH=false
PLAN_FILE=""
PLAN_STATUS=""

usage() {
  echo "Usage: $(basename "$0") --branch <name> [options]"
  echo ""
  echo "Options:"
  echo "  --branch <name>        Branch name to create (required)"
  echo "  --base-ref <ref>       Base commit/branch/tag (default: HEAD)"
  echo "  --worktree-dir <path>  Worktree directory path (auto-derived if omitted)"
  echo "  --existing-branch      Skip branch creation, fetch from origin instead"
  echo "  --plan-file <path>     Path to a plan file relative to repo root"
  echo "  --plan-status <status> Set the YAML frontmatter status: field in the plan file"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0") --branch feat/new-feature --base-ref main"
  echo "  $(basename "$0") --branch fix/bug-123 --existing-branch"
  echo "  $(basename "$0") --branch ralph/task-1 --plan-file docs/plan.md --plan-status inprogress"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --branch=*)
      BRANCH="${1#*=}"
      shift
      ;;
    --base-ref)
      BASE_REF="$2"
      shift 2
      ;;
    --base-ref=*)
      BASE_REF="${1#*=}"
      shift
      ;;
    --worktree-dir)
      WORKTREE_DIR="$2"
      shift 2
      ;;
    --worktree-dir=*)
      WORKTREE_DIR="${1#*=}"
      shift
      ;;
    --existing-branch)
      EXISTING_BRANCH=true
      shift
      ;;
    --plan-file)
      PLAN_FILE="$2"
      shift 2
      ;;
    --plan-file=*)
      PLAN_FILE="${1#*=}"
      shift
      ;;
    --plan-status)
      PLAN_STATUS="$2"
      shift 2
      ;;
    --plan-status=*)
      PLAN_STATUS="${1#*=}"
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Error: Unknown option '$1'"
      usage
      ;;
  esac
done

# --- Validation ---

if [ -z "$BRANCH" ]; then
  echo "Error: --branch is required."
  usage
fi

REPO_ROOT=$(git rev-parse --show-toplevel)

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "Error: base-ref '$BASE_REF' does not resolve to a valid commit."
  exit 1
fi

# --- Auto-derive worktree directory ---

if [ -z "$WORKTREE_DIR" ]; then
  PROJECT_NAME=$(basename "$REPO_ROOT")
  BRANCH_SUFFIX="${BRANCH#feat/}"
  BRANCH_SUFFIX="${BRANCH_SUFFIX#fix/}"
  BRANCH_SUFFIX="${BRANCH_SUFFIX#chore/}"
  BRANCH_SUFFIX="${BRANCH_SUFFIX#ralph/}"
  WORKTREE_DIR="$(dirname "$REPO_ROOT")/${PROJECT_NAME}-${BRANCH_SUFFIX}"
fi

if [ -d "$WORKTREE_DIR" ]; then
  echo "Error: Worktree directory already exists: $WORKTREE_DIR"
  exit 1
fi

# --- Create or fetch branch ---

if [ "$EXISTING_BRANCH" = true ]; then
  echo "Fetching existing branch '$BRANCH' from origin..."
  git fetch origin "$BRANCH"
else
  echo "Creating branch '$BRANCH' from '$BASE_REF' (without changing HEAD)..."
  RESOLVED_REF=$(git rev-parse "$BASE_REF")
  git update-ref "refs/heads/$BRANCH" "$RESOLVED_REF"
  echo "Pushing branch '$BRANCH' to origin..."
  git push -u origin "$BRANCH"
fi

# --- Create worktree ---

echo "Adding worktree at '$WORKTREE_DIR' for branch '$BRANCH'..."
git worktree add "$WORKTREE_DIR" "$BRANCH"

if [ ! -d "$WORKTREE_DIR" ]; then
  echo "Error: Worktree directory was not created: $WORKTREE_DIR"
  exit 1
fi

echo "Worktree created successfully."

# --- Update plan file status ---

if [ -n "$PLAN_FILE" ] && [ -n "$PLAN_STATUS" ]; then
  echo "Updating plan file status to '$PLAN_STATUS'..."
  cd "$WORKTREE_DIR"

  if [ ! -f "$PLAN_FILE" ]; then
    echo "Error: Plan file not found in worktree: $PLAN_FILE"
    exit 1
  fi

  # Update the status: field within YAML frontmatter (between --- markers)
  sed -i "0,/^status:.*/{s/^status:.*/status: ${PLAN_STATUS}/}" "$PLAN_FILE"

  git add -A
  git commit -m "chore: set $(basename "$PLAN_FILE") status to $PLAN_STATUS"
  git push

  cd "$REPO_ROOT"
  echo "Plan file updated and pushed."
fi

# --- Output worktree path (last line for callers to capture) ---

echo "$WORKTREE_DIR"
exit 0
