#!/bin/bash
# Build and start a dev container using @devcontainers/cli
#
# Usage:
#   ./devcontainer-up.sh --workspace <path> [--name <name>]
#
# Builds and starts a dev container from the workspace's .devcontainer/ config.
# Outputs the container ID on the last line for callers to capture.

set -e

WORKSPACE=""
NAME=""

usage() {
  echo "Usage: $(basename "$0") --workspace <path> [options]"
  echo ""
  echo "Options:"
  echo "  --workspace <path>  Path to the workspace folder containing .devcontainer/ (required)"
  echo "  --name <name>       Name label for the dev container instance (optional)"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0") --workspace /path/to/repo"
  echo "  $(basename "$0") --workspace /path/to/repo --name myapp-feature-x"
  exit 1
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
      echo "Error: Unknown option '$1'"
      usage
      ;;
  esac
done

# --- Validation ---

if [ -z "$WORKSPACE" ]; then
  echo "Error: --workspace is required."
  usage
fi

WORKSPACE="$(cd "$WORKSPACE" && pwd)"

if [ ! -d "$WORKSPACE/.devcontainer" ] && [ ! -f "$WORKSPACE/.devcontainer.json" ]; then
  echo "Error: No .devcontainer/ directory or .devcontainer.json found in '$WORKSPACE'."
  exit 1
fi

# --- Build and start the dev container ---

echo "Building and starting dev container for workspace: $WORKSPACE"

DEVCONTAINER_ARGS=(
  up
  --workspace-folder "$WORKSPACE"
  --id-label "devcontainer.local_folder=$WORKSPACE"
)

if [ -n "$NAME" ]; then
  DEVCONTAINER_ARGS+=(--id-label "devcontainer.name=$NAME")
  echo "Container name label: $NAME"
fi

OUTPUT=$(devcontainer "${DEVCONTAINER_ARGS[@]}" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "Error: devcontainer up failed (exit code $EXIT_CODE):"
  echo "$OUTPUT"
  exit 1
fi

echo "Dev container started successfully."

# Parse the container ID from the JSON output
CONTAINER_ID=$(echo "$OUTPUT" | grep -o '"containerId":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$CONTAINER_ID" ]; then
  echo "Warning: Could not parse container ID from devcontainer output."
  echo "$OUTPUT"
  echo "unknown"
else
  echo "Container ID: $CONTAINER_ID"
  echo "$CONTAINER_ID"
fi

exit 0
