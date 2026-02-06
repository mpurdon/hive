defmodule Hive.CombTest do
  use ExUnit.Case, async: false

  alias Hive.Comb
  alias Hive.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    tmp = Path.join(System.tmp_dir!(), "hive_comb_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    %{tmp: tmp}
  end

  describe "add/2 with a local path" do
    test "registers a comb from an existing directory", %{tmp: tmp} do
      assert {:ok, comb} = Comb.add(tmp)

      assert comb.name == Path.basename(tmp)
      assert comb.path == tmp
      assert String.starts_with?(comb.id, "cmb-")
    end

    test "uses a custom name when provided", %{tmp: tmp} do
      assert {:ok, comb} = Comb.add(tmp, name: "my-project")

      assert comb.name == "my-project"
    end

    test "returns error for non-existent path" do
      assert {:error, :path_not_found} = Comb.add("/nonexistent/path/#{System.unique_integer()}")
    end
  end

  describe "list/0" do
    test "returns empty list when no combs exist" do
      assert Comb.list() == []
    end

    test "returns all registered combs", %{tmp: tmp} do
      sub1 = Path.join(tmp, "project-a")
      sub2 = Path.join(tmp, "project-b")
      File.mkdir_p!(sub1)
      File.mkdir_p!(sub2)

      {:ok, _} = Comb.add(sub1, name: "project-a")
      {:ok, _} = Comb.add(sub2, name: "project-b")

      combs = Comb.list()
      names = Enum.map(combs, & &1.name) |> Enum.sort()

      assert names == ["project-a", "project-b"]
    end
  end

  describe "get/1" do
    test "finds a comb by name", %{tmp: tmp} do
      {:ok, created} = Comb.add(tmp, name: "findme")

      assert {:ok, found} = Comb.get("findme")
      assert found.id == created.id
    end

    test "finds a comb by ID", %{tmp: tmp} do
      {:ok, created} = Comb.add(tmp, name: "byid")

      assert {:ok, found} = Comb.get(created.id)
      assert found.name == "byid"
    end

    test "returns error for unknown name" do
      assert {:error, :not_found} = Comb.get("nonexistent")
    end
  end

  describe "remove/2" do
    test "removes a comb record by name", %{tmp: tmp} do
      {:ok, _} = Comb.add(tmp, name: "removeme")

      assert {:ok, removed} = Comb.remove("removeme")
      assert removed.name == "removeme"

      assert {:error, :not_found} = Comb.get("removeme")
    end

    test "returns error for unknown comb" do
      assert {:error, :not_found} = Comb.remove("ghost")
    end
  end

  describe "merge_strategy field" do
    test "defaults to manual when not specified", %{tmp: tmp} do
      assert {:ok, comb} = Comb.add(tmp, name: "default-strategy")

      assert comb.merge_strategy == "manual"
    end

    test "can create comb with specific merge_strategy" do
      alias Hive.Schema.Comb, as: CombSchema

      changeset = CombSchema.changeset(%{name: "pr-comb", merge_strategy: "pr_branch"})
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :merge_strategy) == "pr_branch"

      changeset = CombSchema.changeset(%{name: "auto-comb", merge_strategy: "auto_merge"})
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :merge_strategy) == "auto_merge"
    end

    test "rejects invalid merge_strategy" do
      alias Hive.Schema.Comb, as: CombSchema

      changeset = CombSchema.changeset(%{name: "bad-comb", merge_strategy: "yolo"})
      refute changeset.valid?
      assert {"is invalid", _} = changeset.errors[:merge_strategy]
    end
  end
end
