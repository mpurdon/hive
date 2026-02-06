defmodule Hive.Cell do
  @moduledoc """
  Context module for managing cells -- git worktrees assigned to bees.

  A cell provides an isolated working directory for a bee by creating a git
  worktree from a comb's repository. This keeps each bee's changes on a
  separate branch without affecting the main worktree.

  This is a pure context module: no process state, just data transformations
  that coordinate git operations with database records.
  """

  import Ecto.Query

  alias Hive.Git
  alias Hive.Repo
  alias Hive.Schema.Cell, as: CellSchema

  # -- Public API ------------------------------------------------------------

  @doc """
  Creates a new cell (git worktree) for a bee within a comb.

  1. Generates branch name: `bee/<bee_id>`
  2. Computes worktree path: `<comb.path>/bees/<bee_id>/`
  3. Runs `git worktree add` to create the worktree
  4. Inserts a Cell record in the database

  Returns `{:ok, cell}` or `{:error, reason}`.
  """
  @spec create(String.t(), String.t(), keyword()) :: {:ok, CellSchema.t()} | {:error, term()}
  def create(comb_id, bee_id, opts \\ []) do
    branch = Keyword.get(opts, :branch, "bee/#{bee_id}")
    hive_root = Keyword.get(opts, :hive_root)

    with {:ok, comb} <- Hive.Comb.get(comb_id),
         :ok <- validate_comb_path(comb),
         worktree_path = build_worktree_path(comb.path, bee_id),
         {:ok, _path} <- Git.worktree_add(comb.path, worktree_path, branch),
         :ok <- maybe_generate_settings(bee_id, hive_root, worktree_path),
         {:ok, cell} <- insert_cell(comb_id, bee_id, worktree_path, branch) do
      {:ok, cell}
    end
  end

  @doc """
  Removes a cell's worktree and marks the record as removed.

  1. Runs `git worktree remove` to clean up the worktree directory
  2. Deletes the `bee/<bee_id>` branch
  3. Updates the cell record: status "removed", removed_at set to now

  Pass `force: true` to force-remove dirty worktrees.

  Returns `{:ok, cell}` or `{:error, reason}`.
  """
  @spec remove(String.t(), keyword()) :: {:ok, CellSchema.t()} | {:error, term()}
  def remove(cell_id, opts \\ []) do
    with {:ok, cell} <- get(cell_id),
         {:ok, comb} <- Hive.Comb.get(cell.comb_id),
         :ok <- remove_worktree(comb.path, cell.worktree_path, opts),
         :ok <- delete_branch(comb.path, cell.branch),
         {:ok, updated} <- mark_removed(cell) do
      {:ok, updated}
    end
  end

  @doc """
  Lists cells with optional filters.

  ## Options

    * `:comb_id` - filter by comb
    * `:status` - filter by status (e.g., "active", "removed")

  Returns a list of cell structs.
  """
  @spec list(keyword()) :: [CellSchema.t()]
  def list(opts \\ []) do
    CellSchema
    |> apply_filter(:comb_id, Keyword.get(opts, :comb_id))
    |> apply_filter(:status, Keyword.get(opts, :status))
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a cell by ID.

  Returns `{:ok, cell}` or `{:error, :not_found}`.
  """
  @spec get(String.t()) :: {:ok, CellSchema.t()} | {:error, :not_found}
  def get(cell_id) do
    case Repo.get(CellSchema, cell_id) do
      nil -> {:error, :not_found}
      cell -> {:ok, cell}
    end
  end

  @doc """
  Finds cells whose associated bee no longer exists or has stopped.

  Returns orphaned cells that are still marked "active" but have no
  corresponding active bee record. Useful for periodic cleanup.
  """
  @spec cleanup_orphans() :: {:ok, non_neg_integer()}
  def cleanup_orphans do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    orphan_query =
      from(c in CellSchema,
        left_join: b in Hive.Schema.Bee,
        on: c.bee_id == b.id,
        where: c.status == "active",
        where: is_nil(b.id) or b.status in ["stopped", "crashed"]
      )

    {count, _} =
      Repo.update_all(orphan_query,
        set: [status: "removed", removed_at: now]
      )

    {:ok, count}
  end

  # -- Private helpers -------------------------------------------------------

  defp validate_comb_path(%{path: nil}), do: {:error, :comb_has_no_path}
  defp validate_comb_path(%{path: path}) when is_binary(path), do: :ok

  defp build_worktree_path(comb_path, bee_id) do
    Path.join([comb_path, "bees", bee_id])
  end

  defp insert_cell(comb_id, bee_id, worktree_path, branch) do
    %CellSchema{}
    |> CellSchema.changeset(%{
      comb_id: comb_id,
      bee_id: bee_id,
      worktree_path: worktree_path,
      branch: branch
    })
    |> Repo.insert()
  end

  defp remove_worktree(comb_path, worktree_path, opts) do
    case Git.worktree_remove(comb_path, worktree_path, opts) do
      :ok -> :ok
      {:error, _reason} = err -> err
    end
  end

  defp delete_branch(comb_path, branch) do
    case Git.branch_delete(comb_path, branch) do
      :ok -> :ok
      # Branch may already be gone; treat as success
      {:error, _reason} -> :ok
    end
  end

  defp mark_removed(cell) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    cell
    |> Ecto.Changeset.change(status: "removed", removed_at: now)
    |> Repo.update()
  end

  defp maybe_generate_settings(_bee_id, nil, _worktree_path), do: :ok

  defp maybe_generate_settings(bee_id, hive_root, worktree_path) do
    Hive.Runtime.Settings.generate(bee_id, hive_root, worktree_path)
  end

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, :comb_id, value), do: where(query, [c], c.comb_id == ^value)
  defp apply_filter(query, :status, value), do: where(query, [c], c.status == ^value)
end
