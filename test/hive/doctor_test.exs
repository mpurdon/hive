defmodule Hive.DoctorTest do
  use ExUnit.Case, async: false

  alias Hive.Doctor
  alias Hive.Repo
  alias Hive.Schema.{Bee, Cell, Comb}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  describe "checks/0" do
    test "returns all check names" do
      checks = Doctor.checks()
      assert is_list(checks)
      assert :git_installed in checks
      assert :claude_installed in checks
      assert :database_ok in checks
      assert :orphan_cells in checks
      assert :stale_bees in checks
    end
  end

  describe "check/1 - git_installed" do
    test "reports ok when git is available" do
      result = Doctor.check(:git_installed)
      # git should be available in CI and dev environments
      assert result.name == :git_installed
      assert result.status == :ok
      assert result.message =~ "git"
    end
  end

  describe "check/1 - database_ok" do
    test "reports ok when database is accessible" do
      result = Doctor.check(:database_ok)
      assert result.name == :database_ok
      assert result.status == :ok
      assert result.message =~ "accessible"
    end
  end

  describe "check/1 - hive_initialized" do
    test "returns a check result with name and status" do
      result = Doctor.check(:hive_initialized)
      assert result.name == :hive_initialized
      assert result.status in [:ok, :error]
      assert is_binary(result.message)
    end
  end

  describe "check/1 - orphan_cells" do
    test "reports ok when no orphan cells exist" do
      result = Doctor.check(:orphan_cells)
      assert result.name == :orphan_cells
      assert result.status == :ok
      assert result.message =~ "No orphan"
    end

    test "reports warn when orphan cells exist" do
      # Create a comb, a stopped bee, and an active cell for that bee
      {:ok, comb} =
        %Comb{}
        |> Comb.changeset(%{name: "orphan-test-comb-#{:erlang.unique_integer([:positive])}"})
        |> Repo.insert()

      {:ok, bee} =
        %Bee{}
        |> Bee.changeset(%{name: "orphan-bee", status: "stopped"})
        |> Repo.insert()

      {:ok, _cell} =
        %Cell{}
        |> Cell.changeset(%{
          bee_id: bee.id,
          comb_id: comb.id,
          worktree_path: "/tmp/fake-worktree",
          branch: "bee/#{bee.id}",
          status: "active"
        })
        |> Repo.insert()

      result = Doctor.check(:orphan_cells)
      assert result.name == :orphan_cells
      assert result.status == :warn
      assert result.fixable == true
      assert result.message =~ "orphan cell"
    end
  end

  describe "check/1 - stale_bees" do
    test "reports ok when no stale bees exist" do
      result = Doctor.check(:stale_bees)
      assert result.name == :stale_bees
      assert result.status == :ok
    end

    test "reports warn when stale bees exist" do
      {:ok, _bee} =
        %Bee{}
        |> Bee.changeset(%{name: "stale-bee", status: "starting", pid: nil})
        |> Repo.insert()

      result = Doctor.check(:stale_bees)
      assert result.name == :stale_bees
      assert result.status == :warn
      assert result.fixable == true
      assert result.message =~ "stale bee"
    end
  end

  describe "fix/1 - orphan_cells" do
    test "cleans up orphan cells" do
      {:ok, comb} =
        %Comb{}
        |> Comb.changeset(%{name: "fix-orphan-comb-#{:erlang.unique_integer([:positive])}"})
        |> Repo.insert()

      {:ok, bee} =
        %Bee{}
        |> Bee.changeset(%{name: "fix-orphan-bee", status: "crashed"})
        |> Repo.insert()

      {:ok, _cell} =
        %Cell{}
        |> Cell.changeset(%{
          bee_id: bee.id,
          comb_id: comb.id,
          worktree_path: "/tmp/fake-fix-worktree",
          branch: "bee/#{bee.id}",
          status: "active"
        })
        |> Repo.insert()

      result = Doctor.fix(:orphan_cells)
      assert result.name == :orphan_cells
      assert result.status == :ok
      assert result.message =~ "Fixed"
    end
  end

  describe "fix/1 - stale_bees" do
    test "marks stale bees as crashed" do
      {:ok, bee} =
        %Bee{}
        |> Bee.changeset(%{name: "fix-stale-bee", status: "working", pid: nil})
        |> Repo.insert()

      result = Doctor.fix(:stale_bees)
      assert result.name == :stale_bees
      assert result.status == :ok
      assert result.message =~ "Marked"

      # Verify the bee was updated
      updated = Repo.get(Bee, bee.id)
      assert updated.status == "crashed"
    end
  end

  describe "fix/1 - queen_workspace" do
    test "regenerates QUEEN.md when in a hive workspace" do
      case Hive.hive_dir() do
        {:ok, path} ->
          queen_md = Path.join([path, ".hive", "queen", "QUEEN.md"])
          # Remove it so fix can regenerate
          File.rm(queen_md)

          result = Doctor.fix(:queen_workspace)
          assert result.name == :queen_workspace
          assert result.status == :ok
          assert result.message =~ "Regenerated"
          assert File.exists?(queen_md)

        {:error, _} ->
          # Not in a hive workspace, skip
          :ok
      end
    end
  end

  describe "fix/1 - config_valid" do
    test "regenerates config.toml when in a hive workspace" do
      case Hive.hive_dir() do
        {:ok, path} ->
          config_path = Path.join([path, ".hive", "config.toml"])
          # Corrupt the config
          File.write(config_path, "invalid toml content [[[")

          result = Doctor.fix(:config_valid)
          assert result.name == :config_valid
          assert result.status == :ok
          assert result.message =~ "Regenerated"

          # Verify config is valid again
          assert {:ok, _} = Hive.Config.read_config(config_path)

        {:error, _} ->
          # Not in a hive workspace, skip
          :ok
      end
    end
  end

  describe "fix/1 - unfixable check" do
    test "returns error for non-fixable checks" do
      result = Doctor.fix(:git_installed)
      assert result.status == :error
      assert result.message =~ "Not fixable"
    end
  end

  describe "run_all/0" do
    test "returns results for all checks" do
      results = Doctor.run_all()
      assert is_list(results)
      assert length(results) == length(Doctor.checks())

      Enum.each(results, fn r ->
        assert is_atom(r.name)
        assert r.status in [:ok, :warn, :error]
        assert is_binary(r.message)
        assert is_boolean(r.fixable)
      end)
    end
  end

  describe "run_all/1 with fix: true" do
    test "auto-fixes fixable issues" do
      {:ok, _bee} =
        %Bee{}
        |> Bee.changeset(%{name: "autofix-bee", status: "starting", pid: nil})
        |> Repo.insert()

      results = Doctor.run_all(fix: true)

      stale_result = Enum.find(results, &(&1.name == :stale_bees))
      assert stale_result.status == :ok
    end
  end
end
