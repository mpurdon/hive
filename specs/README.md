# The Hive

**Multi-agent orchestration system for Claude Code with persistent work tracking**

## Quick Start

```bash
hive init ~/my-hive --git
cd ~/my-hive
hive comb add myproject https://github.com/you/repo.git
hive queen
```

Then tell the Queen what you want to build!

## Overview

The Hive is a workspace manager that coordinates multiple Claude Code agents working on different tasks. Built in Elixir, it leverages OTP patterns for process supervision, Phoenix PubSub for messaging, and SQLite for persistence.

## Core Concepts

| Concept | Name | Description |
|---------|------|-------------|
| Workspace | **Hive** | Root directory, one Queen |
| Coordinator | **Queen** | AI that orchestrates work |
| Project | **Comb** | Git repo container |
| Worker agent | **Bee** | Ephemeral Claude instance |
| Work unit | **Job** | Single task for a bee |
| Work bundle | **Quest** | Group of related jobs |
| Messages | **Waggle** | Inter-agent communication |
| Persistent state | **Cell** | Git worktree for bee's work |

## Architecture

```
Hive.Application (OTP App)
├── Hive.Repo (SQLite via Ecto)
├── Hive.Queen (GenServer - coordinator)
├── Hive.Waggle (Phoenix.PubSub + persistence)
├── Hive.CombSupervisor (DynamicSupervisor)
│   └── Hive.Comb (per-project supervisor)
│       ├── Hive.Bee (GenServer per worker)
│       └── Hive.TranscriptWatcher (file watcher)
└── Hive.Doctor (health checks)
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

## CLI Commands

```bash
# Workspace
hive init <path> [--git]     # Initialize hive
hive doctor [--fix]          # Health checks

# Projects
hive comb add <name> <repo>  # Add project
hive comb list               # List projects

# Coordination
hive queen                   # Start Queen session
hive bees                    # List active bees

# Work tracking
hive quest list              # Show quests
hive quest show <id>         # Quest details
hive jobs                    # List jobs

# Messaging
hive waggle list             # Check messages
hive waggle send <to> <msg>  # Send message

# Monitoring
hive costs [--today]         # Token costs
hive cell list               # Active worktrees
hive dashboard               # Web UI
```

## Dependencies

- Elixir 1.15+
- Git 2.25+ (for worktree support)
- Claude Code CLI

## License

MIT
