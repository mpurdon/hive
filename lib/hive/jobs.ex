defmodule Hive.Jobs do
  @moduledoc """
  Context module for job lifecycle management.

  A job is a unit of work assigned to a bee within a quest. This module
  enforces valid status transitions -- the state machine that governs how
  a job moves from pending through to done or failed.

  Status transitions:

      pending --> assigned --> running --> done
                                     \\--> failed
      pending --> blocked --> pending (unblock)
      running --> blocked

  This is a pure context module: no process state, just data transformations
  against the database.
  """

  import Ecto.Query

  alias Hive.Repo
  alias Hive.Schema.{Job, JobDependency}

  # -- Valid transitions -------------------------------------------------------

  @transitions %{
    {"pending", :assign} => "assigned",
    {"assigned", :start} => "running",
    {"running", :complete} => "done",
    {"running", :fail} => "failed",
    {"failed", :reset} => "pending",
    {"pending", :block} => "blocked",
    {"running", :block} => "blocked",
    {"blocked", :unblock} => "pending"
  }

  # -- Public API --------------------------------------------------------------

  @doc """
  Creates a new job.

  Required attrs: `title`, `quest_id`, `comb_id`.
  Optional: `description`.

  Returns `{:ok, job}` or `{:error, changeset}`.
  """
  @spec create(map()) :: {:ok, Job.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Job{}
    |> Job.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Assigns a job to a bee.

  Transitions: pending -> assigned.
  """
  @spec assign(String.t(), String.t()) :: {:ok, Job.t()} | {:error, atom() | Ecto.Changeset.t()}
  def assign(job_id, bee_id) do
    with {:ok, job} <- get(job_id),
         {:ok, next_status} <- validate_transition(job.status, :assign) do
      job
      |> Job.changeset(%{status: next_status, bee_id: bee_id})
      |> Repo.update()
    end
  end

  @doc """
  Starts a job. Transitions: assigned -> running.
  """
  @spec start(String.t()) :: {:ok, Job.t()} | {:error, atom() | Ecto.Changeset.t()}
  def start(job_id) do
    transition(job_id, :start)
  end

  @doc """
  Completes a job. Transitions: running -> done.
  """
  @spec complete(String.t()) :: {:ok, Job.t()} | {:error, atom() | Ecto.Changeset.t()}
  def complete(job_id) do
    transition(job_id, :complete)
  end

  @doc """
  Fails a job. Transitions: running -> failed.
  """
  @spec fail(String.t()) :: {:ok, Job.t()} | {:error, atom() | Ecto.Changeset.t()}
  def fail(job_id) do
    transition(job_id, :fail)
  end

  @doc """
  Blocks a job. Transitions: pending | running -> blocked.
  """
  @spec block(String.t()) :: {:ok, Job.t()} | {:error, atom() | Ecto.Changeset.t()}
  def block(job_id) do
    transition(job_id, :block)
  end

  @doc """
  Unblocks a job. Transitions: blocked -> pending.
  """
  @spec unblock(String.t()) :: {:ok, Job.t()} | {:error, atom() | Ecto.Changeset.t()}
  def unblock(job_id) do
    transition(job_id, :unblock)
  end

  @doc """
  Resets a failed job back to pending so it can be retried.

  Transitions: failed -> pending. Also clears the bee_id assignment
  so the job can be assigned to a fresh bee.
  """
  @spec reset(String.t()) :: {:ok, Job.t()} | {:error, atom() | Ecto.Changeset.t()}
  def reset(job_id) do
    with {:ok, job} <- get(job_id),
         {:ok, next_status} <- validate_transition(job.status, :reset) do
      job
      |> Job.changeset(%{status: next_status, bee_id: nil})
      |> Repo.update()
    end
  end

  @doc """
  Lists jobs with optional filters.

  ## Options

    * `:quest_id` - filter by quest
    * `:status` - filter by status
    * `:bee_id` - filter by assigned bee
  """
  @spec list(keyword()) :: [Job.t()]
  def list(opts \\ []) do
    Job
    |> apply_filter(:quest_id, Keyword.get(opts, :quest_id))
    |> apply_filter(:status, Keyword.get(opts, :status))
    |> apply_filter(:bee_id, Keyword.get(opts, :bee_id))
    |> order_by([j], desc: j.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a job by ID.

  Returns `{:ok, job}` or `{:error, :not_found}`.
  """
  @spec get(String.t()) :: {:ok, Job.t()} | {:error, :not_found}
  def get(job_id) do
    case Repo.get(Job, job_id) do
      nil -> {:error, :not_found}
      job -> {:ok, job}
    end
  end

  # -- Private helpers ---------------------------------------------------------

  defp transition(job_id, action) do
    with {:ok, job} <- get(job_id),
         {:ok, next_status} <- validate_transition(job.status, action) do
      job
      |> Job.changeset(%{status: next_status})
      |> Repo.update()
    end
  end

  defp validate_transition(current_status, action) do
    case Map.get(@transitions, {current_status, action}) do
      nil -> {:error, :invalid_transition}
      next -> {:ok, next}
    end
  end

  # -- Dependency management ---------------------------------------------------

  @doc """
  Adds a dependency: `job_id` depends on `depends_on_id`.

  Validates no self-dependency and no cycles (BFS).
  Returns `{:ok, dep}` or `{:error, reason}`.
  """
  @spec add_dependency(String.t(), String.t()) ::
          {:ok, JobDependency.t()} | {:error, term()}
  def add_dependency(job_id, depends_on_id) do
    cond do
      job_id == depends_on_id ->
        {:error, :self_dependency}

      has_cycle?(job_id, depends_on_id) ->
        {:error, :cycle_detected}

      true ->
        %JobDependency{}
        |> JobDependency.changeset(%{job_id: job_id, depends_on_id: depends_on_id})
        |> Repo.insert()
    end
  end

  @doc "Removes a dependency between two jobs."
  @spec remove_dependency(String.t(), String.t()) :: :ok | {:error, :not_found}
  def remove_dependency(job_id, depends_on_id) do
    case Repo.one(
           from(d in JobDependency,
             where: d.job_id == ^job_id and d.depends_on_id == ^depends_on_id
           )
         ) do
      nil -> {:error, :not_found}
      dep -> Repo.delete(dep) |> then(fn {:ok, _} -> :ok end)
    end
  end

  @doc "Lists jobs that `job_id` depends on."
  @spec dependencies(String.t()) :: [Job.t()]
  def dependencies(job_id) do
    from(j in Job,
      join: d in JobDependency,
      on: d.depends_on_id == j.id,
      where: d.job_id == ^job_id
    )
    |> Repo.all()
  end

  @doc "Lists jobs that depend on `job_id`."
  @spec dependents(String.t()) :: [Job.t()]
  def dependents(job_id) do
    from(j in Job,
      join: d in JobDependency,
      on: d.job_id == j.id,
      where: d.depends_on_id == ^job_id
    )
    |> Repo.all()
  end

  @doc "Returns true if all dependencies of `job_id` are done."
  @spec ready?(String.t()) :: boolean()
  def ready?(job_id) do
    not_done_count =
      from(d in JobDependency,
        join: j in Job,
        on: j.id == d.depends_on_id,
        where: d.job_id == ^job_id and j.status != "done",
        select: count(d.id)
      )
      |> Repo.one()

    not_done_count == 0
  end

  @doc """
  After a job completes, transitions blocked dependents to pending
  if all their dependencies are now done.
  """
  @spec unblock_dependents(String.t()) :: :ok
  def unblock_dependents(job_id) do
    dependent_ids =
      from(d in JobDependency,
        where: d.depends_on_id == ^job_id,
        select: d.job_id
      )
      |> Repo.all()

    Enum.each(dependent_ids, fn dep_job_id ->
      if ready?(dep_job_id) do
        case get(dep_job_id) do
          {:ok, %{status: "blocked"}} -> unblock(dep_job_id)
          _ -> :ok
        end
      end
    end)

    :ok
  end

  # -- Private helpers ---------------------------------------------------------

  # BFS cycle detection: adding depends_on_id as a dependency of job_id
  # would create a cycle if job_id is reachable from depends_on_id.
  defp has_cycle?(job_id, depends_on_id) do
    bfs_reachable?(depends_on_id, job_id, MapSet.new())
  end

  defp bfs_reachable?(from_id, target_id, visited) do
    if from_id == target_id do
      true
    else
      if MapSet.member?(visited, from_id) do
        false
      else
        visited = MapSet.put(visited, from_id)

        deps =
          from(d in JobDependency,
            where: d.job_id == ^from_id,
            select: d.depends_on_id
          )
          |> Repo.all()

        Enum.any?(deps, fn dep_id -> bfs_reachable?(dep_id, target_id, visited) end)
      end
    end
  end

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, :quest_id, value), do: where(query, [j], j.quest_id == ^value)
  defp apply_filter(query, :status, value), do: where(query, [j], j.status == ^value)
  defp apply_filter(query, :bee_id, value), do: where(query, [j], j.bee_id == ^value)
end
