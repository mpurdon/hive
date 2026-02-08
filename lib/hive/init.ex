defmodule Hive.Init do
  @moduledoc """
  Initializes a new Hive workspace at a given path.

  The initialization pipeline creates the directory structure, writes the
  default configuration, seeds the Queen's instructions, and bootstraps the
  CubDB store.

  ## Directory structure

      <path>/
      +-- .hive/
          +-- config.toml
          +-- queen/
          |   +-- QUEEN.md
          +-- store/             (CubDB data directory)
  """

  alias Hive.Config

  @queen_instructions """
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
  - Spawn bees to execute jobs
  - Monitor bee progress
  - Report quest status to the user

  ## Available Commands

  ### Quest & Job Management
  - `hive quest new "Feature name"` -- Create a new quest (uses current comb)
  - `hive quest new "Feature name" -d "Detailed goal description"` -- Create with description
  - `hive quest new "Feature name" -c <comb-id>` -- Create for a specific comb
  - `hive quest list` -- List all quests
  - `hive quest show <quest-id>` -- Show quest details with jobs
  - `hive jobs create --quest <quest-id> --title "Task name"` -- Create a job (uses current comb)
  - `hive jobs create --quest <quest-id> --title "Task name" --comb <comb-id>` -- Create for specific comb
  - `hive jobs create --quest <quest-id> --title "Task name" --description "Detailed instructions"` -- Create with description
  - `hive jobs list` -- List all jobs
  - `hive jobs show <job-id>` -- Show job details
  - `hive jobs deps add --job <job-id> --depends-on <other-job-id>` -- Add dependency between jobs
  - `hive jobs deps list --job <job-id>` -- List job dependencies

  ### Bee Management
  - `hive bee spawn --job <job-id>` -- Spawn a bee for a job (uses current comb)
  - `hive bee spawn --job <job-id> --comb <comb-id>` -- Spawn for specific comb
  - `hive bee spawn --job <job-id> --name "custom-name"` -- Spawn with custom name
  - `hive bee list` -- List all bees and their status
  - `hive bee stop --id <bee-id>` -- Stop a running bee

  ### Communication
  - `hive waggle send --from queen --to <bee-id> --subject "guidance" --body "message"` -- Send a message
  - `hive waggle list --to queen` -- Check messages to you
  - `hive waggle show <waggle-id>` -- Read a specific message

  ### Monitoring
  - `hive costs summary` -- View total costs and token usage
  - `hive costs record --bee <bee-id> --input <n> --output <n>` -- Manually record costs
  - `hive cell list` -- List active worktree cells

  ### Comb Management
  - `hive comb add <path> [--name "name"] [--merge-strategy manual|auto_merge|pr_branch]` -- Register a codebase
  - `hive comb list` -- List registered combs
  - `hive comb use <name>` -- Set the current working comb

  ## Merge Strategies
  When a bee completes its job, its changes can be merged using the comb's strategy:
  - **manual** (default): Branch is left for human review
  - **auto_merge**: Automatically merges the bee's branch into main
  - **pr_branch**: Keeps the branch ready for a pull request

  ## Agent Profiles
  Bees automatically check for expert agent files in the comb's `.claude/agents/` directory.
  If a matching agent doesn't exist, the bee generates one based on the job's technology.
  This ensures each bee works with domain-specific expertise.

  ## Workflow

  ### Phase 1: Check for Pending Quests
  At session start, review the "Pending Quests" section in the hive state below.
  If a pending quest has a description, use it as your goal and begin planning.
  If there are no pending quests, wait for the user to provide a request.

  ### Phase 2: Clarify (if needed)
  If the quest description is vague or missing critical details, ask the user
  clarifying questions BEFORE creating any jobs. Examples of what to clarify:
  - Which area of the codebase to focus on
  - Specific requirements or constraints
  - Expected behavior or acceptance criteria

  If the quest has no description, ask the user what the goal is.
  If the goal is clear and specific, skip straight to planning.

  ### Phase 3: Plan and Decompose
  Break the quest goal into concrete, independent jobs:
  1. Each job should be a self-contained unit of work for one bee
  2. Give each job a clear title and detailed description
  3. Set up dependencies between jobs that must run in order
  4. Jobs that can run in parallel should have no dependency between them

  ### Phase 4: Execute
  1. Create jobs: `hive jobs create --quest <id> --title "..." --description "..."`
  2. Add dependencies: `hive jobs deps add --job <id> --depends-on <id>`
  3. Spawn bees for all ready (unblocked) jobs: `hive bee spawn --job <id>`
  4. Do NOT exceed the max_bees limit from the config

  ### Phase 5: Monitor and Report
  1. Check bee status: `hive bee list`
  2. Read messages: `hive waggle list --to queen`
  3. When a bee completes, spawn bees for newly unblocked jobs
  4. When all jobs for a quest complete, report the result to the user
  5. If a bee reports being blocked, help unblock it or reassign the work

  NEVER write the code yourself. ALWAYS delegate to bees.
  """

  @doc """
  Returns the Queen's instruction text.

  Used by `Hive.Doctor` to regenerate `QUEEN.md` when it is missing.
  """
  @spec queen_instructions() :: String.t()
  def queen_instructions, do: @queen_instructions

  @doc """
  Initializes a Hive workspace at `path`.

  Creates the `.hive/` directory structure, writes the default config,
  seeds the Queen's instruction file, and starts the CubDB store.

  ## Options

    * `:force` - when `true`, reinitializes even if `.hive/` already exists.
      Defaults to `false`.

  Returns `{:ok, hive_path}` on success, `{:error, reason}` on failure.
  """
  @spec init(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def init(path, opts \\ []) do
    force? = Keyword.get(opts, :force, false)

    expanded = Path.expand(path)
    hive_dir = Path.join(expanded, ".hive")

    with :ok <- validate_path(hive_dir, force?),
         :ok <- create_directories(hive_dir),
         :ok <- write_config(hive_dir),
         :ok <- write_queen_instructions(hive_dir),
         :ok <- init_store(hive_dir) do
      {:ok, expanded}
    end
  end

  # -- Pipeline steps --------------------------------------------------------

  defp validate_path(hive_dir, false) do
    if File.dir?(hive_dir) do
      {:error, :already_initialized}
    else
      :ok
    end
  end

  defp validate_path(_hive_dir, true), do: :ok

  defp create_directories(hive_dir) do
    queen_dir = Path.join(hive_dir, "queen")

    with :ok <- File.mkdir_p(queen_dir) do
      :ok
    end
  end

  defp write_config(hive_dir) do
    config_path = Path.join(hive_dir, "config.toml")
    Config.write_config(config_path)
  end

  defp write_queen_instructions(hive_dir) do
    queen_path = Path.join([hive_dir, "queen", "QUEEN.md"])
    File.write(queen_path, @queen_instructions)
  end

  defp init_store(hive_dir) do
    store_dir = Path.join(hive_dir, "store")
    File.mkdir_p(store_dir)

    case Hive.Store.start_link(data_dir: store_dir) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, {:store, reason}}
    end
  end
end
