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

## Prerequisites

- **Worktree skill**: `git` (standard)
- **Dev container skill**: `@devcontainers/cli` (`npm install -g @devcontainers/cli`), Docker or compatible container runtime
