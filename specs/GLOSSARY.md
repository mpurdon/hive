# The Hive - Glossary

## Terminology Mapping

| Gas Town | The Hive | Description |
|----------|----------|-------------|
| Town | **Hive** | Root workspace directory |
| Mayor | **Queen** | AI coordinator agent |
| Rig | **Comb** | Project/repository container |
| Polecat | **Bee** | Ephemeral worker agent |
| Bead | **Job** | Single unit of work |
| Convoy | **Quest** | Bundle of related jobs |
| Mail | **Waggle** | Inter-agent messages |
| Hook (worktree) | **Cell** | Git worktree for bee isolation |
| Deacon/Witness | **Drone** | Patrol/health monitor agent |
| Handoff | **Handoff** | Context-preserving restart |

## Core Concepts

### Hive 🐝

Your workspace directory (e.g., `~/my-hive/`). Contains all projects, the Queen, configuration, and the SQLite database. One Queen per Hive.

### Queen 👑

The coordinator AI agent. A Claude Code instance with full context about your workspace. Start here - tell the Queen what you want to accomplish and she'll create jobs and spawn bees.

### Comb 🍯

A project container. Each comb wraps a git repository and manages its associated bees. Multiple combs can exist in one hive.

### Bee 🐝

An ephemeral worker agent. Spawns to complete a single job, then disappears. Each bee runs in its own git worktree (cell) for isolation.

### Job 📋

A discrete unit of work. Created by the Queen, assigned to a bee. Examples: "Implement login endpoint", "Add OAuth provider", "Write tests for auth module".

### Quest 🗺️

A bundle of related jobs. When you tell the Queen "Build user authentication", she creates a quest containing multiple jobs that together accomplish the goal.

### Waggle 💬

The messaging system. Named after the waggle dance bees use to communicate. Bees and Queen exchange waggles to coordinate work, report progress, and handle issues.

### Cell 🔲

A git worktree where a bee does its work. Provides isolation so multiple bees can work on the same comb without conflicts. Cleaned up when the bee completes.

### Drone 🛡️

A patrol agent that monitors hive health. Checks for stuck bees, orphaned cells, and other issues. (Future feature)

## Workflow Terms

### Prime

The context injection that happens when a Claude session starts. The `hive prime` command outputs role-specific context that Claude captures.

### Handoff

When a bee's context window fills up, it can "hand off" to a fresh session. State is serialized, sent as a waggle to itself, and restored in the new session.

### Transcript

Claude's conversation log at `~/.claude/projects/*/transcript.jsonl`. The Hive watches this file to track token usage and costs.

## CLI Commands

| Command | Description |
|---------|-------------|
| `hive init` | Initialize a new hive |
| `hive queen` | Start Queen session |
| `hive comb add` | Add a project |
| `hive comb list` | List projects |
| `hive quest list` | Show quests |
| `hive quest show` | Quest details |
| `hive bees` | List active bees |
| `hive waggle list` | Check messages |
| `hive costs` | Token costs |
| `hive doctor` | Health checks |
| `hive dashboard` | Web UI |
