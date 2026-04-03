# worktree-devcontainer

Isolated development environments for AI sub-agents. Two skills for setting up isolated workspaces:

| Skill | Description |
|---|---|
| **worktree** | Git worktree lifecycle — create branch, setup worktree, spawn sub-agent, create PR, cleanup |
| **dev-container** | Dev container lifecycle — build container from worktree, run AI tool inside, cleanup |

## Installation

```
/plugin install worktree-devcontainer@rav-town-marketplace
```

## Usage

### Worktree (branch isolation)

```
/worktree Fix the login timeout bug in src/auth/session.ts
```

Creates an isolated git worktree, spawns a sub-agent to do the work, creates a PR, and cleans up.

### Dev Container (container isolation)

```
/dev-container --workspace ./my-worktree --prompt "Implement the auth feature"
```

Builds a dev container from the workspace's `.devcontainer/` config, runs the AI tool inside the container, and cleans up on completion.

## Composing Skills

The typical flow for fully isolated work:

1. **Worktree skill** creates a branch and worktree directory
2. **Dev container skill** builds a container from that worktree and runs the AI tool inside

This gives you both branch isolation (worktree) and environment isolation (container).

## Tested Workflow

The worktree + dev-container composition was validated end-to-end with the following test run:

**Scenario:** Add a LICENSE file to the worktree-devcontainer plugin via the full skill pipeline.

| Step | Skill | Script | Result |
|---|---|---|---|
| 1. Create branch & worktree | worktree | `setup-worktree.sh --branch feat/add-worktree-devcontainer-license --base-ref HEAD` | ✅ Branch created via `git update-ref` (no HEAD change), pushed to origin, worktree at `../agents-add-worktree-devcontainer-license/` |
| 2. Build dev container | dev-container | `devcontainer-up.sh --workspace <worktree> --name agents-worktree-license-test` | ✅ Container built from `.devcontainer/devcontainer.json`, started successfully |
| 3. Execute AI tool | dev-container | `devcontainer-exec.sh --workspace <worktree> --tool copilot --prompt "..."` | ⚠️ `copilot` not found in container (exit 127) — expected; AI tool must be pre-installed in the container image |
| 4. Manual fallback | — | Copied LICENSE, committed, pushed from worktree | ✅ Commit pushed to feature branch |
| 5. Cleanup container | dev-container | `devcontainer-down.sh --workspace <worktree> --name agents-worktree-license-test` | ✅ Container found by label and force-removed |
| 6. Cleanup worktree | worktree | `cleanup-worktree.sh --worktree-dir <worktree>` | ✅ Worktree removed, `git worktree prune` ran |

**Key finding:** The dev container base image (`mcr.microsoft.com/devcontainers/typescript-node:22`) does not include `copilot`, `claude`, or `amp`. To use the dev-container skill's exec step, the AI tool must be added to the Dockerfile or via a dev container feature.

## Prerequisites

- **Worktree skill**: `git` (standard)
- **Dev container skill**: `@devcontainers/cli` (`npm install -g @devcontainers/cli`), Docker or compatible container runtime
- **AI tool in container**: The container image must have the target AI tool (`copilot`, `claude`, or `amp`) installed for `devcontainer-exec` to work

## License

MIT — see [LICENSE](LICENSE)
