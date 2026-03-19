---
name: worktree
description: "Execute work in an isolated git worktree with a subagent. Creates a branch, sets up a worktree, spawns a subagent to do the work, creates a PR, and cleans up. Triggers on: worktree, run in worktree, isolated branch, work in worktree, branch and worktree."
user-invokable: true
---

# Worktree Skill

Execute work in an isolated git worktree. This skill manages the full lifecycle: branch creation → worktree setup → subagent execution → PR creation → cleanup.

A subagent runs inside the worktree to do the actual work. The parent session (you) manages the infrastructure around it.

---

## Inputs

When this skill is invoked, gather the following from the user or calling agent:

| Input | Required | Default | Description |
|---|---|---|---|
| **Prompt** | No | — | Inline instructions for the subagent. Free-form text describing the work to do. |
| **Plan file** | No | — | Path to a file in the repo that describes the work (e.g., a PRD, a plan, a design doc). The subagent reads it and executes it. |
| **Agent type** | No | `general-purpose` | Which subagent type to spawn via the `task` tool (e.g., `general-purpose`, `ralph-agent`, `explore`). |
| **Branch name** | No | Auto-generated | Git branch name (e.g., `feat/my-feature`). If not provided, derive a kebab-case name from the prompt or plan file. |
| **Base ref** | No | `HEAD` | Branch, tag, or commit to base the new branch from. |
| **Existing branch** | No | `false` | If `true`, the branch already exists (e.g., prepared by an orchestrator). Skip branch creation; fetch and use it directly. |
| **Port offset** | No | — | Integer for parallel port isolation (API = 3001 + N, Web = 3000 + N). |
| **Auto-merge** | No | `true` | Whether to enable auto-merge on the created PR. |
| **Create PR** | No | `true` | Whether to create a PR at the end. Set to `false` if the subagent handles PR creation itself. |

At least one of **Prompt** or **Plan file** must be provided. They can also be used together — the plan file provides the specification and the prompt provides additional context or instructions.

---

## Execution Flow

### Step 1: Resolve Inputs

```
BRANCH_NAME="<branch-name>"
REPO_ROOT="$(pwd)"
PROJECT_NAME="$(basename "$REPO_ROOT")"
```

Set the base ref for the new branch:
```bash
BASE_REF="<base-ref>"  # e.g., HEAD, origin/main, a commit SHA
```

### Step 2: Setup Branch and Worktree

Run the setup script to create the branch and worktree. The script handles everything without modifying the current HEAD.

**On Linux/macOS (bash):**
```bash
SCRIPT_DIR=".github/skills/worktree/scripts"

WORKTREE_DIR=$("$SCRIPT_DIR/setup-worktree.sh" \
  --branch "$BRANCH_NAME" \
  --base-ref "$BASE_REF" \
  # Include --existing-branch if using an existing branch
  # Include --plan-file and --plan-status if the plan file status needs updating
)
```

**On Windows (PowerShell):**
```powershell
$ScriptDir = ".github\skills\worktree\scripts"

$WorktreeDir = & "$ScriptDir\setup-worktree.ps1" `
  -Branch $BranchName `
  -BaseRef $BaseRef
  # Include -ExistingBranch if using an existing branch
  # Include -PlanFile and -PlanStatus if the plan file status needs updating
```

The script outputs the worktree directory path as its last line. Capture it for use in subsequent steps.

If the plan file has a YAML frontmatter `status:` field that should be updated (e.g., from `todo` to `inprogress`), pass `--plan-file` and `--plan-status`:

```bash
WORKTREE_DIR=$("$SCRIPT_DIR/setup-worktree.sh" \
  --branch "$BRANCH_NAME" \
  --base-ref "$BASE_REF" \
  --plan-file "$PLAN_FILE" \
  --plan-status "inprogress")
```

### Step 3: Build Subagent Prompt

Construct the prompt for the subagent. The prompt structure depends on whether a plan file, inline prompt, or both are provided.

**Base context** (always included):

```
You are working in an isolated git worktree at: <WORKTREE_DIR>

IMPORTANT: cd into <WORKTREE_DIR> before doing any work. All file paths are relative to this directory.
```

**Port configuration** (if port offset provided):
```
Use these ports for any dev servers:
- API port: <3001 + PORT_OFFSET>
- Web port: <3000 + PORT_OFFSET>
- NEXT_PUBLIC_API_URL: http://localhost:<API port>
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
- When everything is complete, output: <promise>WORKTREE-COMPLETE</promise>
```

**PR instructions** (if `create_pr` is true):
```
- Create a PR: gh pr create --base main --title "<title>" --body "<body>"
- Enable auto-merge: gh pr merge --auto --squash --delete-branch
```

### Step 4: Launch Subagent

