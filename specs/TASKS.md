# The Hive - Implementation Tasks

## Task 1: Project Scaffolding & CLI Foundation

**Objective:** Create Elixir project with Mix, add core dependencies, set up CLI entry point

**Implementation:**
- `mix new hive --sup` with application supervision tree
- Add deps: `ecto_sqlite3`, `phoenix_pubsub`, `fs`, `jason`, `optimus` (CLI)
- Create `hive` escript entry point with subcommand routing
- Implement `hive version` command

**Test:** `mix test` passes, `./hive version` outputs version

**Demo:** Run `./hive version` and see version output

---

## Task 2: SQLite Schema & Repo

**Objective:** Set up Ecto with SQLite, create core schemas

**Implementation:**
- Configure Ecto repo with SQLite adapter
- Create migrations for: `combs`, `jobs`, `quests`, `waggles`, `costs`
- Define Ecto schemas with relationships
- Add repo to supervision tree

**Test:** Migrations run, schemas validate

**Demo:** `mix ecto.create && mix ecto.migrate` succeeds, can insert/query a comb

---

## Task 3: Hive Initialization (`hive init`)

**Objective:** Initialize a new Hive workspace with git and config

**Implementation:**
- Create `~/.hive/` directory structure
- Initialize git repo if `--git` flag
- Create `config.toml` with defaults
- Store hive path in config

**Test:** `hive init /tmp/test-hive --git` creates valid structure

**Demo:** Run `hive init ~/my-hive --git`, show directory structure and git status

---

## Task 4: Comb Management (`hive comb add/list`)

**Objective:** Add and list project repositories

**Implementation:**
- `hive comb add <name> <repo-url>` - clones repo, creates comb record
- `hive comb list` - shows all combs with status
- Store comb metadata in SQLite
- Create comb directory structure: `<hive>/<comb>/`

**Test:** Add comb, verify clone, list shows it

**Demo:** `hive comb add myproject https://github.com/...`, then `hive comb list`

---

## Task 5: Waggle System (PubSub + Persistence)

**Objective:** Implement inter-agent messaging

**Implementation:**
- Start Phoenix.PubSub in supervision tree
- Create `Hive.Waggle` GenServer for message persistence
- Topics: `waggle:queen`, `waggle:bee:<id>`, `waggle:comb:<name>`
- Persist messages to SQLite for offline agents
- `hive waggle list` - show pending messages

**Test:** Send message, receive via subscription, persist and retrieve

**Demo:** Send waggle to queen, show it in `hive waggle list`

---

## Task 6: Queen GenServer

**Objective:** Implement the coordinator agent

**Implementation:**
- `Hive.Queen` GenServer with state: active jobs, bees, quests
- Handle messages: `:create_job`, `:assign_job`, `:job_complete`
- Subscribe to `waggle:queen` topic
- `hive queen` - starts interactive Queen session (spawns Claude)

**Test:** Queen starts, handles job creation message

**Demo:** `hive queen` starts Claude session with Queen context injected

---

## Task 7: Claude Runtime Integration

**Objective:** Spawn and monitor Claude processes

**Implementation:**
- `Hive.Runtime.Claude` module - spawn via Port
- Generate `.claude/settings.json` with hooks pointing to `hive` CLI
- Hooks: SessionStart → `hive prime`, Stop → `hive costs record`
- `hive prime` - outputs context to stdout for Claude to capture
- Monitor Port for exit, emit events

**Test:** Spawn Claude, verify hooks file created, prime outputs context

**Demo:** Spawn Claude process, show hooks file, demonstrate prime output

---

## Task 8: Bee Worker GenServer

**Objective:** Implement worker agents that execute jobs

**Implementation:**
- `Hive.Bee` GenServer - manages single Claude instance
- Create git worktree (cell) for isolation
- Inject job context via `hive prime`
- Track state: `:starting`, `:working`, `:complete`, `:failed`
- Report completion back to Queen via waggle

**Test:** Spawn bee, verify worktree created, job context injected

**Demo:** Queen creates job, bee spawns, show worktree and Claude working

---

## Task 9: Job & Quest Management

**Objective:** Create and track work units

**Implementation:**
- `Hive.Job` schema with: id, title, description, status, bee_id, quest_id
- `Hive.Quest` schema with: id, name, jobs (has_many)
- Queen creates jobs, assigns to bees
- `hive quest list` - show quests with progress
- `hive quest show <id>` - show quest details

**Test:** Create quest with jobs, assign jobs, track completion

**Demo:** Queen creates quest "Build auth", spawns bees, `hive quest list` shows progress

---

## Task 10: Transcript Watching & Cost Tracking

**Objective:** Monitor Claude transcripts for token usage

**Implementation:**
- `Hive.TranscriptWatcher` GenServer using `:fs` library
- Watch `~/.claude/projects/*/transcript.jsonl`
- Parse JSON lines for `usage` field
- Store costs in SQLite with bee_id, timestamp
- `hive costs` - show cost summary
- `hive costs --today` - today's costs

**Test:** Write mock transcript, verify costs recorded

**Demo:** Run bee, show `hive costs` updating with token usage

---

## Task 11: Cell (Worktree) Management

**Objective:** Manage git worktrees for bee isolation

**Implementation:**
- `Hive.Cell` module - create/cleanup worktrees
- Sparse checkout to exclude `.hive/` directory
- Track cells in SQLite with bee association
- Cleanup on bee completion/failure
- `hive cell list` - show active cells

**Test:** Create cell, verify sparse checkout, cleanup works

**Demo:** Spawn bee, show cell worktree, complete job, show cleanup

---

## Task 12: Doctor System (Health Checks)

**Objective:** Validate hive health and fix issues

**Implementation:**
- `Hive.Doctor` module with check functions
- Checks: git worktrees valid, SQLite consistent, orphan processes
- `hive doctor` - run all checks
- `hive doctor --fix` - auto-fix issues

**Test:** Create broken state, verify doctor detects and fixes

**Demo:** Run `hive doctor`, show check results, fix an issue

---

## Task 13: Quick Start Experience

**Objective:** Streamline developer onboarding

**Implementation:**
- `hive init` auto-detects if in git repo, offers to add as comb
- `hive queen` works immediately after init (no comb required for simple tasks)
- Add `--quick` flag: `hive init --quick` does init + queen in one command
- Helpful error messages with suggested commands

**Test:** Fresh directory, `hive init --quick` gets to Queen prompt

**Demo:** `hive init ~/test --quick` → immediately talking to Queen

---

## Task 14: Handoff System

**Objective:** Enable context-preserving session restarts

**Implementation:**
- `hive handoff` - serialize bee state, send waggle to self, restart
- Store handoff context in SQLite
- On restart, `hive prime` detects handoff marker, injects context
- Cleanup handoff marker after injection

**Test:** Bee handoff preserves job context across restart

**Demo:** Bee runs low on context, `hive handoff`, new session continues work

---

## Task 15: Web Dashboard (Phoenix LiveView)

**Objective:** Real-time monitoring UI

**Implementation:**
- Phoenix app with LiveView
- Pages: Hive overview, Comb details, Bee status, Quest progress
- Real-time updates via PubSub
- `hive dashboard` - starts web server

**Test:** Dashboard shows live bee status updates

**Demo:** Open dashboard, spawn bee, watch status update in real-time
