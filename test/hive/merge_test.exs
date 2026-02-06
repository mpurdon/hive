defmodule Hive.MergeTest do
  use ExUnit.Case, async: false

  alias Hive.Merge
  alias Hive.Repo
  alias Hive.Schema.{Bee, Cell, Comb, Quest}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    {:ok, comb} =
      %Comb{}
      |> Comb.changeset(%{name: "merge-comb-#{:erlang.unique_integer([:positive])}", merge_strategy: "manual"})
      |> Repo.insert()

    {:ok, quest} =
      %Quest{}
      |> Quest.changeset(%{name: "merge-quest-#{:erlang.unique_integer([:positive])}"})
      |> Repo.insert()

    {:ok, job} =
      Hive.Jobs.create(%{
        title: "Merge test task",
        description: "Test the merge strategies",
        quest_id: quest.id,
        comb_id: comb.id
      })

    {:ok, bee} =
      %Bee{}
      |> Bee.changeset(%{name: "merge-bee", status: "working", job_id: job.id})
      |> Repo.insert()

    {:ok, cell} =
      %Cell{}
      |> Cell.changeset(%{
        bee_id: bee.id,
        comb_id: comb.id,
        worktree_path: "/tmp/merge-worktree",
        branch: "bee/#{bee.id}",
        status: "active"
      })
      |> Repo.insert()

    %{comb: comb, quest: quest, job: job, bee: bee, cell: cell}
  end

  describe "merge_back/1 with manual strategy" do
    test "returns {:ok, \"manual\"} for a comb with manual merge_strategy", ctx do
      assert {:ok, "manual"} = Merge.merge_back(ctx.cell.id)
    end
  end

  describe "merge_back/1 with pr_branch strategy" do
    test "returns {:ok, \"pr_branch\"} for a comb with pr_branch merge_strategy", ctx do
      # Create a comb with pr_branch strategy
      {:ok, pr_comb} =
        %Comb{}
        |> Comb.changeset(%{
          name: "pr-comb-#{:erlang.unique_integer([:positive])}",
          merge_strategy: "pr_branch"
        })
        |> Repo.insert()

      # Create a cell pointing to this comb
      {:ok, pr_cell} =
        %Cell{}
        |> Cell.changeset(%{
          bee_id: ctx.bee.id,
          comb_id: pr_comb.id,
          worktree_path: "/tmp/pr-worktree",
          branch: "bee/pr-test",
          status: "active"
        })
        |> Repo.insert()

      assert {:ok, "pr_branch"} = Merge.merge_back(pr_cell.id)
    end
  end

  describe "merge_back/1 with unknown cell_id" do
    test "returns {:error, :cell_not_found} for a non-existent cell" do
      assert {:error, :cell_not_found} = Merge.merge_back("cel-nonexistent")
    end
  end

  describe "merge_back/1 with nil merge_strategy on comb" do
    test "defaults to manual when comb has nil merge_strategy", ctx do
      # Set merge_strategy to NULL directly, simulating an older comb record
      # that predates the merge_strategy column default.
      Ecto.Adapters.SQL.query!(
        Repo,
        "UPDATE combs SET merge_strategy = NULL WHERE id = ?",
        [ctx.comb.id]
      )

      assert {:ok, "manual"} = Merge.merge_back(ctx.cell.id)
    end
  end
end
