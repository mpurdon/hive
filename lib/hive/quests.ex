defmodule Hive.Quests do
  @moduledoc """
  Context module for quest lifecycle management.

  A quest is a high-level objective decomposed into jobs. Its status is
  derived from the collective state of its jobs via `compute_status/1`,
  a pure function that maps job statuses to a quest status.

  This is a pure context module: no process state, just data transformations
  against the database.
  """

  import Ecto.Query

  alias Hive.Repo
  alias Hive.Schema.{Job, Quest}

  # -- Public API --------------------------------------------------------------

  @doc """
  Creates a new quest.

  Required attrs: `name`.
  Optional: `comb_id`.

  Returns `{:ok, quest}` or `{:error, changeset}`.
  """
  @spec create(map()) :: {:ok, Quest.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Quest{}
    |> Quest.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists quests with optional status filter.

  ## Options

    * `:status` - filter by quest status
  """
  @spec list(keyword()) :: [Quest.t()]
  def list(opts \\ []) do
    Quest
    |> apply_filter(:status, Keyword.get(opts, :status))
    |> order_by([q], desc: q.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a quest by ID, preloading its jobs.

  Returns `{:ok, quest}` or `{:error, :not_found}`.
  """
  @spec get(String.t()) :: {:ok, Quest.t()} | {:error, :not_found}
  def get(quest_id) do
    case Repo.get(Quest, quest_id) |> maybe_preload() do
      nil -> {:error, :not_found}
      quest -> {:ok, quest}
    end
  end

  @doc """
  Computes a quest's status from its jobs' statuses.

  This is a pure function -- it takes a list of job status strings and
  returns the derived quest status. No database access.

  ## Rules

    * No jobs or all pending -> "pending"
    * All done -> "completed"
    * Any failed -> "failed"
    * Any running or assigned -> "active"
    * Otherwise -> "pending"
  """
  @spec compute_status([String.t()]) :: String.t()
  def compute_status([]), do: "pending"

  def compute_status(job_statuses) do
    cond do
      Enum.all?(job_statuses, &(&1 == "done")) ->
        "completed"

      Enum.any?(job_statuses, &(&1 == "failed")) ->
        "failed"

      Enum.any?(job_statuses, &(&1 in ["running", "assigned"])) ->
        "active"

      true ->
        "pending"
    end
  end

  @doc """
  Recomputes and persists a quest's status from its current jobs.

  Fetches job statuses from the database, runs `compute_status/1`,
  and updates the quest record.

  Returns `{:ok, quest}` or `{:error, reason}`.
  """
  @spec update_status!(String.t()) :: {:ok, Quest.t()} | {:error, term()}
  def update_status!(quest_id) do
    with {:ok, quest} <- get(quest_id) do
      job_statuses =
        quest.jobs
        |> Enum.map(& &1.status)

      new_status = compute_status(job_statuses)

      quest
      |> Quest.changeset(%{status: new_status})
      |> Repo.update()
    end
  end

  @doc """
  Adds a job to a quest.

  Merges the quest_id into the job attrs and delegates to `Hive.Jobs.create/1`.

  Returns `{:ok, job}` or `{:error, changeset}`.
  """
  @spec add_job(String.t(), map()) :: {:ok, Job.t()} | {:error, Ecto.Changeset.t()}
  def add_job(quest_id, job_attrs) do
    job_attrs
    |> Map.put(:quest_id, quest_id)
    |> Hive.Jobs.create()
  end

  # -- Private helpers ---------------------------------------------------------

  defp maybe_preload(nil), do: nil
  defp maybe_preload(quest), do: Repo.preload(quest, :jobs)

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, :status, value), do: where(query, [q], q.status == ^value)
end
