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
| 1. Create branch & worktree | worktree | `setup-worktree.sh --branch feat/license-worktree-devcontainer --base-ref HEAD` | ✅ Branch created via `git update-ref` (no HEAD change), pushed to origin, worktree at `../agents-license-worktree-devcontainer/` |
| 2. Build dev container | dev-container | `devcontainer up` with `--mount` for main repo `.git` | ✅ Container built from `.devcontainer/devcontainer.json`, copilot + claude installed via `postCreateCommand` |
| 3. Execute AI tool | dev-container | `devcontainer-exec.sh --workspace <worktree> --tool copilot --prompt "..."` | ✅ Copilot ran inside the container with `--allow-all`, copied LICENSE, committed, and pushed. Output: `WORKTREE-COMPLETE` |
| 4. Cleanup container | dev-container | `devcontainer-down.sh --workspace <worktree> --name agents-license-test` | ✅ Container found by label and force-removed |
| 5. Cleanup worktree | worktree | `cleanup-worktree.sh --worktree-dir <worktree>` | ✅ Worktree removed, `git worktree prune` ran |

**Key findings from testing:**

1. **AI tools must be in the image.** The `postCreateCommand` installs `@github/copilot` (npm) and Claude Code (native installer) so they are available for `devcontainer-exec`.
2. **Worktree `.git` references break in containers.** A worktree's `.git` file contains an absolute path to the main repo's `.git/worktrees/` directory. When mounted in a container, that path doesn't exist. **Fix:** Pass `--mount type=bind,source=<repo>/.git,target=<repo>/.git` when running `devcontainer up`.
3. **Auth forwarding is required.** Mount `~/.git-credentials` into the container and export `GITHUB_TOKEN` from it in the `postCreateCommand` so both `git push` and `copilot`/`claude` can authenticate.
4. **Non-interactive tools need permission flags.** Copilot requires `--allow-all` and Claude requires `--dangerouslySkipPermissions` for unattended execution.

## Prerequisites

- **Worktree skill**: `git` (standard)
- **Dev container skill**: `@devcontainers/cli` (`npm install -g @devcontainers/cli`), Docker or compatible container runtime
- **AI tool in container**: The container image must have the target AI tool (`copilot`, `claude`, or `amp`) installed for `devcontainer-exec` to work

## License

MIT — see [LICENSE](LICENSE)
