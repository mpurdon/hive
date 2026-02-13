# The Hive

**Multi-agent orchestration system for AI coding assistants with persistent work tracking**

## Quick Start

```bash
hive init ~/my-hive --git
cd ~/my-hive
hive comb add myproject https://github.com/you/repo.git
hive queen
```

Then tell the Queen what you want to build!

## Overview

The Hive is a workspace manager that coordinates multiple AI coding agents working on different tasks. Built in Elixir, it leverages OTP patterns for process supervision, Phoenix PubSub for messaging, and SQLite for persistence.

Supports multiple model providers through a plugin system: Claude Code, GitHub Copilot CLI, Kimi CLI, and any custom provider via the `Hive.Plugin.Model` behaviour.

## Core Concepts

| Concept | Name | Description |
|---------|------|-------------|
| Workspace | **Hive** | Root directory, one Queen |
| Coordinator | **Queen** | AI that orchestrates work |
| Project | **Comb** | Git repo container |
| Worker agent | **Bee** | Ephemeral AI instance |
| Work unit | **Job** | Single task for a bee |
| Work bundle | **Quest** | Group of related jobs |
| Messages | **Waggle** | Inter-agent communication |
| Persistent state | **Cell** | Git worktree for bee's work |

## Architecture

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
├── Hive.Queen (GenServer - started on demand)
├── Hive.Drone (GenServer - health monitor)
└── Hive.Dashboard.Endpoint (Phoenix - web UI)
```

## Workflow

```
You → hive queen
        "Build user authentication system"
        ↓
      Queen creates jobs:
        - job-a1b2: "Create user model"
        - job-c3d4: "Implement login endpoint"
        - job-e5f6: "Add session management"
        ↓
      Queen spawns bees, assigns jobs
        ↓
      Bees complete work, Queen tracks progress
        ↓
      You see: "Auth system complete, 3/3 jobs done"
```

## Model Providers

| Provider | Streaming | Cost Tracking | Session Resume |
|----------|-----------|---------------|----------------|
| Claude Code | JSONL | Yes | Yes |
| Copilot CLI | Plain text | No | No |
| Kimi CLI | JSONL | Yes | Yes |

Configure the default in `.hive/config.toml`:

```toml
[plugins.models]
default = "claude"
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `hive init` | Initialize a new hive |
| `hive queen` | Start Queen session |
| `hive comb add` | Add a project |
| `hive comb list` | List projects |
| `hive comb rename` | Rename a comb |
| `hive quest list` | Show quests |
| `hive quest show` | Quest details |
| `hive bees` | List active bees |
| `hive bee revive` | Revive a dead bee |
| `hive waggle list` | Check messages |
| `hive costs` | Token costs |
| `hive doctor` | Health checks |
| `hive dashboard` | Web UI |
| `hive plugin list` | List plugins |
| `hive watch` | Live progress |

## Dependencies

- Elixir 1.15+
- Git 2.25+ (for worktree support)
- At least one AI CLI: `claude`, `copilot`, or `kimi`

## License

MIT
