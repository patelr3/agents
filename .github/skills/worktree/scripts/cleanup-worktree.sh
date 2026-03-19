#!/bin/bash
# Cleanup a git worktree — best-effort, never fails the caller.
#
# Usage:
#   ./cleanup-worktree.sh --worktree-dir <path>

usage() {
  echo "Usage: ./cleanup-worktree.sh --worktree-dir <path>"
  echo ""
  echo "Options:"
  echo "  --worktree-dir <path>  Worktree directory to remove (required)"
  exit 0
}

WORKTREE_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --worktree-dir)
      WORKTREE_DIR="$2"
      shift 2
      ;;
    --worktree-dir=*)
      WORKTREE_DIR="${1#*=}"
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$WORKTREE_DIR" ]; then
  echo "Error: --worktree-dir <path> is required."
  usage
fi

# Navigate to repo root
cd "$(git rev-parse --show-toplevel)" 2>/dev/null || true

# Remove worktree
git worktree remove "$WORKTREE_DIR" --force 2>/dev/null || true

# Prune stale worktree metadata
git worktree prune 2>/dev/null || true

# Fallback: if directory still exists, force-remove it
if [ -d "$WORKTREE_DIR" ]; then
  rm -rf "$WORKTREE_DIR"
  git worktree prune 2>/dev/null || true
fi

echo "Worktree cleaned up: $WORKTREE_DIR"
exit 0
