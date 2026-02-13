# The Hive - Architecture

## Supervision Tree

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
├── Hive.Queen (GenServer - coordinator, started on demand)
├── Hive.Drone (GenServer - health monitor)
└── Hive.Dashboard.Endpoint (Phoenix - web UI)
```

## Core Dependencies

```elixir
defp deps do
  [
    {:ecto_sqlite3, "~> 0.12"},      # SQLite persistence
    {:phoenix_pubsub, "~> 2.1"},     # Inter-agent messaging
    {:phoenix, "~> 1.7"},            # Web dashboard
    {:phoenix_live_view, "~> 1.0"},  # Real-time dashboard
    {:fs, "~> 8.6"},                 # File system watching
    {:jason, "~> 1.4"},              # JSON parsing
    {:optimus, "~> 0.5"},            # CLI argument parsing
    {:toml, "~> 0.7"},               # Config file parsing
    {:req, "~> 0.5"},                # HTTP client (GitHub API)
    {:term_ui, "~> 0.1"},            # Terminal UI framework
  ]
end
```

## Database Schema

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   combs     │     │   quests    │     │    jobs     │
├─────────────┤     ├─────────────┤     ├─────────────┤
│ id          │     │ id          │     │ id          │
│ name        │     │ name        │     │ title       │
│ repo_url    │     │ status      │     │ description │
│ path        │     │ created_at  │     │ status      │
│ created_at  │     │ updated_at  │     │ quest_id    │◄──┐
└─────────────┘     └─────────────┘     │ bee_id      │   │
                           │            │ comb_id     │   │
                           │            │ created_at  │   │
                           └────────────┴─────────────┘   │
                                                          │
┌─────────────┐     ┌─────────────┐     ┌─────────────┐   │
│    bees     │     │   waggles   │     │   costs     │   │
├─────────────┤     ├─────────────┤     ├─────────────┤   │
│ id          │     │ id          │     │ id          │   │
│ name        │     │ from        │     │ bee_id      │───┘
│ status      │     │ to          │     │ input_tokens│
│ job_id      │     │ subject     │     │ output_tokens│
│ cell_path   │     │ body        │     │ cost_usd    │
│ pid         │     │ read        │     │ recorded_at │
│ created_at  │     │ created_at  │     └─────────────┘
└─────────────┘     └─────────────┘

┌─────────────┐
│   cells     │
├─────────────┤
│ id          │
│ bee_id      │
│ comb_id     │
│ worktree_path│
│ branch      │
│ created_at  │
└─────────────┘
```

## Plugin System

The plugin architecture allows extending the Hive with new model providers, commands, themes, and integrations.

### Plugin Types

| Type | Behaviour | Built-in |
|------|-----------|----------|
| Model | `Hive.Plugin.Model` | Claude, Copilot, Kimi |
| Command | `Hive.Plugin.Command` | Help, Quit, Quest, Bee, Plugin |
| Theme | `Hive.Plugin.Theme` | Default |
| LSP | `Hive.Plugin.LSP` | Generic |
| MCP | `Hive.Plugin.MCP` | (none yet) |
| Channel | `Hive.Plugin.Channel` | Telegram |

### Plugin Lifecycle

```
1. Application starts
        │
        ▼
2. Plugin.Manager.init()
   ├── Plugin.Registry.init() (creates ETS tables)
   ├── Register built-in models (Claude, Copilot, Kimi)
   ├── Register built-in themes, commands
   └── Set default theme
        │
        ▼
3. Runtime: Plugin.Manager.load_plugin(MyPlugin)
   ├── Detect type from behaviour
   ├── Register in ETS via Plugin.Registry
   ├── Start supervised children (MCP/Channel)
   └── Broadcast via PubSub
```

### Model Plugin Callbacks

