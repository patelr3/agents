# RaV Town — Read-and-Vibe Town

![RaV Town Banner](rav-town-banner.png)

A Claude Code plugin marketplace for **multi-agent orchestration** — autonomously implement features from Product Requirements Documents (PRDs). Coordinates parallel AI agents, each working in isolated git worktrees, to go from specification to merged pull request.

## Installation

Add the marketplace and install the plugins you want:

```
/plugin marketplace add patelr3/agents
/plugin install rav-town@rav-town-marketplace
/plugin install dev-browser@rav-town-marketplace
```

## Plugins

### rav-town

The core orchestration system. Includes:

| Component | Type | Description |
|---|---|---|
| **prd** | skill | Generate structured PRDs from feature descriptions |
| **ralph-prd** | skill | Convert markdown PRDs to Ralph's JSON execution format |
| **ralph-loop** | skill | Iterative execution loop — one story per AI session |
| **worktree** | skill | Isolated git worktree lifecycle management |
| **ravtown-mayor** | agent | Fleet manager — coordinates parallel PRD implementations |
| **ralph-agent** | agent | Autonomous PRD processor — reads, converts, implements |

[→ Full documentation](plugins/rav-town/README.md)

### dev-browser

Standalone browser automation via Playwright. Navigate websites, fill forms, take screenshots, extract data, test web apps. Used by rav-town agents to visually verify UI changes, but works independently too.

[→ Full documentation](plugins/dev-browser/README.md)

## Quick Start

### 1. Create a PRD

```
/prd Add a task priority system with high/medium/low levels
```

Creates `docs/prds/prd-<date>-<feature>.md` with `status: todo`.

### 2. Launch the Orchestrator

Start the ravtown-mayor agent, then submit PRDs:

```
Complete docs/prds/prd-2026-03-15-task-priority.md
```

Or submit everything:

```
Complete all todo PRDs
```

### 3. Watch It Work

The mayor delegates to ralph-agent subagents running in isolated worktrees. Each agent:
1. Converts the PRD to structured JSON
2. Implements stories one at a time (fresh AI session per story)
3. Runs quality checks, commits, logs progress
4. Creates and auto-merges a PR when done

## How It Works

```
┌──────────────────────────────────────────────────────────────┐
│                      Ravtown Mayor                            │
│  Accepts PRDs → tracks state → invokes /worktree per PRD      │
└────────┬─────────────────────────────────────────────────────┘
         │
         ├─ /worktree #1 (port offset 10)
         │  ├─ creates branch ralph/<feature>
         │  ├─ spawns ralph-agent
         │  │   ├─ /ralph-prd → converts PRD to JSON
         │  │   └─ /ralph-loop → implements stories iteratively
         │  └─ creates PR → merges → cleans up
         │
         ├─ /worktree #2 (port offset 20)
         │  └─ parallel independent feature
         │
         └─ /worktree #3 (port offset 30)  [blocked]
            └─ waits for dependency to complete
```

## PRD Format

PRDs flow through stages tracked by YAML frontmatter: `todo` → `inprogress` → `complete`.

Ralph JSON format:
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
- Stories ordered by dependency (schema → backend → UI)
- Every story needs `"Typecheck passes"` as a criterion
- UI stories need `"Verify in browser using dev-browser skill"`

## Supported AI Backends

The ralph-loop supports three backends via `--tool`:

| Tool | Command | Flag |
|---|---|---|
| **GitHub Copilot CLI** | `copilot` | `--tool copilot` (default) |
| **Claude Code** | `claude` | `--tool claude` |
| **AMP** | `amp` | `--tool amp` |

## License

MIT
