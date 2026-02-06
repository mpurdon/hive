defmodule Hive.Conflict do
  @moduledoc """
  Detects merge conflicts between a bee's worktree branch and the main branch.

  Uses `git diff` to detect potential conflicts before merging.
  Pure context module -- no process state.
  """

  require Logger

  alias Hive.Repo
  alias Hive.Schema.Cell

  @doc """
  Checks a cell's branch for conflicts against the main branch.

  Returns `{:ok, :clean}` or `{:error, :conflicts, file_list}`.
  """
  @spec check(String.t()) :: {:ok, :clean} | {:error, :conflicts, [String.t()]} | {:error, term()}
  def check(cell_id) do
    with {:ok, cell} <- fetch_cell(cell_id),
         {:ok, comb} <- fetch_comb(cell.comb_id),
         {:ok, main_branch} <- detect_main_branch(comb.path) do
      check_conflicts(comb.path, cell.branch, main_branch)
    end
  end

  @doc """
  Checks all active cells for conflicts.

  Returns a list of `{:ok, cell_id, :clean}` or `{:error, cell_id, :conflicts, files}`.
  """
  @spec check_all_active() :: [tuple()]
  def check_all_active do
    import Ecto.Query

    from(c in Cell, where: c.status == "active")
    |> Repo.all()
    |> Enum.map(fn cell ->
      case check(cell.id) do
        {:ok, :clean} -> {:ok, cell.id, :clean}
        {:error, :conflicts, files} -> {:error, cell.id, :conflicts, files}
        {:error, _reason} -> {:ok, cell.id, :clean}
      end
    end)
  rescue
    _ -> []
  end

  # -- Private -----------------------------------------------------------------

  defp check_conflicts(repo_path, branch, main_branch) do
    # Use git diff to find files that differ and may conflict
    case System.cmd("git", ["diff", "--name-only", "#{main_branch}...#{branch}"],
           cd: repo_path, stderr_to_stdout: true) do
      {output, 0} ->
        changed_files = output |> String.split("\n", trim: true)

        if changed_files == [] do
          {:ok, :clean}
        else
          # Check if main has also modified these files (potential conflict)
          check_overlapping_changes(repo_path, branch, main_branch, changed_files)
        end

      {_output, _code} ->
        # Can't determine, assume clean
        {:ok, :clean}
    end
  rescue
    _ -> {:ok, :clean}
  end

  defp check_overlapping_changes(repo_path, _branch, main_branch, branch_files) do
    # Find files changed on main since the branch point
    merge_base = get_merge_base(repo_path, main_branch)

    case merge_base do
      {:ok, base} ->
        case System.cmd("git", ["diff", "--name-only", "#{base}..#{main_branch}"],
               cd: repo_path, stderr_to_stdout: true) do
          {output, 0} ->
            main_files = output |> String.split("\n", trim: true) |> MapSet.new()
            branch_set = MapSet.new(branch_files)
            conflicts = MapSet.intersection(main_files, branch_set) |> MapSet.to_list()

            if conflicts == [] do
              {:ok, :clean}
            else
              {:error, :conflicts, conflicts}
            end

          _ ->
            {:ok, :clean}
        end

      {:error, _} ->
        {:ok, :clean}
    end
  end

  defp get_merge_base(repo_path, main_branch) do
    case System.cmd("git", ["merge-base", "HEAD", main_branch],
           cd: repo_path, stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  defp fetch_cell(cell_id) do
    case Repo.get(Cell, cell_id) do
      nil -> {:error, :cell_not_found}
      cell -> {:ok, cell}
    end
  end

  defp fetch_comb(comb_id) do
    case Repo.get(Hive.Schema.Comb, comb_id) do
      nil -> {:error, :comb_not_found}
      comb -> {:ok, comb}
    end
  end

  defp detect_main_branch(repo_path) do
    cond do
      Hive.Git.branch_exists?(repo_path, "main") -> {:ok, "main"}
      Hive.Git.branch_exists?(repo_path, "master") -> {:ok, "master"}
      true -> Hive.Git.current_branch(repo_path)
    end
  rescue
    _ -> {:ok, "main"}
  end
end
