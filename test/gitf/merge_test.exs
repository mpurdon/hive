defmodule GiTF.MergeTest do
  use ExUnit.Case, async: false

  alias GiTF.Merge
  alias GiTF.Store

  setup do
    GiTF.Test.StoreHelper.ensure_infrastructure()

    tmp_dir = Path.join(System.tmp_dir!(), "gitf_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    GiTF.Test.StoreHelper.stop_store()
    {:ok, _} = GiTF.Store.start_link(data_dir: tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    {:ok, sector} =
      Store.insert(:sectors, %{
        name: "merge-sector-#{:erlang.unique_integer([:positive])}",
        merge_strategy: "manual"
      })

    {:ok, mission} =
      Store.insert(:missions, %{
        name: "merge-mission-#{:erlang.unique_integer([:positive])}",
        status: "pending"
      })

    {:ok, op} =
      GiTF.Ops.create(%{
        title: "Merge test task",
        description: "Test the merge strategies",
        mission_id: mission.id,
        sector_id: sector.id
      })

    {:ok, ghost} =
      Store.insert(:ghosts, %{name: "merge-ghost", status: "working", op_id: op.id})

    {:ok, shell} =
      Store.insert(:shells, %{
        ghost_id: ghost.id,
        sector_id: sector.id,
        worktree_path: "/tmp/merge-worktree",
        branch: "ghost/#{ghost.id}",
        status: "active"
      })

    %{sector: sector, mission: mission, op: op, ghost: ghost, shell: shell}
  end

  describe "merge_back/1 with manual strategy" do
    test "returns {:ok, \"manual\"} for a sector with manual merge_strategy", ctx do
      assert {:ok, "manual"} = Merge.merge_back(ctx.shell.id)
    end
  end

  describe "merge_back/1 with pr_branch strategy" do
    test "returns {:ok, \"pr_branch\"} for a sector with pr_branch merge_strategy", ctx do
      # Create a sector with pr_branch strategy
      {:ok, pr_comb} =
        Store.insert(:sectors, %{
          name: "pr-sector-#{:erlang.unique_integer([:positive])}",
          merge_strategy: "pr_branch"
        })

      # Create a shell pointing to this sector
      {:ok, pr_cell} =
        Store.insert(:shells, %{
          ghost_id: ctx.ghost.id,
          sector_id: pr_comb.id,
          worktree_path: "/tmp/pr-worktree",
          branch: "ghost/pr-test",
          status: "active"
        })

      assert {:ok, "pr_branch"} = Merge.merge_back(pr_cell.id)
    end
  end

  describe "merge_back/1 with unknown shell_id" do
    test "returns {:error, :cell_not_found} for a non-existent shell" do
      assert {:error, :cell_not_found} = Merge.merge_back("cel-nonexistent")
    end
  end

  describe "merge_back/1 with nil merge_strategy on sector" do
    test "defaults to manual when sector has nil merge_strategy", ctx do
      # Set merge_strategy to nil directly, simulating an older sector record
      updated_comb = %{ctx.sector | merge_strategy: nil}
      Store.put(:sectors, updated_comb)

      assert {:ok, "manual"} = Merge.merge_back(ctx.shell.id)
    end
  end

  describe "auto_merge rollback" do
    test "auto_merge with invalid repo path returns error", ctx do
      # Create a sector with auto_merge strategy but no valid git repo
      {:ok, auto_comb} =
        Store.insert(:sectors, %{
          name: "auto-sector-#{:erlang.unique_integer([:positive])}",
          merge_strategy: "auto_merge",
          path: "/tmp/nonexistent-repo"
        })

      {:ok, auto_cell} =
        Store.insert(:shells, %{
          ghost_id: ctx.ghost.id,
          sector_id: auto_comb.id,
          worktree_path: "/tmp/nonexistent-worktree",
          branch: "ghost/auto-test",
          status: "active"
        })

      # Should fail gracefully with merge_conflict error, not crash
      result = Merge.merge_back(auto_cell.id)
      assert match?({:error, _}, result)
    end
  end

  describe "merge_back_with_rebase/1" do
    test "returns error for non-existent shell" do
      assert {:error, :cell_not_found} = Merge.merge_back_with_rebase("cel-nonexistent")
    end
  end
end
