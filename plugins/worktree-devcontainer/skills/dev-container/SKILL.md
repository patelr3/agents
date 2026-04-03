---
name: dev-container
description: "Run work inside a dev container. Builds a dev container from a workspace's .devcontainer/ config, executes an AI tool (Copilot, Claude, or AMP) inside the container, and cleans up. Triggers on: dev container, run in container, devcontainer, containerized work."
user-invokable: true
---

# Dev Container Skill

Run work inside a dev container. This skill manages the full lifecycle: container build → AI tool execution → cleanup.

A sub-agent (Copilot, Claude, or AMP) runs inside the dev container to do the actual work. The parent session (you) manages the container lifecycle around it.

---

## Inputs

When this skill is invoked, gather the following from the user or calling agent:

| Input | Required | Default | Description |
|---|---|---|---|
| **Workspace folder** | Yes | — | Path to the repo/worktree directory containing `.devcontainer/` config |
| **Prompt** | No | — | Inline instructions for the sub-agent. Free-form text describing the work to do. |
| **Plan file** | No | — | Path to a file in the repo that describes the work (e.g., a PRD, a plan, a design doc). The sub-agent reads it and executes it. |
| **Tool** | No | `copilot` | AI backend to run inside the container: `copilot`, `claude`, or `amp`. |
| **Container name** | No | Auto-derived from workspace | Name for the dev container instance. |
| **Port offset** | No | — | Integer for parallel port isolation (API = 3001 + N, Web = 3000 + N). |
| **Auto-merge** | No | `true` | Whether to enable auto-merge on the created PR. |
| **Create PR** | No | `true` | Whether to create a PR at the end. Set to `false` if the sub-agent handles PR creation itself. |

At least one of **Prompt** or **Plan file** must be provided. They can also be used together — the plan file provides the specification and the prompt provides additional context or instructions.

---

## Execution Flow

### Step 1: Resolve Inputs

Validate the workspace folder exists and contains a `.devcontainer/` directory:

```
WORKSPACE_FOLDER="<workspace-folder>"
PROJECT_NAME="$(basename "$WORKSPACE_FOLDER")"
TOOL="<tool>"  # copilot, claude, or amp — default: copilot
```

Auto-derive container name if not provided:

```bash
BRANCH_SUFFIX=$(cd "$WORKSPACE_FOLDER" && git rev-parse --abbrev-ref HEAD | sed 's|.*/||')
CONTAINER_NAME="${PROJECT_NAME}-${BRANCH_SUFFIX}"
```

Validate inputs:
- `WORKSPACE_FOLDER` must exist and contain a `.devcontainer/` directory (or `.devcontainer.json` at root)
- At least one of prompt or plan file must be provided
- Tool must be one of: `copilot`, `claude`, `amp`

### Step 2: Build and Start Dev Container

Run the setup script to build and start the dev container.

**On Linux/macOS (bash):**
```bash
SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/skills/dev-container/scripts"

CONTAINER_ID=$("$SCRIPT_DIR/devcontainer-up.sh" \
  --workspace "$WORKSPACE_FOLDER" \
  --name "$CONTAINER_NAME")
```

**On Windows (PowerShell):**
```powershell
$ScriptDir = "${CLAUDE_PLUGIN_ROOT}\skills\dev-container\scripts"

$ContainerId = & "$ScriptDir\devcontainer-up.ps1" `
  -Workspace $WorkspaceFolder `
  -Name $ContainerName
```

The script outputs the container ID as its last line. Capture it for diagnostics.

### Step 3: Build Sub-agent Prompt

Construct the prompt for the AI tool running inside the container. The prompt structure depends on whether a plan file, inline prompt, or both are provided.

**Base context** (always included):

```
You are working inside a dev container.
The workspace is mounted at /workspaces/<PROJECT_NAME>.
All file paths are relative to this directory.
```

**Port configuration** (if port offset provided):

```
Use these ports for any dev servers:
- API port: <3001 + PORT_OFFSET>
- Web port: <3000 + PORT_OFFSET>
```

**Plan file** (if provided):

```
## Your Plan

Your plan is in the file: <plan_file>
Read it and execute all instructions in it.
```

**Inline prompt** (if provided):

```
## Your Task

<user's original prompt>
```

If both `plan_file` and `prompt` are provided, include both sections. The plan file is the primary specification; the prompt provides additional context.

**Closing instructions** (always included):

```
## When Done

- Commit all changes with conventional commit messages
- Push to origin: `git push`
<PR instructions if create_pr is true>
- When everything is complete, output: WORKTREE-COMPLETE
```

**PR instructions** (if `create_pr` is true):

```
- Create a PR: gh pr create --base main --title "<title>" --body "<body>"
- Enable auto-merge: gh pr merge --auto --squash --delete-branch
```

### Step 4: Execute AI Tool in Container

