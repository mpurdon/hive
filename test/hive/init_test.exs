defmodule Hive.InitTest do
  use ExUnit.Case, async: false

  # The init module tries to start its own Repo, but in tests the Repo
  # is already running with the Sandbox pool. Init handles the
  # {:error, {:already_started, _}} case and calls ensure_migrated!
  # on the existing Repo -- which needs a sandbox checkout.

  alias Hive.Repo

  @tmp_dir System.tmp_dir!()

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  defp tmp_workspace do
    path = Path.join(@tmp_dir, "hive_init_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(path)
    on_exit(fn -> File.rm_rf!(path) end)
    path
  end

  describe "init/2" do
    test "creates the .hive directory structure" do
      workspace = tmp_workspace()

      assert {:ok, ^workspace} = Hive.Init.init(workspace)

      assert File.dir?(Path.join(workspace, ".hive"))
      assert File.dir?(Path.join([workspace, ".hive", "queen"]))
      assert File.exists?(Path.join([workspace, ".hive", "config.toml"]))
      assert File.exists?(Path.join([workspace, ".hive", "queen", "QUEEN.md"]))
    end

    test "writes a valid TOML config" do
      workspace = tmp_workspace()

      {:ok, _} = Hive.Init.init(workspace)

      config_path = Path.join([workspace, ".hive", "config.toml"])
      assert {:ok, config} = Hive.Config.read_config(config_path)
      assert config["queen"]["max_bees"] == 5
    end

    test "writes QUEEN.md with delegation instructions" do
      workspace = tmp_workspace()

      {:ok, _} = Hive.Init.init(workspace)

      queen_path = Path.join([workspace, ".hive", "queen", "QUEEN.md"])
      content = File.read!(queen_path)

      assert content =~ "Queen Instructions"
      assert content =~ "COORDINATION, not coding"
      assert content =~ "NEVER write the code yourself"
    end

    test "refuses to reinitialize without --force" do
      workspace = tmp_workspace()

      {:ok, _} = Hive.Init.init(workspace)
      assert {:error, :already_initialized} = Hive.Init.init(workspace)
    end

    test "reinitializes with force: true" do
      workspace = tmp_workspace()

      {:ok, _} = Hive.Init.init(workspace)
      assert {:ok, ^workspace} = Hive.Init.init(workspace, force: true)
    end

    test "expands paths to absolute form" do
      workspace = tmp_workspace()

      {:ok, result} = Hive.Init.init(workspace)

      assert Path.type(result) == :absolute
    end
  end
end