Use the `task` tool to spawn a background subagent:

```
task(
  agent_type: "<agent-type>",  # e.g., "general-purpose"
  mode: "background",
  name: "worktree-<branch-suffix>",
  description: "Worktree: <branch-suffix>",
  prompt: "<constructed prompt from Step 3>"
)
```

Record the returned `agent_id`.

### Step 5: Monitor Subagent

Wait for the subagent to complete:

```
read_agent(agent_id: "<agent_id>", wait: true, timeout: 300)
```

If the agent is still running after the timeout, keep checking periodically. The subagent may run for a while depending on the complexity of the work.

Look for `<promise>WORKTREE-COMPLETE</promise>` in the output to confirm success.

### Step 6: Create PR (if not handled by subagent)

If `create_pr` is true and the subagent did NOT create a PR itself:

```bash
cd "$WORKTREE_DIR"
gh pr create --base main --title "<descriptive title>" --body "<summary of changes>"
gh pr merge --auto --squash --delete-branch
cd "$REPO_ROOT"
```

### Step 7: Cleanup

**Always run cleanup**, regardless of whether the subagent succeeded or failed.

**On Linux/macOS (bash):**
```bash
"$SCRIPT_DIR/cleanup-worktree.sh" --worktree-dir "$WORKTREE_DIR"
```

**On Windows (PowerShell):**
```powershell
& "$ScriptDir\cleanup-worktree.ps1" -WorktreeDir $WorktreeDir
```

The cleanup script is best-effort — it always exits 0 even if removal partially fails.

### Step 8: Report Result

- **On success**: Output `<promise>WORKTREE-COMPLETE</promise>`
- **On failure**: Report what went wrong (subagent error, worktree creation failure, etc.)

---

## Scripts

| File | Purpose |
|---|---|
| `scripts/setup-worktree.sh` | Bash script: creates branch (without changing HEAD), creates worktree, optionally updates plan file status |
| `scripts/setup-worktree.ps1` | PowerShell equivalent of setup-worktree.sh |
| `scripts/cleanup-worktree.sh` | Bash script: removes worktree and cleans up (best-effort) |
| `scripts/cleanup-worktree.ps1` | PowerShell equivalent of cleanup-worktree.sh |

---

## Examples

### Example 1: User-Invoked — Fix a Bug (inline prompt)

User says: `/worktree Fix the login timeout bug in src/auth/session.ts`

You would:
1. Derive branch name: `fix/login-timeout-bug`
2. Create branch from HEAD
3. Create worktree at `../<project>-login-timeout-bug/`
4. Spawn a `general-purpose` subagent with the inline prompt
5. Monitor until complete
6. Clean up worktree

### Example 2: Plan File — PRD Processing

Mayor invokes with:
- Agent type: `ralph-agent`
- Plan file: `docs/prds/prd-2026-03-15-task-status.md`
- Branch: `ralph/task-status` (new)
- Port offset: 10
- Create PR: false (the subagent's workflow handles PR creation)

You would:
1. Create branch `ralph/task-status` from HEAD
2. Create worktree at `../<project>-task-status/`
3. Spawn a `ralph-agent` subagent — its prompt says "your plan is at `docs/prds/prd-2026-03-15-task-status.md`, read and execute it"
4. The ralph-agent reads the PRD and runs the full workflow
5. Monitor until complete
6. Clean up worktree

### Example 3: Both Plan File and Prompt

User invokes with:
- Plan file: `docs/plans/refactor-auth.md`
- Prompt: "Focus on the OAuth section first. Skip the SAML parts for now."

The subagent gets the full plan from the file plus the scoping instructions from the prompt.

### Example 4: Parallel Execution

Multiple worktree skills running in parallel (launched by an orchestrator):

| Instance | Branch | Worktree | Port Offset | Agent Type |
|---|---|---|---|---|
| 1 | `ralph/feature-a` | `../myapp-feature-a/` | 10 | `ralph-agent` |
| 2 | `ralph/feature-b` | `../myapp-feature-b/` | 20 | `ralph-agent` |
| 3 | `feat/bugfix-c` | `../myapp-bugfix-c/` | 30 | `general-purpose` |

Each instance has isolated ports and an isolated worktree directory.

---

## Important Rules

- **Always clean up worktrees**, even on failure. Stale worktrees waste disk space and cause git issues.
- **Never modify the main repository's working directory.** Use git plumbing for branch creation. The worktree is a sibling directory.
- **Port offsets prevent collisions** when running multiple worktree skills in parallel.
- **The subagent does the work.** Your job is infrastructure: branch, worktree, launch, monitor, cleanup.
- **Worktree path convention**: `../<project-name>-<branch-suffix>/` (sibling to the repo root).
