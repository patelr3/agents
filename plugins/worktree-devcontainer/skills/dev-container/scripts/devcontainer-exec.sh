#!/bin/bash
# Execute an AI tool inside a running dev container
#
# Usage:
#   ./devcontainer-exec.sh --workspace <path> --tool <copilot|claude|amp> --prompt <text>
#
# Runs the specified AI tool command inside the dev container associated with
# the given workspace folder. Passes through the exit code from the tool.

set -e

WORKSPACE=""
TOOL=""
PROMPT=""

usage() {
  echo "Usage: $(basename "$0") --workspace <path> --tool <tool> --prompt <text>"
  echo ""
  echo "Options:"
  echo "  --workspace <path>            Path to the workspace folder (required)"
  echo "  --tool <copilot|claude|amp>   AI tool to run inside the container (required)"
  echo "  --prompt <text>               Prompt text for the AI tool (required)"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0") --workspace /path/to/repo --tool copilot --prompt 'Fix the login bug'"
  echo "  $(basename "$0") --workspace /path/to/repo --tool claude --prompt 'Implement feature X'"
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
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --prompt)
      PROMPT="$2"
      shift 2
      ;;
    --prompt=*)
      PROMPT="${1#*=}"
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

if [ -z "$TOOL" ]; then
  echo "Error: --tool is required."
  usage
fi

if [ -z "$PROMPT" ]; then
  echo "Error: --prompt is required."
  usage
fi

WORKSPACE="$(cd "$WORKSPACE" && pwd)"

case "$TOOL" in
  copilot|claude|amp)
    ;;
  *)
    echo "Error: --tool must be one of: copilot, claude, amp (got '$TOOL')."
    exit 1
    ;;
esac

# --- Build the tool command ---

# Source .bashrc for environment variables (e.g., GITHUB_TOKEN) before running the tool
BASHRC_INIT="[ -f ~/.bashrc ] && . ~/.bashrc;"

case "$TOOL" in
  copilot)
    TOOL_CMD="${BASHRC_INIT} copilot -p \"$PROMPT\" --allow-all"
    ;;
  claude)
    TOOL_CMD="${BASHRC_INIT} claude -p \"$PROMPT\" --allowedTools \"edit,write,bash,computer,mcp\" --dangerouslySkipPermissions"
    ;;
  amp)
    TOOL_CMD="${BASHRC_INIT} amp -p \"$PROMPT\""
    ;;
esac

echo "Executing $TOOL inside dev container for workspace: $WORKSPACE"
echo "---"

# --- Run the command inside the dev container ---

devcontainer exec \
  --workspace-folder "$WORKSPACE" \
  sh -c "$TOOL_CMD"

EXIT_CODE=$?

echo "---"
echo "Tool '$TOOL' exited with code: $EXIT_CODE"

exit $EXIT_CODE
