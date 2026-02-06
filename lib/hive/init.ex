defmodule Hive.Init do
  @moduledoc """
  Initializes a new Hive workspace at a given path.

  The initialization pipeline creates the directory structure, writes the
  default configuration, seeds the Queen's instructions, and bootstraps the
  SQLite database with all migrations applied.

  ## Directory structure

      <path>/
      +-- .hive/
          +-- config.toml
          +-- queen/
          |   +-- QUEEN.md
          +-- hive.db          (created when Repo starts)
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
  - `hive quest new "Feature name"` -- Create a new quest
  - `hive quest list` -- List all quests
  - `hive quest show <quest-id>` -- Show quest details with jobs
  - `hive jobs create --quest <quest-id> --title "Task name" --comb <comb-id>` -- Create a job
  - `hive jobs create --quest <quest-id> --title "Task name" --comb <comb-id> --description "Detailed instructions"` -- Create with description
  - `hive jobs list` -- List all jobs
  - `hive jobs show <job-id>` -- Show job details

  ### Bee Management
  - `hive bee spawn --job <job-id> --comb <comb-id>` -- Spawn a bee for a job
  - `hive bee spawn --job <job-id> --comb <comb-id> --name "custom-name"` -- Spawn with custom name
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

  1. Analyze the user's request
  2. Create a quest: `hive quest new "Feature name"`
  3. Create jobs for each piece of work: `hive jobs create --quest <id> --title "..." --comb <id>`
  4. Spawn bees for each job: `hive bee spawn --job <id> --comb <id>`
  5. Monitor: `hive bee list` and `hive waggle list --to queen`
  6. Report: "Quest complete: X/Y jobs done"

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
  seeds the Queen's instruction file, and runs database migrations.

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
         :ok <- init_database(hive_dir) do
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

  defp init_database(hive_dir) do
    db_path = Path.join(hive_dir, "hive.db")

    case Hive.Repo.start_link(database: db_path, pool_size: 1) do
      {:ok, _pid} ->
        Hive.Repo.ensure_migrated!()

      {:error, {:already_started, _pid}} ->
        Hive.Repo.ensure_migrated!()

      {:error, reason} ->
        {:error, {:database, reason}}
    end
  end
end
