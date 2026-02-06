# The Hive - Architecture

## Supervision Tree

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

## Core Dependencies

```elixir
defp deps do
  [
    {:ecto_sqlite3, "~> 0.12"},      # SQLite persistence
    {:phoenix_pubsub, "~> 2.1"},     # Inter-agent messaging
    {:fs, "~> 8.6"},                 # File system watching
    {:jason, "~> 1.4"},              # JSON parsing
    {:optimus, "~> 0.5"},            # CLI argument parsing
    {:toml, "~> 0.7"},               # Config file parsing
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
│   Hive.Queen    │ │   Hive.Bee      │ │   Hive.Comb     │
│   (GenServer)   │ │   (GenServer)   │ │   (Supervisor)  │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

## Claude Integration

### Hook Configuration

Generated at `.claude/settings.json` in each cell:

```json
{
  "hooks": {
    "SessionStart": [{
      "command": "hive prime --bee BEE_ID"
    }],
    "Stop": [{
      "command": "hive costs record --bee BEE_ID"
    }]
  }
}
```

### Runtime Flow

```
1. Queen creates job
         │
         ▼
2. Hive.Bee GenServer starts
         │
         ▼
3. Create git worktree (cell)
         │
         ▼
4. Generate .claude/settings.json
         │
         ▼
5. Spawn Claude via Port
         │
         ▼
6. Claude's SessionStart hook runs `hive prime`
         │
         ▼
7. Context injected, Claude starts working
         │
         ▼
8. TranscriptWatcher monitors progress
         │
         ▼
9. Claude completes, Stop hook runs `hive costs record`
         │
         ▼
10. Bee reports completion via waggle to Queen
         │
         ▼
11. Cell (worktree) cleaned up
```

## File Structure

```
~/my-hive/                    # Hive root
├── .hive/
│   ├── config.toml           # Hive configuration
│   ├── hive.db               # SQLite database
│   └── hive.db-journal
├── myproject/                # Comb (cloned repo)
│   ├── .git/
│   ├── bees/                 # Bee cells (worktrees)
│   │   ├── bee-abc123/
│   │   │   ├── .claude/
│   │   │   │   └── settings.json
│   │   │   └── ... (repo files)
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
