defmodule Hive.PrimeTest do
  use ExUnit.Case, async: false

  alias Hive.Prime
  alias Hive.Repo
  alias Hive.Schema.Bee

  @tmp_dir System.tmp_dir!()

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
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
      {:ok, _bee} =
        %Bee{}
        |> Bee.changeset(%{name: "busy-bee", status: "working"})
        |> Repo.insert()

      {:ok, markdown} = Prime.prime(:queen, hive_root)
      assert markdown =~ "busy-bee"
    end
  end

  describe "prime(:bee, bee_id)" do
    test "returns a briefing for an existing bee" do
      {:ok, bee} =
        %Bee{}
        |> Bee.changeset(%{name: "worker-bee"})
        |> Repo.insert()

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
      {:ok, bee} =
        %Bee{}
        |> Bee.changeset(%{name: "idle-bee"})
        |> Repo.insert()

      {:ok, markdown} = Prime.prime(:bee, bee.id)
      assert markdown =~ "No job assigned"
    end
  end
end