Required:
- `name/0` — unique identifier (e.g. `"claude"`, `"copilot"`, `"kimi"`)
- `description/0` — human-readable description
- `spawn_interactive/2` — launch TUI session
- `spawn_headless/3` — launch headless prompt session
- `parse_output/1` — parse raw output into structured events

Optional:
- `find_executable/0` — locate CLI binary
- `workspace_setup/2` — return provider-specific workspace config
- `pricing/0` — token pricing table
- `capabilities/0` — supported feature list
- `extract_costs/1` — extract cost data from events
- `extract_session_id/1` — extract session ID from events
- `progress_from_events/1` — extract progress updates from events
- `detached_command/2` — build shell command for detached spawning

### Model Resolution

```
Hive.Runtime.Models.resolve_plugin(opts)
        │
        ├── 1. Check opts[:model_plugin] (module or name string)
        ├── 2. Check config: plugins.models.default
        └── 3. Fallback: "claude"
```

All call sites use `Hive.Runtime.Models` instead of calling provider modules directly. This ensures provider-neutral orchestration.

## Process Communication

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

## Provider Integration

### Workspace Setup

Provider-specific workspace configuration is generated via `workspace_setup/2`:

- **Claude**: Generates `.claude/settings.json` with hooks and permissions
- **Copilot**: Returns `nil` (manages its own config)
- **Kimi**: Returns `nil` (manages its own config)

### Runtime Flow

```
1. Queen creates job
         │
         ▼
2. Hive.Bee.Worker GenServer starts
         │
         ▼
3. Create git worktree (cell)
         │
         ▼
4. Generate workspace config (provider-specific)
         │
         ▼
5. Spawn AI via Hive.Runtime.Models.spawn_headless()
   (delegates to active provider plugin)
         │
         ▼
6. Provider's hooks/startup inject context
         │
         ▼
7. Context injected, AI starts working
         │
         ▼
8. Output parsed via plugin.parse_output()
         │
         ▼
9. Progress tracked via plugin.progress_from_events()
         │
         ▼
10. AI completes, costs extracted via plugin.extract_costs()
         │
         ▼
11. Bee reports completion via waggle to Queen
         │
         ▼
12. Cell (worktree) merged back and cleaned up
```

## File Structure

```
~/my-hive/                    # Hive root
├── .hive/
│   ├── config.toml           # Hive configuration
│   ├── hive.db               # SQLite database
│   ├── hive.db-journal
│   └── queen/                # Queen's workspace (no code access)
├── myproject/                # Comb (cloned repo)
│   ├── .git/
│   ├── bees/                 # Bee cells (worktrees)
│   │   ├── bee-abc123/
│   │   └── bee-def456/
│   └── ... (repo files)
└── another-project/          # Another comb
```

## Key Design Decisions

### Why Elixir/OTP?

- **Supervision trees** - Automatic crash recovery for bees
- **GenServer** - Clean state management per agent
- **PubSub** - Real-time messaging without polling
- **Ports** - Native process spawning and monitoring
- **Hot code reload** - Update without stopping

### Why SQLite?

- **Zero config** - No external database to manage
- **Single file** - Easy backup and portability
- **Ecto support** - Full query capabilities
- **Concurrent reads** - Multiple bees can query

### Why a Plugin System?

- **Provider-neutral** - Core orchestration doesn't assume any specific AI provider
- **Hot reload** - Load/unload plugins at runtime without restart
- **Extensible** - Six plugin types cover models, commands, themes, LSP, MCP, channels
- **Behaviour-driven** - Clear contracts via Elixir behaviours

### Why No Tmux?

- **Native processes** - Elixir processes are first-class
- **Better monitoring** - Port gives us exit status, output
- **Simpler** - No session management complexity
- **Cross-platform** - Works on Windows too

### Why Git Worktrees?

- **Isolation** - Each bee has its own working directory
- **Shared objects** - Saves disk space
- **Branch per bee** - No conflicts between workers
- **Sparse checkout** - Exclude `.hive/` from bee view
