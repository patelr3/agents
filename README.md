# Ralph — Autonomous Agent System for Feature Development

Ralph is a multi-agent orchestration system that autonomously implements features from Product Requirements Documents (PRDs). It coordinates parallel AI agents, each working in isolated git worktrees, to go from specification to merged pull request without human intervention.

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                     Ralph Orchestrator                           │
│  Scans PRDs → builds dependency graph → launches agent waves    │
└────────┬────────────────────────────────────────────────────────┘
         │
         ├─ Ralph Agent #1 (port offset 10)
         │  ├─ reads prd-feature-a.json
         │  ├─ runs ralph.sh → iterates through stories
         │  └─ creates PR → merges → signals PRD-COMPLETE
         │
         ├─ Ralph Agent #2 (port offset 20)
         │  └─ same flow for another independent feature
         │
         └─ Ralph Agent #3 (port offset 30)  [blocked]
            └─ waits for Agent #1 to finish (dependency)
```

### The Loop

Each Ralph agent runs a **loop** (`ralph.sh`) that spawns a fresh AI coding session per iteration:

1. **Read PRD** — pick the highest-priority story where `passes: false`
2. **Implement** — make the code changes for that one story
3. **Quality check** — run typecheck, lint, tests
4. **Commit** — `feat: [US-001] - Story Title`
5. **Update PRD** — mark story as `passes: true`
6. **Log learnings** — append to progress file for future iterations
7. **Repeat** until all stories pass, then create & merge PR

## Components

### Agents (`/.github/agents/`)

| Agent | Role |
|---|---|
| [**ralph-agent**](.github/agents/ralph-agent.md) | Executes a single PRD end-to-end. Sets up a git worktree, runs `ralph.sh`, monitors completion. |
| [**ralph-orchestrator**](.github/agents/ralph-orchestrator.md) | Fleet manager. Scans for PRD files, builds a dependency DAG, launches agents in parallel waves, cleans up on completion. |

### Skills (`/.github/skills/`)

Reusable capabilities that agents (or humans) can invoke:

| Skill | Purpose |
|---|---|
| [**prd**](.github/skills/prd/SKILL.md) | Generates a Product Requirements Document from a feature description. Asks clarifying questions, outputs structured markdown to `docs/prds/`. |
| [**ralph**](.github/skills/ralph/SKILL.md) | Converts a markdown PRD into Ralph's `prd-<suffix>.json` format. Ensures stories are right-sized (one iteration each), properly ordered, and have verifiable acceptance criteria. |
| [**dev-browser**](.github/skills/dev-browser/SKILL.md) | Browser automation via Playwright. Agents use this to visually verify UI changes — navigate pages, click elements, take screenshots. |

### Scripts (`/scripts/ralph/`)

| File | Purpose |
|---|---|
| [**ralph.sh**](scripts/ralph/ralph.sh) | The core execution loop. Invokes an AI tool (Copilot, Claude, or AMP) repeatedly, injecting the PRD context each iteration. Handles worktree setup, port isolation, and completion detection. |
| [**CLAUDE.md**](scripts/ralph/CLAUDE.md) | The prompt template injected into each iteration. Tells the AI agent how to read the PRD, implement a story, run checks, commit, and log progress. |

### Prompts (`/.github/prompts/`)

| Prompt | Purpose |
|---|---|
| [**create-and-merge-pr**](.github/prompts/create-and-merge-pr.prompt.md) | Step-by-step guide for creating a PR, waiting for CI, and squash-merging to main. Used by agents at the end of a PRD. |

### Root Symlinks

| File | Target |
|---|---|
| `AGENTS.md` | → `.github/copilot-instructions.md` |
| `CLAUDE.md` | → `.github/copilot-instructions.md` |

These symlinks ensure that tools like GitHub Copilot, Claude Code, and other AI agents discover the project instructions regardless of which filename convention they look for.

## Workflow: Feature → Merged PR

```
1. User describes a feature
        │
        ▼
2. PRD Skill generates docs/prds/prd-feature.md
        │
        ▼
3. Ralph Skill converts to scripts/ralph/prd-feature.json
        │
        ▼
4. Orchestrator discovers prd-feature.json
        │
        ▼
5. Orchestrator launches Ralph Agent in background
        │
        ▼
6. ralph.sh iterates:
   ┌─────────────────────────────────────┐
   │  Iteration 1: US-001 (schema)       │
   │  Iteration 2: US-002 (backend)      │
   │  Iteration 3: US-003 (UI)           │
   │  Iteration 4: US-004 (filters)      │
   │  Iteration 5: All pass → create PR  │
   └─────────────────────────────────────┘
        │
        ▼
7. PR auto-merges to main
        │
        ▼
8. Orchestrator archives PRD, cleans up worktree
```

## Port Isolation

When multiple agents run in parallel, each gets a unique port offset to prevent collisions:

| Agent | Offset | API Port | Web Port |
|---|---|---|---|
| Agent 1 | 10 | 3011 | 3010 |
| Agent 2 | 20 | 3021 | 3020 |
| Agent 3 | 30 | 3031 | 3030 |

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

## Adopting Ralph in Your Project

1. **Copy this repo's structure** into your project:
   ```
   .github/agents/
   .github/skills/
   .github/prompts/
   scripts/ralph/
   AGENTS.md → .github/copilot-instructions.md
   CLAUDE.md → .github/copilot-instructions.md
   ```

2. **Fill in `.github/copilot-instructions.md`** with your project's tech stack, commands, and architecture

3. **Create a PRD** using the `prd` skill or manually write `docs/prds/prd-feature.md`

4. **Convert to Ralph format** using the `ralph` skill → produces `scripts/ralph/prd-feature.json`

5. **Run manually** (single feature):
   ```bash
   ./scripts/ralph/ralph.sh --prd prd-feature.json --tool copilot 10
   ```

6. **Or use the orchestrator** (multiple features in parallel):
   - Place multiple `prd-*.json` files in `scripts/ralph/`
   - Invoke the ralph-orchestrator agent

## Supported AI Tools

Ralph supports three AI backends via `--tool`:

| Tool | Command | Flag |
|---|---|---|
| **GitHub Copilot CLI** | `copilot` | `--tool copilot` (default) |
| **Claude Code** | `claude` | `--tool claude` |
| **AMP** | `amp` | `--tool amp` |

## License

MIT
