defmodule Hive.Bees do
  @moduledoc """
  Context module for managing bee agents.

  Provides the public API for spawning, listing, and stopping bees. This
  module coordinates between the Bee.Worker GenServer (runtime lifecycle),
  the Schema.Bee (database persistence), and the CombSupervisor (process
  supervision).

  This is a context module: thin orchestration layer over database records
  and supervised processes.
  """

  import Ecto.Query

  alias Hive.Repo
  alias Hive.Schema.Bee, as: BeeSchema

  # -- Public API --------------------------------------------------------------

  @doc """
  Spawns a new bee to work on a job.

  1. Creates a bee record in the database
  2. Assigns the job to the bee
  3. Starts a Bee.Worker under CombSupervisor

  ## Options

    * `:name` - human-friendly name (default: auto-generated)
    * `:prompt` - explicit prompt (overrides job description)
    * `:claude_executable` - path to executable (for testing)

  Returns `{:ok, bee}` or `{:error, reason}`.
  """
  @spec spawn(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, BeeSchema.t()} | {:error, term()}
  def spawn(job_id, comb_id, hive_root, opts \\ []) do
    name = Keyword.get(opts, :name, generate_bee_name())

    with :ok <- check_job_ready(job_id),
         {:ok, bee} <- create_bee_record(name, job_id),
         :ok <- assign_job(job_id, bee.id),
         {:ok, _pid} <- start_worker(bee.id, job_id, comb_id, hive_root, opts) do
      {:ok, bee}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists bees with optional filters.

  ## Options

    * `:status` - filter by status (e.g., "working", "stopped")
  """
  @spec list(keyword()) :: [BeeSchema.t()]
  def list(opts \\ []) do
    BeeSchema
    |> apply_filter(:status, Keyword.get(opts, :status))
    |> order_by([b], desc: b.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a bee by ID.

  Returns `{:ok, bee}` or `{:error, :not_found}`.
  """
  @spec get(String.t()) :: {:ok, BeeSchema.t()} | {:error, :not_found}
  def get(bee_id) do
    case Repo.get(BeeSchema, bee_id) do
      nil -> {:error, :not_found}
      bee -> {:ok, bee}
    end
  end

  @doc """
  Gracefully stops a running bee worker.

  Returns `:ok` or `{:error, :not_found}` if the worker process is not running.
  """
  @spec stop(String.t()) :: :ok | {:error, :not_found}
  def stop(bee_id) do
    Hive.Bee.Worker.stop(bee_id)
  end

  # -- Private helpers ---------------------------------------------------------

  defp check_job_ready(job_id) do
    if Hive.Jobs.ready?(job_id), do: :ok, else: {:error, :blocked}
  end

  defp create_bee_record(name, job_id) do
    %BeeSchema{}
    |> BeeSchema.changeset(%{name: name, status: "starting", job_id: job_id})
    |> Repo.insert()
  end

  defp assign_job(job_id, bee_id) do
    case Hive.Jobs.assign(job_id, bee_id) do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_worker(bee_id, job_id, comb_id, hive_root, opts) do
    child_opts =
      [
        bee_id: bee_id,
        job_id: job_id,
        comb_id: comb_id,
        hive_root: hive_root
      ] ++ Keyword.take(opts, [:prompt, :claude_executable])

    Hive.CombSupervisor.start_child({Hive.Bee.Worker, child_opts})
  end

  defp generate_bee_name do
    adjectives = ~w(swift bright keen bold calm sharp)
    nouns = ~w(scout worker forager builder dancer)

    adj = Enum.random(adjectives)
    noun = Enum.random(nouns)
    suffix = :crypto.strong_rand_bytes(2) |> Base.encode16(case: :lower)

    "#{adj}-#{noun}-#{suffix}"
  end

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, :status, value), do: where(query, [b], b.status == ^value)
end
