defmodule Hive.PrimeTest do
  use ExUnit.Case, async: false

  alias Hive.Prime
  alias Hive.Store

  @tmp_dir System.tmp_dir!()

  setup do
    tmp_dir = Path.join(@tmp_dir, "hive_store_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    if Process.whereis(Hive.Store), do: GenServer.stop(Hive.Store)
    {:ok, _} = Hive.Store.start_link(data_dir: tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    :ok
  end

  defp create_hive_workspace do
    name = "hive_prime_test_#{:erlang.unique_integer([:positive])}"
    hive_root = Path.join(@tmp_dir, name)
    queen_dir = Path.join([hive_root, ".hive", "queen"])
    File.mkdir_p!(queen_dir)

    queen_md = Path.join(queen_dir, "QUEEN.md")
    File.write!(queen_md, "# Queen Instructions\n\nYou are the Queen.\n")

    on_exit(fn -> File.rm_rf!(hive_root) end)
    hive_root
  end

  describe "prime(:queen, hive_root)" do
    test "returns QUEEN.md content plus hive state summary" do
      hive_root = create_hive_workspace()

      assert {:ok, markdown} = Prime.prime(:queen, hive_root)
      assert markdown =~ "Queen Instructions"
      assert markdown =~ "Current Hive State"
      assert markdown =~ "Active Bees"
      assert markdown =~ "Pending Jobs"
    end

    test "returns error when QUEEN.md is missing" do
      tmp = Path.join(@tmp_dir, "hive_prime_nomd_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(Path.join(tmp, ".hive"))
      on_exit(fn -> File.rm_rf!(tmp) end)

      assert {:error, :enoent} = Prime.prime(:queen, tmp)
    end

    test "includes active bee information in state summary" do
      hive_root = create_hive_workspace()

      # Create a working bee
      {:ok, _bee} = Store.insert(:bees, %{name: "busy-bee", status: "working"})

      {:ok, markdown} = Prime.prime(:queen, hive_root)
      assert markdown =~ "busy-bee"
    end

    test "includes planning quests in state summary" do
      hive_root = create_hive_workspace()

      {:ok, quest} =
        Store.insert(:quests, %{name: "plan-quest", goal: "Plan something", status: "planning"})

      {:ok, markdown} = Prime.prime(:queen, hive_root)
      assert markdown =~ "plan-quest"
      assert markdown =~ quest.id
    end

    test "includes spec content for planning quests" do
      hive_root = create_hive_workspace()

      # Point HIVE_PATH so Specs can find the .hive dir
      System.put_env("HIVE_PATH", hive_root)
      on_exit(fn -> System.delete_env("HIVE_PATH") end)

      {:ok, quest} =
        Store.insert(:quests, %{name: "spec-quest", goal: "Spec something", status: "planning"})

      Hive.Specs.write(quest.id, "requirements", "# Requirements\n\n- FR-1: Do the thing")

      {:ok, markdown} = Prime.prime(:queen, hive_root)
      assert markdown =~ "Planning Specs: spec-quest"
      assert markdown =~ "Requirements"
      assert markdown =~ "FR-1: Do the thing"
    end

    test "truncates long spec content" do
      hive_root = create_hive_workspace()

      System.put_env("HIVE_PATH", hive_root)
      on_exit(fn -> System.delete_env("HIVE_PATH") end)

      {:ok, quest} =
        Store.insert(:quests, %{name: "long-spec", goal: "Long spec", status: "planning"})

      long_content = Enum.map(1..150, fn i -> "Line #{i}" end) |> Enum.join("\n")
      Hive.Specs.write(quest.id, "requirements", long_content)

      {:ok, markdown} = Prime.prime(:queen, hive_root)
      assert markdown =~ "(truncated"
      assert markdown =~ "Line 1"
      # Line 150 should be truncated away
      refute markdown =~ "Line 150"
    end
  end

  describe "prime(:bee, bee_id)" do
    test "returns a briefing for an existing bee" do
      {:ok, bee} = Store.insert(:bees, %{name: "worker-bee", status: "starting"})

      assert {:ok, markdown} = Prime.prime(:bee, bee.id)
      assert markdown =~ "Bee Briefing"
      assert markdown =~ "worker-bee"
      assert markdown =~ "Your Job"
      assert markdown =~ "Your Workspace"
      assert markdown =~ "Rules"
    end

    test "returns error for nonexistent bee" do
      assert {:error, :bee_not_found} = Prime.prime(:bee, "bee-000000")
    end

    test "shows no job when bee has no assignment" do
      {:ok, bee} = Store.insert(:bees, %{name: "idle-bee", status: "starting"})

      {:ok, markdown} = Prime.prime(:bee, bee.id)
      assert markdown =~ "No job assigned"
    end
  end
end
