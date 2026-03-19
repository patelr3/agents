# rav-town

Multi-agent orchestration system for autonomous feature development from PRDs.

## What's Included

### Skills

| Skill | Trigger | Description |
|---|---|---|
| **prd** | `/prd`, "create a prd", "plan this feature" | Generate structured PRDs from feature descriptions |
| **ralph-prd** | `/ralph-prd`, "convert this prd", "ralph json" | Convert markdown PRDs to Ralph's JSON execution format |
| **ralph-loop** | `/ralph-loop`, "run ralph loop", "start ralph" | Iterative story-by-story implementation loop |
| **worktree** | `/worktree`, "run in worktree" | Isolated git worktree lifecycle — branch, worktree, subagent, PR, cleanup |

### Agents

| Agent | Description |
|---|---|
| **ravtown-mayor** | Fleet manager. Accepts PRDs, tracks state in JSONL, delegates to ralph-agent subagents via `/worktree`. Manages dependencies and parallel execution. |
| **ralph-agent** | Autonomous PRD processor. Reads a PRD, converts to JSON, runs the ralph-loop, signals completion. Runs inside a worktree. |

## Usage

### Generate a PRD

```
/prd Add user authentication with email/password login
```

### Process a Single PRD

Use the worktree skill directly:

```
/worktree
  agent_type: ralph-agent
  plan_file: docs/prds/prd-2026-03-15-auth.md
  branch: ralph/auth
```

### Orchestrate Multiple PRDs

Start the ravtown-mayor agent, then:

```
Complete all todo PRDs
```

The mayor will:
1. Find all PRDs with `status: todo`
2. Check dependencies between PRDs
3. Launch parallel worktrees for independent PRDs
4. Monitor progress and report status

### Run the Loop Directly

```bash
${CLAUDE_PLUGIN_ROOT}/skills/ralph-loop/scripts/ralph.sh \
  --prd docs/prds/prd-2026-03-15-feature.json \
  --tool copilot \
  --port-offset 10 \
  12
```

## PRD Lifecycle

PRDs flow: `todo` → `inprogress` → `complete` (tracked via YAML frontmatter `status` field).

| File | Pattern |
|---|---|
| PRD markdown | `docs/prds/prd-<date>-<feature>.md` |
| PRD JSON | `docs/prds/prd-<date>-<feature>.json` |
| Progress log | `docs/prds/progress-<date>-<feature>.txt` |
| Git branch | `ralph/<feature>` |

## Port Isolation

Parallel agents get unique port offsets to prevent collisions:

| Variable | Formula |
|---|---|
| `PORT` (API) | `3001 + offset` |
| `WEB_PORT` | `3000 + offset` |
| `NEXT_PUBLIC_API_URL` | `http://localhost:<PORT>` |

## Supported AI Backends

The ralph-loop script supports `--tool copilot` (default), `--tool claude`, and `--tool amp`.

## License

MIT
