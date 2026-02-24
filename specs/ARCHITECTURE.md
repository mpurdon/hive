# The Hive - Architecture

## System Overview

The Hive is a multi-agent orchestration system designed to operate as a "Dark Factory" for software development. It coordinates multiple AI agents (Bees) to autonomously plan, implement, verify, and deliver code changes with minimal human oversight.

The system leverages a **Research → Plan → Implement** pipeline, enforced by a central coordinator (Queen) and a dedicated quality assurance watchdog (Drone).

## Core Architecture

### Supervision Tree

```
Hive.Application (OTP App)
├── Hive.Repo (SQLite via Ecto)
├── Phoenix.PubSub (inter-agent messaging)
├── Registry (process registry)
├── Hive.Plugin.Manager (plugin lifecycle + hot reload)
│   ├── Hive.Plugin.Registry (ETS-backed lookup)
│   ├── Hive.Plugin.MCPSupervisor
│   └── Hive.Plugin.ChannelSupervisor
├── Hive.CombSupervisor (DynamicSupervisor)
│   └── Hive.Comb (per-project supervisor)
│       ├── Hive.Bee.Worker (GenServer per worker)
│       └── Hive.TranscriptWatcher (file watcher)
├── Hive.Queen (GenServer - coordinator)
├── Hive.Drone (GenServer - autonomous watchdog)
└── Hive.Dashboard.Endpoint (Phoenix - web UI)
```

### Process Communication

Agents communicate via **Waggles** (messages) broadcast over Phoenix PubSub.

```
                    ┌─────────────────┐
                    │  Phoenix.PubSub │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  waggle:queen   │ │ waggle:bee:123  │ │waggle:comb:proj │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   Hive.Queen    │ │ Hive.Bee.Worker │ │   Hive.Comb     │
│   (GenServer)   │ │   (GenServer)   │ │   (Supervisor)  │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

## Data Model

The system uses a document-oriented approach over SQLite.

### Schema Entities

| Entity | Description | Key Fields |
|--------|-------------|------------|
| **Comb** | A managed git repository | `id`, `name`, `path`, `repo_url` |
| **Quest** | High-level objective | `id`, `goal`, `status`, `plan`, `current_phase` |
| **Job** | Discrete unit of work | `id`, `title`, `job_type`, `status`, `assigned_model`, `verification_status` |
| **Bee** | Active agent instance | `id`, `name`, `status`, `context_usage`, `assigned_model` |
| **Cell** | Isolated git worktree | `id`, `worktree_path`, `branch` |
| **Waggle** | Inter-agent message | `id`, `from`, `to`, `subject`, `body` |

### Job Types
- **Planning**: Breaking down requirements (Model: Opus)
- **Implementation**: Writing code (Model: Sonnet)
- **Research**: Analyzing codebase (Model: Haiku)
- **Verification**: Running tests/checks (Model: Haiku)

## Autonomous Workflows ("The Dark Factory")

The Hive operates on a strict phased pipeline to ensuring quality and autonomy.

### 1. Research → Plan → Implement
1.  **Research Phase**: The Queen scans the codebase using cost-effective models (Haiku) to map dependencies, entry points, and constraints. This data is cached to minimize token usage.
2.  **Planning Phase**: The Queen uses high-intelligence models (Opus) to decompose the Quest into a dependency graph of Jobs. Each job is assigned a specific `job_type` and `verification_criteria`.
3.  **Implementation Phase**: Bees are spawned to execute jobs in parallel. Each Bee works in an isolated **Cell** (git worktree) to prevent conflicts.

### 2. Multi-Model Intelligence
The system dynamically selects the optimal AI model for each task to balance cost and quality:
*   **Claude 3.5 Sonnet**: Default for implementation and refactoring.
*   **Claude 3 Opus**: Used for complex planning and architectural decisions.
*   **Claude 3 Haiku**: Used for high-volume tasks like research, summarization, and verification.

### 3. Context Management
*   **Context Monitor**: Real-time tracking of token usage per Bee.
*   **Auto-Handoff**: If a Bee exceeds 50% context usage, it automatically summarizes its state and "hands off" to a fresh instance to prevent context window exhaustion.

### 4. Quality Assurance & Verification
The **Drone** acts as an autonomous quality gatekeeper:
*   **Verification Gates**: A Job cannot be marked "Done" until it passes verification.
*   **Static Analysis**: Automated linting and code style checks.
*   **Security Scanning**: Vulnerability detection (secrets, dependencies).
*   **Performance Benchmarking**: Regression testing against baselines.
*   **Self-Healing**: The Drone periodically patrols the Hive to detect stuck Bees, deadlocks, or orphaned resources, automatically triggering recovery procedures.

## Observability

The system provides real-time visibility into the "Dark Factory" operations:

*   **TUI Dashboard**: A terminal-based UI showing active Bees, Quests, and system health.
*   **Metrics**: Real-time tracking of Quality Scores, Token Costs, and Failure Rates.
*   **Alerts**: Immediate notifications for stalled quests, validation failures, or budget overruns.

## Plugin System

The Hive is extensible via a behaviour-based plugin system:

*   **Models**: Adapters for AI providers (Claude, Copilot, Kimi).
*   **Commands**: Custom CLI extensions.
*   **Themes**: UI styling.

## Future Roadmap

*   **Enterprise Monitoring**: Prometheus/Grafana integration for long-term metrics history.
*   **Multi-Agent Collaboration**: Direct Bee-to-Bee communication for collaborative problem solving.
*   **Human-in-the-Loop**: Interactive approval gates for high-risk changes.
