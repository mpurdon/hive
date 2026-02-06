# The Hive - Queen Delegation Principle

## The Problem

In Gas Town, the Mayor sometimes "just did the work" instead of delegating to polecats. This defeats the entire purpose of the multi-agent architecture:

```
❌ WRONG: Queen receives task → Queen does the coding herself
✅ RIGHT: Queen receives task → Queen creates job → Queen spawns bee → Bee does the coding
```

## Why This Happens

1. **Path of least resistance** - It's "easier" to just do it than set up delegation
2. **Context already loaded** - Queen already understands the task
3. **No enforcement** - Nothing prevents Queen from coding directly
4. **Unclear boundaries** - Queen's role isn't strictly defined

## The Solution: Queen Never Codes

### Hard Rule

**The Queen MUST NOT:**
- Write application code
- Modify project files
- Run tests
- Make commits
- Push branches

**The Queen MUST:**
- Analyze requests and break them into jobs
- Create quests for related work
- Spawn bees and assign jobs
- Monitor progress via waggles
- Summarize results to the user
- Handle escalations from stuck bees

### Enforcement Mechanisms

#### 1. Working Directory Isolation

The Queen runs from `<hive>/.hive/queen/` - a directory with NO project code:

```
~/my-hive/
├── .hive/
│   ├── queen/           # Queen's workspace - NO CODE HERE
│   │   └── QUEEN.md     # Queen's instructions
│   ├── config.toml
│   └── hive.db
└── myproject/           # Comb - Queen can't touch this
```

#### 2. Queen's CLAUDE.md

The Queen's context file explicitly forbids coding:

```markdown
# Queen Instructions

You are the Queen of this Hive. Your role is COORDINATION, not coding.

## You MUST NOT
- Write or modify any code files
- Run application tests
- Make git commits
- Touch any files in comb directories

## You MUST
- Break down user requests into discrete jobs
- Create quests to bundle related jobs
- Spawn bees to execute jobs: `hive bee spawn --job <job-id>`
- Monitor bee progress: `hive bees`
- Report quest status to the user

## When a user asks you to build something:

1. Analyze the request
2. Create a quest: `hive quest create "Feature name"`
3. Create jobs for each discrete task
4. Spawn bees for each job
5. Monitor and report progress

## Example

User: "Add user authentication to myproject"

You should:
1. `hive quest create "User Authentication" --comb myproject`
2. `hive job create "Create User model" --quest <quest-id>`
3. `hive job create "Implement login endpoint" --quest <quest-id>`
4. `hive job create "Add session management" --quest <quest-id>`
5. `hive bee spawn --job <job-id>` for each job
6. `hive quest show <quest-id>` to monitor
7. Report: "Quest 'User Authentication' complete: 3/3 jobs done"

NEVER write the code yourself. ALWAYS delegate to bees.
```

#### 3. Sparse Checkout for Queen

Queen's git config excludes all comb directories:

```bash
# Queen can only see .hive/ directory
git sparse-checkout set .hive/
```

#### 4. CLI Guardrails

The `hive prime --queen` command:
- Sets working directory to `.hive/queen/`
- Injects the "no coding" instructions
- Provides only coordination commands

#### 5. Audit Trail

Log when Queen attempts file operations outside `.hive/`:

```elixir
defmodule Hive.Queen.Audit do
  def check_file_access(path) do
    if outside_hive_dir?(path) do
      Logger.warning("Queen attempted to access #{path} - delegation required")
      {:error, :delegation_required}
    else
      :ok
    end
  end
end
```

### The Delegation Flow

```
User: "Fix bug #123 in myproject"
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│ Queen analyzes request                                  │
│                                                         │
│ > This is a coding task. I must delegate.               │
│ > Creating job for bug fix...                           │
│                                                         │
│ $ hive job create "Fix bug #123" --comb myproject       │
│ Created job: job-abc123                                 │
│                                                         │
│ $ hive bee spawn --job job-abc123                       │
│ Spawned bee: bee-xyz789                                 │
│                                                         │
│ > Bee spawned. Monitoring progress...                   │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│ Bee (bee-xyz789) in cell worktree                       │
│                                                         │
│ - Reads job description                                 │
│ - Writes code to fix bug                                │
│ - Runs tests                                            │
│ - Commits changes                                       │
│ - Runs: hive done --job job-abc123                      │
│ - Pushes branch, creates PR                             │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│ Queen receives completion waggle                        │
│                                                         │
│ > Bee completed job-abc123                              │
│ > Bug #123 fixed, PR created: #456                      │
│                                                         │
│ Reports to user: "Bug #123 fixed! PR #456 ready."       │
└─────────────────────────────────────────────────────────┘
```

### Parallel Work

When 10 bugs come in:

```
User: "Fix bugs #1-10 in myproject"
         │
         ▼
Queen creates quest with 10 jobs
         │
         ▼
Queen spawns 10 bees (or batches based on config)
         │
         ├── Bee 1 → Bug #1
         ├── Bee 2 → Bug #2
         ├── Bee 3 → Bug #3
         │   ...
         └── Bee 10 → Bug #10
         │
         ▼
Bees work in parallel, each in isolated cell
         │
         ▼
Queen monitors, reports: "Quest complete: 10/10 bugs fixed"
```

### Escalation Path

If a bee gets stuck:

```
Bee: "I can't figure out how to fix this bug"
         │
         ▼ (waggle to queen)
         │
Queen: "Bee stuck on job-abc123. Options:
        1. Provide more context to bee
        2. Reassign to different bee
        3. Escalate to user for guidance"
         │
         ▼
Queen sends waggle with hints, or asks user
```

## Implementation Checklist

- [ ] Queen workspace at `.hive/queen/` with no code access
- [ ] Queen's CLAUDE.md with strict "no coding" rules
- [ ] Sparse checkout excluding combs from Queen's view
- [ ] `hive prime --queen` sets up isolation
- [ ] Audit logging for Queen file access attempts
- [ ] Clear CLI commands for delegation workflow
- [ ] Quest/job creation commands for Queen
- [ ] Bee spawn command that Queen uses
- [ ] Waggle system for bee → queen communication
- [ ] Progress monitoring commands

## Summary

The key insight: **Make delegation the path of least resistance**.

If the Queen can't see the code, she can't edit it. If she can't edit it, she must delegate. The architecture enforces the behavior we want.
