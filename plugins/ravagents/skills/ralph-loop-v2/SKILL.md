---
name: ralph-loop-v2
description: "Run the Ralph v2 autonomous coding loop with optional ravagents support. Iterates through PRD user stories and associated ravagent review tasks, spawning a fresh AI session per iteration. Triggers on: run ralph loop v2, start ralph v2, execute prd with ravagents, ralph iterate v2."
user-invokable: true
---

# Ralph Loop v2

Runs the Ralph v2 execution loop (`ralph.sh`) that iterates through PRD user stories and, when `useRavagents` is set in the PRD JSON, also runs associated ravagent review tasks after each story's implementation.

---

## The Job

Execute the `ralph.sh` script from this skill's `scripts/` directory. The script reads a PRD JSON file and iterates through its tasks, invoking an AI tool (Copilot, Claude, or AMP) once per iteration. When the PRD JSON contains `"useRavagents": true`, the loop also drives ravagent tasks (test-engineer, devops-cicd, infra-as-code, observability, code-reviewer, documentation, and any others listed) after each story is implemented.

---

## Usage

```bash
${CLAUDE_PLUGIN_ROOT}/skills/ralph-loop-v2/scripts/ralph.sh --prd <path-to-prd.json> [--tool copilot|claude|amp] [--port-offset N] [max_iterations]
```

### Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--prd <file>` | Yes | — | Path to the PRD JSON file (e.g., `docs/prds/prd-2026-03-15-task-status.json`) |
| `--tool <name>` | No | `copilot` | AI backend: `copilot`, `claude`, or `amp` |
| `--port-offset N` | No | — | Port offset for parallel isolation (API=3001+N, Web=3000+N) |
| `max_iterations` | No | `10` | Maximum loop iterations before aborting |

### Example

```bash
# Run with Copilot (default), ravagents mode driven by PRD JSON flag
${CLAUDE_PLUGIN_ROOT}/skills/ralph-loop-v2/scripts/ralph.sh \
  --prd docs/prds/prd-2026-03-15-task-status.json \
  --port-offset 10 \
  20
```

---

## What the Loop Does

### Without ravagents (`useRavagents: false` or field absent)

Behaves identically to `ralph-loop`. Each iteration spawns a fresh AI session that:

1. Reads the PRD JSON file
2. Reads the progress log for context from prior iterations
3. Picks the highest-priority story where `passes: false`
4. Implements that one story
5. Runs quality checks (typecheck, lint, tests)
6. Commits with message: `feat: [US-XXX] - Story Title`
7. Marks the story as `passes: true` in the PRD JSON
8. Appends learnings to the progress file
9. Checks if all stories pass — if so, updates PRD status, creates PR, enables auto-merge, and outputs `<promise>PRD-COMPLETE</promise>`

### With ravagents (`useRavagents: true`)

The PRD JSON contains a `ravagentTasks` array in addition to `userStories`. The loop processes both:

1. Implements user stories in priority order (same as above)
2. After a story is marked `passes: true`, its associated ravagent tasks become available
3. Each ravagent task is processed in a dedicated iteration: the AI embodies that agent's role (test-engineer, code-reviewer, devops-cicd, infra-as-code, observability, documentation, etc.) and applies their expertise to the parent story's changes
4. Ravagent tasks are marked `passes: true` when complete
5. All `userStories` AND all `ravagentTasks` must be `passes: true` before the loop signals `<promise>PRD-COMPLETE</promise>`

---

## PRD JSON Format (v2 with ravagents)

When `useRavagents: true`, the PRD JSON produced by `ralph-agent-v2` includes a `ravagentTasks` array:

```json
{
  "project": "MyApp",
  "branchName": "ralph/my-feature",
  "description": "...",
  "useRavagents": true,
  "userStories": [
    {
      "id": "US-001",
      "title": "Add status field",
      "description": "...",
      "acceptanceCriteria": ["..."],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ],
  "ravagentTasks": [
    {
      "id": "US-001-test-engineer",
      "dependsOnStory": "US-001",
      "agent": "test-engineer",
      "priority": 11,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-001-devops-cicd",
      "dependsOnStory": "US-001",
      "agent": "devops-cicd",
      "priority": 12,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-001-infra-as-code",
      "dependsOnStory": "US-001",
      "agent": "infra-as-code",
      "priority": 13,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-001-observability",
      "dependsOnStory": "US-001",
      "agent": "observability",
      "priority": 14,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-001-code-reviewer",
      "dependsOnStory": "US-001",
      "agent": "code-reviewer",
      "priority": 15,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-001-documentation",
      "dependsOnStory": "US-001",
      "agent": "documentation",
      "priority": 16,
      "passes": false,
      "notes": ""
    }
  ]
}
```

Priority numbering convention: story US-N has priority `N` (e.g., US-001 → priority 1, US-002 → priority 2); its ravagent tasks get priorities `N×10 + 1` through `N×10 + 6` (e.g., US-001 → ravagent priorities 11–16, US-002 → ravagent priorities 21–26). Optional agents continue from offset 7 onward.

---

## Completion

The loop exits successfully (exit 0) when:
- All `userStories` have `passes: true`
- All `ravagentTasks` have `passes: true` (if `useRavagents: true`)
- The PRD markdown frontmatter has been updated to `status: complete`
- A PR has been created with auto-merge enabled
- The output contains `<promise>PRD-COMPLETE</promise>`

The loop exits with failure (exit 1) when:
- `max_iterations` is reached without all tasks passing

---

## Iteration Count Guidance

With ravagents enabled, set `max_iterations` to:

```
(number of user stories × 7) + 5 buffer
```

The factor of 7 accounts for: 1 implementation + 6 mandatory ravagent tasks per story.

---

## Port Isolation

When `--port-offset N` is provided, the script exports environment variables so parallel agents don't collide:

| Variable | Value |
|---|---|
| `PORT` | `3001 + N` |
| `WEB_PORT` | `3000 + N` |
| `NEXT_PUBLIC_API_URL` | `http://localhost:<PORT>` |

---

## Files in This Skill

| File | Purpose |
|---|---|
| `scripts/ralph.sh` | The core v2 execution loop |
| `scripts/CLAUDE.md` | Prompt template injected into each AI iteration (handles both implementation and ravagent tasks) |
