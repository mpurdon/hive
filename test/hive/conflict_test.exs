defmodule Hive.ConflictTest do
  use ExUnit.Case, async: false

  alias Hive.Conflict
  alias Hive.Store

  setup do
    store_dir = Path.join(System.tmp_dir!(), "hive_store_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(store_dir)
    if Process.whereis(Hive.Store), do: GenServer.stop(Hive.Store)
    {:ok, _} = Hive.Store.start_link(data_dir: store_dir)
    on_exit(fn -> File.rm_rf!(store_dir) end)

    # Create a temporary git repo for testing
    tmp_dir = Path.join(System.tmp_dir!(), "hive_conflict_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    System.cmd("git", ["init"], cd: tmp_dir)
    System.cmd("git", ["config", "user.email", "test@test.com"], cd: tmp_dir)
    System.cmd("git", ["config", "user.name", "Test"], cd: tmp_dir)
    File.write!(Path.join(tmp_dir, "README.md"), "# Test")
    System.cmd("git", ["add", "."], cd: tmp_dir)
    System.cmd("git", ["commit", "-m", "initial"], cd: tmp_dir)

    {:ok, comb} =
      Store.insert(:combs, %{
        name: "conflict-comb-#{:erlang.unique_integer([:positive])}",
        path: tmp_dir
      })

    {:ok, bee} =
      Store.insert(:bees, %{name: "conflict-bee-#{:erlang.unique_integer([:positive])}", status: "starting"})

    on_exit(fn -> File.rm_rf(tmp_dir) end)

    %{comb: comb, bee: bee, tmp_dir: tmp_dir}
  end

  describe "check/1" do
    test "returns clean when no conflicts exist", %{comb: comb, bee: bee, tmp_dir: tmp_dir} do
      # Create a branch with non-conflicting changes
      System.cmd("git", ["checkout", "-b", "test-branch"], cd: tmp_dir)
      File.write!(Path.join(tmp_dir, "new_file.txt"), "new content")
      System.cmd("git", ["add", "."], cd: tmp_dir)
      System.cmd("git", ["commit", "-m", "add new file"], cd: tmp_dir)
      System.cmd("git", ["checkout", "main"], cd: tmp_dir)

      {:ok, cell} =
        Store.insert(:cells, %{
          comb_id: comb.id,
          bee_id: bee.id,
          branch: "test-branch",
          worktree_path: tmp_dir,
          status: "active"
        })

      assert {:ok, :clean} = Conflict.check(cell.id)
    end

    test "returns error for non-existent cell" do
      assert {:error, :cell_not_found} = Conflict.check("cel-nonexistent")
    end
  end

  describe "check_all_active/0" do
    test "returns empty list when no active cells" do
      assert Conflict.check_all_active() == []
    end
  end
end
