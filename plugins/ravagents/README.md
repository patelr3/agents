# ravagents

18 specialized engineering agents covering the full software development lifecycle — from product spec to deployment, security, and observability.

## Installation

```
/plugin install ravagents@rav-town-marketplace
```

## Agents

### 🧠 Core Engineering

| Agent | Model | Description |
|---|---|---|
| **feature-developer** | claude-sonnet-4-5 | Implements features from specs, tickets, or PRDs; coordinates with Test and Security agents; opens a PR when complete |
| **refactor-quality** | claude-sonnet-4-5 | Refactors existing code to improve structure, consistency, and maintainability without changing behavior |
| **test-engineer** | claude-sonnet-4-5 | Generates and maintains unit, integration, and E2E tests; validates PRs for coverage; ensures tests are deterministic and behavior-focused |

### 🔐 Security & Reliability

| Agent | Model | Description |
|---|---|---|
| **security-engineer** | claude-opus-4-5 | Reviews code for security vulnerabilities, enforces OWASP Top 10, audits dependencies for CVEs, blocks merges on critical findings |
| **threat-modeling** | claude-opus-4-5 | Builds STRIDE-based threat models, maps attack surfaces, identifies threats, and suggests concrete mitigations |
| **dependency-supply-chain** | gpt-5.4 | Monitors dependencies for outdated packages, CVEs, suspicious releases, and supply chain risks; enforces reproducible builds |

### ⚙️ DevOps & Infrastructure

| Agent | Model | Description |
|---|---|---|
| **devops-cicd** | gpt-5.4 | Maintains CI/CD pipelines and GitHub Actions workflows; enforces build reproducibility, quality gates, caching, and deployment best practices |
| **infra-as-code** | gpt-5.4 | Manages Terraform, Pulumi, and Bicep infrastructure; enforces security best practices, cost efficiency, and drift detection |
| **observability** | gpt-5.4 | Instruments services with logging, metrics, and tracing; designs dashboards and alerts; diagnoses production issues |

### 🧪 Quality, Review & Governance

| Agent | Model | Description |
|---|---|---|
| **code-reviewer** | claude-sonnet-4-5 | Reviews pull requests for style, architecture, correctness, and test coverage with actionable, prioritized feedback |
| **architecture-governance** | claude-opus-4-5 | Enforces architectural integrity by validating layering, module boundaries, domain rules, and separation of concerns |
| **documentation** | gpt-5.4 | Maintains and generates READMEs, API docs, ADRs, and diagrams; keeps documentation in sync with code |

### 🧭 Product & Planning

| Agent | Model | Description |
|---|---|---|
| **product-spec** | gpt-5.4 | Converts ideas and requests into structured, implementation-ready PRDs with acceptance criteria, user stories, and risk analysis |
| **ux-interaction** | gemini-flash | Reviews and designs UI flows, interaction patterns, and component structures with a focus on usability and accessibility (WCAG); uses `/dev-browser` for live visual inspection |
| **roadmap-prioritization** | gpt-5.4 | Plans sprints, grooms backlogs, sequences work by risk and value, surfaces blockers, and keeps the roadmap aligned with product goals |

### 🧩 Power-Up

| Agent | Model | Description |
|---|---|---|
| **migration** | claude-sonnet-4-5 | Handles framework upgrades, major version migrations, and large-scale code transformations safely and incrementally |
| **performance-optimization** | claude-sonnet-4-5 | Profiles code, identifies bottlenecks, and rewrites slow paths with measurable, benchmark-verified improvements |
| **data-validation** | claude-sonnet-4-5 | Validates database schemas, migrations, data integrity, and API contracts to ensure correctness across the stack |

## Model Assignments

Agents are assigned models by task complexity:

| Model | Used By |
|---|---|
| `claude-opus-4-5` | architecture-governance, security-engineer, threat-modeling (complex reasoning) |
| `gemini-flash` | ux-interaction (UI tasks) |
| `claude-sonnet-4-5` | feature-developer, refactor-quality, test-engineer, code-reviewer, migration, performance-optimization, data-validation |
| `gpt-5.4` | product-spec, roadmap-prioritization, documentation, devops-cicd, infra-as-code, observability, dependency-supply-chain |

## Tool Restrictions

Each agent only has access to the tools it needs:

| Tools | Agents |
|---|---|
| `bash` + `text_editor` | feature-developer, refactor-quality, test-engineer, devops-cicd, infra-as-code, observability, architecture-governance, migration, performance-optimization, data-validation, ux-interaction |
| `bash` + `text_editor` + `web_search` | security-engineer, dependency-supply-chain, threat-modeling (CVE/doc lookups) |
| `text_editor` + `web_search` | documentation (no command execution needed) |
| `text_editor` only | code-reviewer, product-spec, roadmap-prioritization (read-only/planning) |

> **Note:** `ux-interaction` includes `bash` to support the `/dev-browser` skill for live visual inspection of running UIs.

## License

MIT
