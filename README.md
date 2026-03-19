# RaV Town — Read-and-Vibe Town

![RaV Town Banner](rav-town-banner.png)

A multi-agent orchestration system that autonomously implements features from Product Requirements Documents (PRDs). It coordinates parallel AI agents, each working in isolated git worktrees, to go from specification to merged pull request without human intervention.

## Quick Start

### 1. Create a PRD

Use the `/prd` skill to generate a PRD:

```
/prd Add a task priority system with high/medium/low levels
```

This creates `docs/prds/prd-<date>-<feature>.md` with `status: todo` in the YAML frontmatter. You can create one or many.

### 2. Run Ravtown Mayor

Launch the orchestrator agent:

```bash
copilot --agent ravtown-mayor
```

Submit PRDs incrementally — one at a time or in batches:

```
Complete docs/prds/prd-2026-03-15-task-priority.md
```

Or submit everything at once:

```
Complete all todo PRDs
```

You can keep sending new PRDs to the same session:

```
Complete docs/prds/prd-2026-03-19-user-profiles.md
```

The mayor tracks state in a local JSONL file (`docs/prds/.ravtown-state.jsonl`) so it can resume if restarted. Ask for status at any time:

```
Status
```

The mayor tracks state, invokes `/worktree` for each PRD, and monitors progress. Submit more PRDs at any time.

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                      Ravtown Mayor                               │
│  Accepts PRDs incrementally → tracks state in JSONL              │
│  → invokes /worktree per PRD → monitors progress                 │
└────────┬────────────────────────────────────────────────────────┘
         │
         ├─ /worktree #1 (port offset 10)
         │  ├─ creates branch ralph/<feature> from HEAD
         │  ├─ creates worktree
         │  ├─ spawns ralph-agent subagent
         │  │   ├─ reads PRD (plan file)
         │  │   ├─ /ralph-prd → converts PRD to JSON
         │  │   ├─ /ralph-loop → iterates through stories
         │  │   └─ creates PR → merges → archives PRD
         │  └─ cleans up worktree
         │
         ├─ /worktree #2 (port offset 20)
         │  └─ same flow for another independent feature
         │
         └─ /worktree #3 (port offset 30)  [blocked]
            └─ waits for #1 to finish (dependency)
```

### The Loop

Each ralph-agent subagent runs a **loop** (`ralph.sh` via the `/ralph-loop` skill) that spawns a fresh AI coding session per iteration:

1. **Read PRD** — pick the highest-priority story where `passes: false`
2. **Implement** — make the code changes for that one story
3. **Quality check** — run typecheck, lint, tests
4. **Commit** — `feat: [US-001] - Story Title`
5. **Update PRD** — mark story as `passes: true`
6. **Log learnings** — append to progress file for future iterations
7. **Repeat** until all stories pass, then archive PRD, create & merge PR

## Components

### Agents (`/.github/agents/`)

| Agent | Role |
|---|---|
| [**ravtown-mayor**](.github/agents/ravtown-mayor.md) | Fleet manager. Accepts PRDs incrementally, tracks state in JSONL, invokes `/worktree` per PRD with `ralph-agent` as the subagent. Resumable across sessions. |
| [**ralph-agent**](.github/agents/ralph-agent.md) | PRD processor. Runs as a subagent inside a worktree — reads the PRD (plan file), converts it with `/ralph-prd`, implements stories with `/ralph-loop`, archives and creates PR. |

### Skills (`/.github/skills/`)

Reusable capabilities that agents (or humans) can invoke:

| Skill | Purpose |
|---|---|
| [**worktree**](.github/skills/worktree/SKILL.md) | Executes work in an isolated git worktree. Creates a branch, sets up a worktree, spawns a configurable subagent to do the work, and cleans up. Used by agents for parallel isolation or by humans for any branch-isolated task. |
| [**prd**](.github/skills/prd/SKILL.md) | Generates a Product Requirements Document from a feature description. Asks clarifying questions, outputs structured markdown to `docs/prds/` with `status: todo` in YAML frontmatter. |
| [**ralph-prd**](.github/skills/ralph-prd/SKILL.md) | Converts a markdown PRD into Ralph's `prd-<date>-<feature>.json` format. Ensures stories are right-sized (one iteration each), properly ordered, and have verifiable acceptance criteria. |
| [**ralph-loop**](.github/skills/ralph-loop/SKILL.md) | Runs the Ralph execution loop (`ralph.sh`). Iterates through PRD user stories, spawning a fresh AI session per iteration to implement, test, and commit each story. |
| [**dev-browser**](.github/skills/dev-browser/SKILL.md) | Browser automation via Playwright. Agents use this to visually verify UI changes — navigate pages, click elements, take screenshots. |

### Scripts (inside `/ralph-loop` skill)

| File | Purpose |
|---|---|
| [**ralph.sh**](.github/skills/ralph-loop/scripts/ralph.sh) | The core execution loop. Invokes an AI tool (Copilot, Claude, or AMP) repeatedly, injecting the PRD context each iteration. Handles port isolation and completion detection. |
| [**CLAUDE.md**](.github/skills/ralph-loop/scripts/CLAUDE.md) | The prompt template injected into each iteration. Tells the AI agent how to read the PRD, implement a story, run checks, commit, and log progress. |

### Prompts (`/.github/prompts/`)

| Prompt | Purpose |
|---|---|
| [**create-and-merge-pr**](.github/prompts/create-and-merge-pr.prompt.md) | Reference guide for creating a PR, waiting for CI, and squash-merging to main. The Ralph loop's final iteration follows this pattern (see `CLAUDE.md` Stop Condition). |

### Root Symlinks

| File | Target |
|---|---|
| `AGENTS.md` | → `.github/copilot-instructions.md` |
| `CLAUDE.md` | → `.github/copilot-instructions.md` |

These symlinks ensure that tools like GitHub Copilot, Claude Code, and other AI agents discover the project instructions regardless of which filename convention they look for.

## PRD Lifecycle

PRDs flow through three stages, tracked by a YAML frontmatter `status` field:

```
docs/prds/
├── prd-2026-03-15-feature-a.md   ← status: todo
├── prd-2026-03-16-feature-b.md   ← status: inprogress
├── prd-2026-03-17-feature-c.md   ← status: complete
└── ...
```

The `status` field in each PRD's frontmatter is one of: `todo`, `inprogress`, `complete`.

### Naming Convention

All PRD-related files use the pattern `<YYYY-MM-DD>-<feature-name>`:

| File Type | Pattern | Example |
|---|---|---|
| PRD markdown | `prd-<date>-<feature>.md` | `prd-2026-03-15-task-status.md` |
| PRD JSON | `prd-<date>-<feature>.json` | `prd-2026-03-15-task-status.json` |
| Progress file | `progress-<date>-<feature>.txt` | `progress-2026-03-15-task-status.txt` |
| Git branch | `ralph/<feature>` (no date) | `ralph/task-status` |

The date is set when the `/prd` skill first creates the PRD and carries through the entire lifecycle.

## Workflow: Feature → Merged PR

```
1. User describes a feature
        │
        ▼
