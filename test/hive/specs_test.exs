defmodule Hive.SpecsTest do
  use ExUnit.Case, async: false

  alias Hive.Specs

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "hive_specs_test_#{:erlang.unique_integer([:positive])}")

    hive_root = tmp_dir
    hive_dir = Path.join(hive_root, ".hive")
    File.mkdir_p!(hive_dir)

    # Point Hive.hive_dir/0 to our temp workspace
    System.put_env("HIVE_PATH", hive_root)

    # Start the store (some tests may need it indirectly)
    store_dir = Path.join(hive_dir, "store")
    File.mkdir_p!(store_dir)
    Hive.Test.StoreHelper.stop_store()
    {:ok, _} = Hive.Store.start_link(data_dir: store_dir)

    on_exit(fn ->
      System.delete_env("HIVE_PATH")
      File.rm_rf!(tmp_dir)
    end)

    %{hive_root: hive_root}
  end

  describe "write/3" do
    test "writes a requirements spec file" do
      assert {:ok, path} = Specs.write("qst-123", "requirements", "# Requirements\n\n- Feature A")
      assert File.exists?(path)
      assert String.ends_with?(path, "qst-123/requirements.md")
      assert File.read!(path) == "# Requirements\n\n- Feature A"
    end

    test "writes a design spec file" do
      assert {:ok, path} = Specs.write("qst-123", "design", "# Design\n\nUse module X")
      assert File.exists?(path)
      assert String.ends_with?(path, "qst-123/design.md")
    end

    test "writes a tasks spec file" do
      assert {:ok, path} = Specs.write("qst-123", "tasks", "# Tasks\n\n1. Do thing")
      assert File.exists?(path)
      assert String.ends_with?(path, "qst-123/tasks.md")
    end

    test "rejects invalid phase" do
      assert {:error, {:invalid_phase, "invalid"}} = Specs.write("qst-123", "invalid", "content")
    end

    test "creates quest directory if it doesn't exist" do
      quest_id = "qst-newdir-#{:erlang.unique_integer([:positive])}"
      dir = Specs.quest_dir(quest_id)
      refute File.dir?(dir)

      assert {:ok, _path} = Specs.write(quest_id, "requirements", "content")
      assert File.dir?(dir)
    end

    test "overwrites existing spec" do
      Specs.write("qst-overwrite", "requirements", "v1")
      assert {:ok, "v1"} = Specs.read("qst-overwrite", "requirements")

      Specs.write("qst-overwrite", "requirements", "v2")
      assert {:ok, "v2"} = Specs.read("qst-overwrite", "requirements")
    end
  end

  describe "read/2" do
    test "reads an existing spec" do
      Specs.write("qst-read", "design", "# Design Doc")
      assert {:ok, "# Design Doc"} = Specs.read("qst-read", "design")
    end

    test "returns not_found for missing spec" do
      assert {:error, :not_found} = Specs.read("qst-nonexistent", "requirements")
    end

    test "returns not_found for missing phase of existing quest" do
      Specs.write("qst-partial", "requirements", "content")
      assert {:error, :not_found} = Specs.read("qst-partial", "design")
    end

    test "rejects invalid phase" do
      assert {:error, {:invalid_phase, "bogus"}} = Specs.read("qst-123", "bogus")
    end
  end

  describe "list_phases/1" do
    test "lists existing phases in order" do
      Specs.write("qst-phases", "design", "design content")
      Specs.write("qst-phases", "requirements", "reqs content")

      assert Specs.list_phases("qst-phases") == ["requirements", "design"]
    end

    test "returns empty list for nonexistent quest" do
      assert Specs.list_phases("qst-no-such") == []
    end

    test "lists all three phases" do
      Specs.write("qst-all", "requirements", "r")
      Specs.write("qst-all", "design", "d")
      Specs.write("qst-all", "tasks", "t")

      assert Specs.list_phases("qst-all") == ["requirements", "design", "tasks"]
    end

    test "ignores non-phase files in quest directory" do
      quest_id = "qst-extra-files"
      Specs.write(quest_id, "requirements", "content")

      # Write a non-phase file directly
      dir = Specs.quest_dir(quest_id)
      File.write!(Path.join(dir, "notes.md"), "random")

      assert Specs.list_phases(quest_id) == ["requirements"]
    end
  end

  describe "quest_dir/1" do
    test "returns path under .hive/quests/" do
      dir = Specs.quest_dir("qst-abc")
      assert dir =~ ".hive/quests/qst-abc"
    end
  end

  describe "phases/0" do
    test "returns the three valid phases" do
      assert Specs.phases() == ["requirements", "design", "tasks"]
    end
  end
end
