defmodule Hive.Merge do
  @moduledoc """
  Handles merging bee worktree branches back into the main codebase.

  After a bee completes its job, the merge module applies the comb's
  configured merge strategy to integrate the bee's changes.

  ## Strategies

    * `"manual"` -- No auto-merge. Sends a waggle with instructions.
    * `"auto_merge"` -- Checks out the main branch and merges the bee branch.
    * `"pr_branch"` -- Keeps the branch intact for a PR workflow.
  """

  require Logger

  alias Hive.Store

  @doc """
  Merges a bee's worktree branch back according to the comb's merge strategy.

  Looks up the cell, finds the comb, reads the merge_strategy, and dispatches.
  Returns `{:ok, strategy_applied}` or `{:error, reason}`.
  """
  @spec merge_back(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def merge_back(cell_id, _opts \\ []) do
    with {:ok, cell} <- fetch_cell(cell_id),
         {:ok, comb} <- fetch_comb(cell.comb_id) do
      strategy = comb.merge_strategy || "manual"
      apply_strategy(strategy, cell, comb)
    end
  end

  @doc """
  Merges all completed bee branches for a quest into a single quest branch.

  Creates `quest/<quest-name>` off the main branch, then merges each bee's
  branch into it sequentially. Returns `{:ok, quest_branch}` with the branch
  name, or `{:error, reason}` if any merge fails.
  """
  @spec merge_quest(String.t()) :: {:ok, String.t()} | {:error, term()}
  def merge_quest(quest_id) do
    with {:ok, quest} <- Hive.Quests.get(quest_id),
         cells <- cells_for_quest(quest),
         true <- cells != [] || {:error, :no_cells},
         {:ok, comb} <- fetch_comb_for_cells(cells),
         {:ok, main_branch} <- detect_main_branch(comb.path),
         quest_branch = "quest/#{quest.name}",
         :ok <- create_quest_branch(comb.path, quest_branch, main_branch) do
      merge_cells_into_quest_branch(comb.path, quest_branch, cells)
    end
  end

  # -- Private: strategy dispatch ----------------------------------------------

  defp apply_strategy("manual", cell, _comb) do
    Logger.info("Merge strategy: manual. Branch #{cell.branch} ready for manual merge.")
    {:ok, "manual"}
  end

  defp apply_strategy("auto_merge", cell, comb) do
    repo_path = comb.path

    with {:ok, main_branch} <- detect_main_branch(repo_path),
         :ok <- Hive.Git.checkout(repo_path, main_branch),
         :ok <- Hive.Git.merge(repo_path, cell.branch, no_ff: true) do
      Logger.info("Auto-merged #{cell.branch} into #{main_branch}")
      {:ok, "auto_merge"}
    else
      {:error, reason} ->
        Logger.warning("Auto-merge failed for #{cell.branch}: #{inspect(reason)}")
        # Fall back to manual on conflict
        {:error, {:merge_conflict, reason}}
    end
  end

  defp apply_strategy("pr_branch", cell, comb) do
    Logger.info("Branch #{cell.branch} ready for PR.")
    maybe_create_github_pr(comb, cell)
    {:ok, "pr_branch"}
  end

  defp apply_strategy(unknown, _cell, _comb) do
    {:error, {:unknown_strategy, unknown}}
  end

  # -- Private: data fetching --------------------------------------------------

  defp fetch_cell(cell_id) do
    case Store.get(:cells, cell_id) do
      nil -> {:error, :cell_not_found}
      cell -> {:ok, cell}
    end
  end

  defp fetch_comb(comb_id) do
    case Store.get(:combs, comb_id) do
      nil -> {:error, :comb_not_found}
      comb -> {:ok, comb}
    end
  end

  defp maybe_create_github_pr(comb, cell) do
    if Map.get(comb, :github_owner) && Map.get(comb, :github_repo) do
      # Look up the job for this cell's bee
      case Store.find_one(:jobs, fn j -> j.bee_id == cell.bee_id end) do
        nil ->
          Logger.debug("No job found for bee #{cell.bee_id}, skipping GitHub PR")

        job ->
          case Hive.GitHub.create_pr(comb, cell, job) do
            {:ok, url} ->
              Logger.info("GitHub PR created: #{url}")
              Hive.Waggle.send("system", "queen", "pr_created", "PR: #{url}")

            {:error, reason} ->
              Logger.warning("GitHub PR creation failed: #{inspect(reason)}")
          end
      end
    end
  rescue
    e -> Logger.warning("GitHub PR error: #{Exception.message(e)}")
  end

  defp detect_main_branch(repo_path) do
    # Try common main branch names
    cond do
      Hive.Git.branch_exists?(repo_path, "main") -> {:ok, "main"}
      Hive.Git.branch_exists?(repo_path, "master") -> {:ok, "master"}
      true -> Hive.Git.current_branch(repo_path)
    end
  end

  # -- Private: quest merge helpers -------------------------------------------

  defp cells_for_quest(quest) do
    bee_ids =
      quest.jobs
      |> Enum.map(& &1.bee_id)
      |> Enum.reject(&is_nil/1)

    Store.filter(:cells, fn c ->
      c.bee_id in bee_ids and c.status == "active"
    end)
  end

  defp fetch_comb_for_cells([cell | _]) do
    fetch_comb(cell.comb_id)
  end

  defp create_quest_branch(repo_path, quest_branch, main_branch) do
    if Hive.Git.branch_exists?(repo_path, quest_branch) do
      # Branch already exists — check it out
      Hive.Git.checkout(repo_path, quest_branch)
    else
      Hive.Git.branch_create(repo_path, quest_branch, main_branch)
    end
  end

  defp merge_cells_into_quest_branch(repo_path, quest_branch, cells) do
    results =
      Enum.map(cells, fn cell ->
        case Hive.Git.merge(repo_path, cell.branch, no_ff: true) do
          :ok ->
            Logger.info("Merged #{cell.branch} into #{quest_branch}")
            {:ok, cell.branch}

          {:error, reason} ->
            Logger.warning("Failed to merge #{cell.branch}: #{inspect(reason)}")
            # Abort the failed merge so subsequent merges can proceed
            System.cmd("git", ["merge", "--abort"], cd: repo_path, stderr_to_stdout: true)
            {:error, cell.branch, reason}
        end
      end)

    failures = Enum.filter(results, &match?({:error, _, _}, &1))

    if failures == [] do
      Logger.info("All bee branches merged into #{quest_branch}")
      {:ok, quest_branch}
    else
      failed_branches = Enum.map(failures, fn {:error, branch, _} -> branch end)
      {:error, {:merge_conflicts, quest_branch, failed_branches}}
    end
  end
end