2. /prd skill generates docs/prds/prd-2026-03-15-feature.md (status: todo)
        │
        ▼
3. User tells Ravtown Mayor: "Complete this PRD"
   (or "Complete all todo PRDs")
        │
        ▼
4. Mayor submits PRD → appends to JSONL state → invokes /worktree:
   ┌─────────────────────────────────────────┐
   │  agent_type: ralph-agent                 │
   │  plan_file: docs/prds/prd-xxx.md        │
   │  branch: ralph/<feature> (new)           │
   │  port_offset: 10                         │
   └─────────────────────────────────────────┘
        │
        ▼
5. /worktree skill sets up:
   ┌─────────────────────────────────────────┐
   │  Create branch from HEAD                 │
   │  Create worktree                         │
   │  Spawn ralph-agent subagent              │
   └─────────────────────────────────────────┘
        │
        ▼
6. Ralph-agent works inside the worktree:
   ┌─────────────────────────────────────────┐
   │  Read PRD (plan file)                    │
   │  Update PRD status: todo → inprogress    │
   │  /ralph-prd → creates JSON               │
   │  /ralph-loop:                            │
   │    Iteration 1: US-001 (schema)          │
   │    Iteration 2: US-002 (backend)         │
   │    Iteration 3: US-003 (UI)              │
   │    Iteration 4: US-004 (filters)         │
   │    Iteration 5: All pass → archive PRD   │
   │                 → create & merge PR      │
   └─────────────────────────────────────────┘
        │
        ▼
7. /worktree skill cleans up worktree
        │
        ▼
8. PR auto-merges to main (includes archived PRD)
        │
        ▼
9. Mayor updates JSONL state → user can submit more PRDs
```

## Port Isolation

When multiple agents run in parallel, each gets a unique port offset to prevent collisions:

| Instance | Offset | API Port | Web Port |
|---|---|---|---|
| Worktree 1 | 10 | 3011 | 3010 |
| Worktree 2 | 20 | 3021 | 3020 |
| Worktree 3 | 30 | 3031 | 3030 |

## PRD Format

Ralph PRDs are JSON files with this structure:

```json
{
  "project": "MyProject",
  "branchName": "ralph/feature-name",
  "description": "Feature description",
  "dependsOn": [],
  "userStories": [
    {
      "id": "US-001",
      "title": "Story title",
      "description": "As a user, I want X so that Y",
      "acceptanceCriteria": ["Criterion 1", "Typecheck passes"],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

Key rules:
- Each story must be completable in **one iteration** (one AI context window)
- Stories are ordered by dependency (schema → backend → UI)
- Every story needs `"Typecheck passes"` as a criterion
- UI stories need `"Verify in browser using dev-browser skill"`

## Manual / Single Feature

You can also use the `/worktree` skill directly to process a single PRD:

```
/worktree
  agent_type: ralph-agent
  plan_file: docs/prds/prd-2026-03-15-feature.md
  branch: ralph/feature
```

Or run the ralph loop directly (requires the PRD to already be converted to JSON with `status: inprogress`):

```bash
.github/skills/ralph-loop/scripts/ralph.sh \
  --prd docs/prds/prd-2026-03-15-feature.json \
  --tool copilot \
  10
```

## Adopting RaV Town in Your Project

1. **Copy this repo's structure** into your project:
   ```
   .github/agents/
   .github/skills/
   .github/prompts/
   docs/prds/
   AGENTS.md → .github/copilot-instructions.md
   CLAUDE.md → .github/copilot-instructions.md
   ```

2. **Fill in `.github/copilot-instructions.md`** with your project's tech stack, commands, and architecture

3. **Create PRDs** using the `/prd` skill

4. **Run** `copilot --agent ravtown-mayor` and prompt: "Complete all todo PRDs"

## Supported AI Tools

Ralph supports three AI backends via `--tool`:

| Tool | Command | Flag |
|---|---|---|
| **GitHub Copilot CLI** | `copilot` | `--tool copilot` (default) |
| **Claude Code** | `claude` | `--tool claude` |
| **AMP** | `amp` | `--tool amp` |

## License

MIT
