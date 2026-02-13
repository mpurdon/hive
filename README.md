# The Hive

Multi-agent orchestration system for AI coding assistants. Coordinate multiple AI instances working on a shared codebase with automatic task delegation, isolated git worktrees, inter-agent messaging, cost tracking, and a real-time web dashboard.

Supports multiple model providers through a plugin system: Claude Code, GitHub Copilot CLI, Kimi CLI, and any future provider via the `Hive.Plugin.Model` behaviour.

Built in Elixir, leveraging OTP supervision trees for process management, Phoenix PubSub for messaging, and SQLite for persistence.

## Getting Started

### 1. Install prerequisites

You need three things on your machine:

| Dependency | Version | Install |
|------------|---------|---------|
| **Elixir** | 1.15+ | `brew install elixir` or [elixir-lang.org/install](https://elixir-lang.org/install.html) |
| **Git** | 2.25+ | `brew install git` or [git-scm.com](https://git-scm.com) |
| **AI CLI** | latest | At least one: `claude`, `copilot`, or `kimi` |

Verify everything is ready:

```bash
elixir --version   # should print 1.15+
git --version      # should print 2.25+

# At least one of these:
claude --version   # Claude Code CLI
copilot --version  # GitHub Copilot CLI
kimi --version     # Kimi CLI
```

### 2. Build the Hive CLI

```bash
git clone git@github.com:mpurdon/hive.git
cd hive
mix deps.get
mix escript.build
```

This produces a `./hive` binary. Optionally move it to your PATH:

```bash
cp hive /usr/local/bin/
```

### 3. Create a hive workspace

The quickest way -- auto-discovers any git repos in the target directory:

```bash
hive init ~/my-hive --quick
```

Or step by step:

```bash
hive init ~/my-hive
cd ~/my-hive
hive comb add /path/to/your/repo --name myproject
```

### 4. Start the Queen

```bash
cd ~/my-hive
hive queen
```

Tell the Queen what you want built. She'll analyze your request, break it into jobs, spawn worker bees (parallel AI instances), and coordinate them to completion.

### 5. Monitor progress

```bash
hive watch              # live terminal progress
hive quest list         # see active quests
hive bee list           # see running bees
hive costs summary      # check token spend
hive dashboard          # web UI at localhost:4040
```

Run `hive doctor` at any time to verify your setup is healthy.

## How It Works

```
You: "Build user authentication"
        |
        v
   Queen (coordinator)
   Analyzes request, creates quest with 3 jobs:
     - "Create user model"
     - "Implement login endpoint"
     - "Add session management"
        |
        v
   Spawns 3 bees (parallel AI instances)
   Each bee works in an isolated git worktree
        |
        v
   Bees complete work, report back via waggles
        |
        v
   "Auth system complete, 3/3 jobs done"
```

The Queen never writes code herself -- she only delegates. Each bee gets its own git worktree (cell) so multiple agents can work on the same repo without conflicts.

## Model Providers

The Hive uses a plugin system to support multiple AI model providers. The active provider is resolved per-session via config or CLI flags.

| Provider | Binary | Streaming | Cost Tracking | Session Resume |
|----------|--------|-----------|---------------|----------------|
| **Claude Code** | `claude` | JSONL | Yes | Yes |
| **Copilot CLI** | `copilot` | Plain text | No (subscription) | No |
| **Kimi CLI** | `kimi` | JSONL | Yes | Yes |

Set the default provider in `.hive/config.toml`:

```toml
[plugins.models]
default = "claude"   # or "copilot" or "kimi"
```

Or pass it per-command:

```bash
hive queen --model-plugin copilot
```

### Writing a custom provider

Implement the `Hive.Plugin.Model` behaviour and register it with the Plugin Manager. See `lib/hive/plugin/builtin/models/` for examples. Use `mix hive.gen.plugin model my_provider` to scaffold.

## Core Concepts

| Concept | Name | Description |
|---------|------|-------------|
| Workspace | **Hive** | Root directory containing projects, config, and database |
| Coordinator | **Queen** | AI agent that plans and delegates (never codes directly) |
| Project | **Comb** | A git repository registered with the hive |
| Worker | **Bee** | Ephemeral AI instance that executes a single job |
| Work unit | **Job** | A discrete task assigned to a bee |
| Work bundle | **Quest** | A group of related jobs forming a larger objective |
| Messages | **Waggle** | Inter-agent communication (named after the bee waggle dance) |
| Worktree | **Cell** | Isolated git worktree where a bee does its work |
| Monitor | **Drone** | Health patrol agent that checks for stuck bees and orphaned cells |
| Restart | **Handoff** | Context-preserving session restart when a bee's context fills up |

## CLI Reference

### Workspace

```bash
hive init [PATH] [--quick] [--force]   # Initialize a hive workspace
hive doctor [--fix]                     # Run health checks
hive dashboard                          # Start web UI (localhost:4040)
hive watch                              # Live progress monitor
hive version                            # Print version
```

### Projects (Combs)

```bash
hive comb add <path> [--name NAME]      # Register a git repo
  [--merge-strategy manual|auto_merge|pr_branch]
  [--validation-command "mix test"]
  [--github-owner OWNER] [--github-repo REPO]
hive comb list                          # List registered projects
hive comb remove <name>                 # Unregister a project
hive comb rename <old> <new>            # Rename a comb
```

### Orchestration

```bash
hive queen                              # Start Queen coordinator session
hive bee list                           # List all bees
hive bee spawn --job ID --comb ID       # Spawn a worker bee
hive bee stop --id ID                   # Stop a running bee
hive bee revive --id ID                 # Revive a dead bee's worktree
hive bee done --id ID                   # Mark a bee as completed
hive bee fail --id ID --reason "..."    # Mark a bee as failed
```

### Work Tracking

```bash
hive quest new <name>                   # Create a quest
hive quest list                         # List quests
hive quest show <id>                    # Show quest details with jobs

hive jobs list                          # List all jobs
hive jobs show <id>                     # Show job details
hive jobs create --quest ID --title T --comb ID  # Create a job
```

### Job Dependencies

```bash
hive jobs deps add --job ID --depends-on ID    # Add dependency
hive jobs deps remove --job ID --depends-on ID # Remove dependency
hive jobs deps list --job ID                   # Show dependencies
```

### Messaging (Waggles)

```bash
hive waggle list [--to RECIPIENT]       # List messages
hive waggle show <id>                   # Read a message
hive waggle send -f FROM -t TO -s SUBJ -b BODY  # Send a message
```

### Cost Tracking

```bash
hive costs summary                      # Aggregate cost report
hive costs record --bee ID --input N --output N  # Record costs manually
hive budget --quest ID                  # Check quest budget status
```

### Git Worktrees (Cells)

```bash
hive cell list                          # List active worktrees
hive cell clean                         # Remove orphaned worktrees
```

### Advanced

```bash
hive prime --queen                      # Output Queen context prompt
hive prime --bee <id>                   # Output Bee context prompt
hive handoff create --bee ID            # Create context-preserving handoff
hive handoff show --bee ID              # Show handoff context
hive conflict check [--bee ID]          # Check for merge conflicts
hive validate --bee ID                  # Validate a bee's completed work
hive drone [--no-fix]                   # Start health patrol
```

### Plugins

```bash
hive plugin list                        # List loaded plugins
hive plugin load <path>                 # Load a plugin from file
hive plugin unload <type> <name>        # Unload a plugin
hive plugin reload <type> <name>        # Hot-reload a plugin
```

### GitHub Integration

```bash
hive github pr --bee ID                 # Create PR for a bee's work
hive github issues --comb ID            # List issues for a project
hive github sync --comb ID              # Sync GitHub issues
```

## Configuration

The hive config lives at `.hive/config.toml`:

```toml
[hive]
version = "0.1.0"

[queen]
max_bees = 5

[costs]
warn_threshold_usd = 5.0
budget_usd = 10.0

[plugins.models]
default = "claude"

[github]
token = ""
```

You can also set the `HIVE_PATH` environment variable to point to your hive workspace from anywhere.

## Workspace Structure

```
~/my-hive/                     # Hive root
├── .hive/
│   ├── config.toml            # Hive configuration
│   ├── hive.db                # SQLite database
│   └── queen/                 # Queen's workspace (no code access)
├── myproject/                 # Comb (registered repo)
│   ├── .git/
│   └── bees/                  # Bee worktrees
│       ├── bee-abc123/        # Cell with isolated working copy
│       └── bee-def456/
└── another-project/           # Another comb
```

## Architecture

```
Hive.Application (OTP Supervisor)
├── Phoenix.PubSub (inter-agent messaging)
├── Registry (process registry)
├── Hive.Plugin.Manager (plugin lifecycle + hot reload)
│   ├── Hive.Plugin.Registry (ETS-backed plugin lookup)
│   ├── Hive.Plugin.MCPSupervisor (MCP plugin children)
│   └── Hive.Plugin.ChannelSupervisor (channel plugin children)
├── Hive.CombSupervisor (DynamicSupervisor)
│   └── Hive.Comb (per-project supervisor)
│       ├── Hive.Bee.Worker (GenServer per worker)
│       └── Hive.TranscriptWatcher (file watcher)
├── Hive.Queen (GenServer - started on demand)
├── Hive.Drone (GenServer - health monitor)
└── Hive.Dashboard.Endpoint (Phoenix - web UI)
```

### Plugin System

The plugin architecture provides six extension points:

| Type | Behaviour | Purpose |
|------|-----------|---------|
| **Model** | `Hive.Plugin.Model` | AI provider integration (spawn, parse, costs) |
| **Command** | `Hive.Plugin.Command` | TUI slash commands |
| **Theme** | `Hive.Plugin.Theme` | Color palettes for the TUI |
| **LSP** | `Hive.Plugin.LSP` | Language server integration |
| **MCP** | `Hive.Plugin.MCP` | Model Context Protocol servers |
| **Channel** | `Hive.Plugin.Channel` | External notification channels |

Plugins are discovered at startup and can be hot-reloaded at runtime via `Hive.Plugin.Manager`.

### Runtime Modules

| Module | Purpose |
|--------|---------|
| `Hive.Runtime.Models` | Central facade -- resolves active plugin, delegates all model operations |
| `Hive.Runtime.Terminal` | Shared terminal handoff utilities for interactive TUI providers |
| `Hive.Runtime.StreamParser` | JSONL stream parsing (used by providers with JSON output) |
| `Hive.Runtime.Settings` | Generates provider-specific workspace configuration |

### Key Design Decisions

- **Elixir/OTP** -- Supervision trees handle crash recovery, GenServers manage per-agent state, PubSub enables real-time messaging, Ports provide native process spawning
- **SQLite** -- Zero-config, single-file persistence with full Ecto query support
- **Git worktrees** -- Each bee gets an isolated working directory while sharing git objects, with sparse checkout excluding `.hive/` from bee view
- **Provider-neutral plugin system** -- All model-specific logic lives behind the `Hive.Plugin.Model` behaviour; the core orchestration is provider-agnostic
- **No tmux** -- Native Elixir processes are first-class citizens, giving better monitoring and cross-platform support

For detailed architecture docs, see [`specs/ARCHITECTURE.md`](specs/ARCHITECTURE.md).

## Development

```bash
# Run tests
mix test

# Run tests (excluding e2e)
mix test --exclude e2e

# Format code
mix format

# Build escript
mix escript.build
```

## Further Reading

- [`specs/ARCHITECTURE.md`](specs/ARCHITECTURE.md) -- Supervision tree, database schema, process communication
- [`specs/GLOSSARY.md`](specs/GLOSSARY.md) -- Full terminology reference
- [`specs/DELEGATION.md`](specs/DELEGATION.md) -- Queen delegation principle and enforcement
- [`specs/TASKS.md`](specs/TASKS.md) -- Implementation task breakdown

## License

MIT
