# Copilot Instructions

> **This is a template.** Replace the placeholder sections below with your project-specific details.

## Project

**<your-project-name>** — <brief description of your project>.

## Tech Stack

- **Language**: <e.g., TypeScript, Python, Go>
- **Runtime**: <e.g., Node.js 22, Python 3.12>
- **Package manager**: <e.g., npm, yarn, pip, cargo>
- **Backend**: <e.g., Express, FastAPI, Go net/http>
- **Frontend**: <e.g., Next.js, React, Vue>
- **Database**: <e.g., PostgreSQL, Firestore, SQLite>
- **Testing**: <e.g., Vitest, pytest, go test>

## Commands

```bash
# Build
<your-build-command>

# Typecheck
<your-typecheck-command>

# Run dev server
<your-dev-command>

# Run tests
<your-test-command>
```

## Architecture

Describe your project's architecture here:
- Workspace/package layout
- Request flow
- Key modules and their responsibilities

## Key Conventions

Document project-specific conventions:
- Code patterns to follow
- File naming conventions
- Testing patterns
- Import/module conventions

## Environments

| | Dev | Staging | Production |
|---|---|---|---|
| **URL** | `http://localhost:3000` | | |

## Agent System

This project uses the [Ralph agent system](scripts/ralph/) for autonomous feature development. See the [agents README](README.md) for details on how agents, skills, and the orchestrator interact.