**On Linux/macOS (bash):**
```bash
"$SCRIPT_DIR/devcontainer-exec.sh" \
  --workspace "$WORKSPACE_FOLDER" \
  --tool "$TOOL" \
  --prompt "$CONSTRUCTED_PROMPT"
```

**On Windows (PowerShell):**
```powershell
& "$ScriptDir\devcontainer-exec.ps1" `
  -Workspace $WorkspaceFolder `
  -Tool $Tool `
  -Prompt $ConstructedPrompt
```

The exec script runs the appropriate AI tool command inside the container:

| Tool | Command |
|---|---|
| `copilot` | `copilot -p "<prompt>" --allow-all` |
| `claude` | `claude -p "<prompt>" --allowedTools "edit,write,bash,computer,mcp" --dangerouslySkipPermissions` |
| `amp` | `amp -p "<prompt>"` |

### Step 5: Monitor for Completion

Wait for the exec script to complete. Check:

1. Exit code of the exec script (non-zero means failure)
2. Output for `WORKTREE-COMPLETE` signal (confirms the sub-agent finished its work successfully)

### Step 6: Cleanup

**Always run cleanup**, regardless of whether the sub-agent succeeded or failed.

**On Linux/macOS (bash):**
```bash
"$SCRIPT_DIR/devcontainer-down.sh" --workspace "$WORKSPACE_FOLDER" --name "$CONTAINER_NAME"
```

**On Windows (PowerShell):**
```powershell
& "$ScriptDir\devcontainer-down.ps1" -Workspace $WorkspaceFolder -Name $ContainerName
```

The cleanup script is best-effort — it always exits 0 even if removal partially fails.

### Step 7: Report Result

- **On success**: Output `<promise>WORKTREE-COMPLETE</promise>`
- **On failure**: Report what went wrong (container build failure, sub-agent error, etc.)

---

## Scripts

| File | Purpose |
|---|---|
| `scripts/devcontainer-up.sh` | Build and start the dev container using `@devcontainers/cli` |
| `scripts/devcontainer-up.ps1` | PowerShell equivalent of devcontainer-up.sh |
| `scripts/devcontainer-exec.sh` | Execute an AI tool (copilot/claude/amp) inside the running container |
| `scripts/devcontainer-exec.ps1` | PowerShell equivalent of devcontainer-exec.sh |
| `scripts/devcontainer-down.sh` | Stop and remove the container (best-effort, always exits 0) |
| `scripts/devcontainer-down.ps1` | PowerShell equivalent of devcontainer-down.sh |

---

## Examples

### Example 1: User-Invoked — Fix a Bug in a Containerized Environment

User says: `Run in container: fix the flaky test in tests/integration/auth.test.ts`

You would:
1. Identify workspace folder (current repo root)
2. Validate `.devcontainer/` exists
3. Auto-derive container name: `myapp-main`
4. Build and start the dev container
5. Execute `copilot` (default tool) with the fix prompt inside the container
6. Monitor for completion
7. Clean up the container
8. Report result

### Example 2: Orchestrator-Invoked — Process a PRD Inside a Container

An orchestrator invokes with:
- Workspace folder: `../myapp-task-status/` (a worktree)
- Plan file: `docs/prds/prd-2026-03-15-task-status.md`
- Tool: `claude`
- Port offset: 10
- Create PR: false (the sub-agent handles PR creation)

You would:
1. Validate the worktree workspace has `.devcontainer/`
2. Build and start the dev container
3. Construct prompt with plan file reference and port config (API: 3011, Web: 3010)
4. Execute `claude` inside the container
5. Monitor for completion
6. Clean up the container

### Example 3: Composed with Worktree Skill

The worktree skill creates a branch and worktree, then the dev-container skill runs the work:

1. **Worktree skill** creates branch `feat/new-api` and worktree at `../myapp-new-api/`
2. **Dev-container skill** is invoked with:
   - Workspace folder: `../myapp-new-api/`
   - Prompt: "Implement the new REST API endpoints per the OpenAPI spec in docs/api.yaml"
   - Tool: `claude`
   - Container name: `myapp-new-api`
   - Port offset: 5
3. Dev container is built from the worktree's `.devcontainer/` config
4. Claude runs inside the container, implements the changes, commits, and pushes
5. Container is cleaned up
6. **Worktree skill** creates the PR and cleans up the worktree

---

## Important Rules

- **Always clean up containers**, even on failure. Stale containers waste resources and may hold ports.
- **The sub-agent does the work.** Your job is infrastructure: container build, launch, monitor, cleanup.
- **Port offsets prevent collisions** when running multiple dev-container skills in parallel.
- **The workspace must have a `.devcontainer/` directory** (or `.devcontainer.json` at root). Without it, `devcontainer up` will fail.
- **The AI tool must be available inside the container image.** Ensure `copilot`, `claude`, or `amp` is installed in the dev container's Dockerfile or features.
- **Never modify the workspace directly.** All work happens inside the container through the mounted workspace.
