#!/bin/bash
# Stop and remove a dev container — best-effort, never fails the caller.
#
# Usage:
#   ./devcontainer-down.sh --workspace <path> [--name <name>]
#
# Stops and removes the dev container associated with the given workspace.
# Falls back to finding the container by label and force-removing it.
# Always exits 0.

WORKSPACE=""
NAME=""

usage() {
  echo "Usage: $(basename "$0") --workspace <path> [options]"
  echo ""
  echo "Options:"
  echo "  --workspace <path>  Path to the workspace folder (required)"
  echo "  --name <name>       Container name label to help identify the container (optional)"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0") --workspace /path/to/repo"
  echo "  $(basename "$0") --workspace /path/to/repo --name myapp-feature-x"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --workspace)
      WORKSPACE="$2"
      shift 2
      ;;
    --workspace=*)
      WORKSPACE="${1#*=}"
      shift
      ;;
    --name)
      NAME="$2"
      shift 2
      ;;
    --name=*)
      NAME="${1#*=}"
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

if [ -z "$WORKSPACE" ]; then
  echo "Error: --workspace is required."
  usage
fi

WORKSPACE="$(cd "$WORKSPACE" 2>/dev/null && pwd)" || WORKSPACE="$WORKSPACE"

echo "Stopping dev container for workspace: $WORKSPACE"

# Try devcontainer down first (available in newer versions of @devcontainers/cli)
devcontainer down --workspace-folder "$WORKSPACE" 2>/dev/null || true

# Fallback: find container by label and force-remove it
CONTAINER_ID=$(docker ps -aq --filter "label=devcontainer.local_folder=$WORKSPACE" 2>/dev/null | head -1)

if [ -n "$CONTAINER_ID" ]; then
  echo "Found container $CONTAINER_ID by workspace label, force-removing..."
  docker rm -f "$CONTAINER_ID" 2>/dev/null || true
fi

# Also try by name label if provided
if [ -n "$NAME" ]; then
  CONTAINER_ID=$(docker ps -aq --filter "label=devcontainer.name=$NAME" 2>/dev/null | head -1)
  if [ -n "$CONTAINER_ID" ]; then
    echo "Found container $CONTAINER_ID by name label, force-removing..."
    docker rm -f "$CONTAINER_ID" 2>/dev/null || true
  fi
fi

echo "Dev container cleaned up: $WORKSPACE"
exit 0
