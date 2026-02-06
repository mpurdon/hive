defmodule Hive.BeesTest do
  use ExUnit.Case, async: false

  alias Hive.Bees
  alias Hive.Repo
  alias Hive.Schema.{Bee, Quest}

  @tmp_dir System.tmp_dir!()

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    repo_path = create_temp_git_repo()
    hive_root = create_hive_workspace()

    {:ok, comb} =
      Hive.Comb.add(repo_path, name: "bees-test-comb-#{:erlang.unique_integer([:positive])}")

    {:ok, quest} =
      %Quest{}
      |> Quest.changeset(%{name: "bees-test-quest-#{:erlang.unique_integer([:positive])}"})
      |> Repo.insert()

    {:ok, job} =
      Hive.Jobs.create(%{
        title: "Bees test task",
        quest_id: quest.id,
        comb_id: comb.id
      })

    %{comb: comb, quest: quest, job: job, hive_root: hive_root}
  end

  describe "spawn/4" do
    test "creates a bee record, assigns the job, and starts a worker", ctx do
      assert {:ok, bee} =
               Bees.spawn(ctx.job.id, ctx.comb.id, ctx.hive_root,
                 name: "spawned-bee",
                 claude_executable: "/bin/echo",
                 prompt: "hello"
               )

      # Allow the spawned worker process access to the sandbox
      case Hive.Bee.Worker.lookup(bee.id) do
        {:ok, pid} -> Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
        :error -> :ok
      end

      assert bee.name == "spawned-bee"
      assert String.starts_with?(bee.id, "bee-")

      # Job should be assigned to this bee
      {:ok, job} = Hive.Jobs.get(ctx.job.id)
      assert job.bee_id == bee.id
      assert job.status == "assigned"

      # Worker should have started (wait for it to finish since echo exits fast)
      Process.sleep(1_000)

      # After echo finishes, bee should be stopped
      {:ok, updated_bee} = Bees.get(bee.id)
      assert updated_bee.status == "stopped"
    end

    test "auto-generates a name if not provided", ctx do
      assert {:ok, bee} =
               Bees.spawn(ctx.job.id, ctx.comb.id, ctx.hive_root,
                 claude_executable: "/bin/echo",
                 prompt: "auto-name"
               )

      case Hive.Bee.Worker.lookup(bee.id) do
        {:ok, pid} -> Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
        :error -> :ok
      end

      assert is_binary(bee.name)
      assert String.length(bee.name) > 0

      # Wait for process to finish
      Process.sleep(500)
    end
  end

  describe "list/1" do
    test "lists all bees" do
      {:ok, _} =
        %Bee{}
        |> Bee.changeset(%{name: "listed-bee", status: "idle"})
        |> Repo.insert()

      bees = Bees.list()
      assert length(bees) >= 1
    end

    test "filters by status" do
      {:ok, _} =
        %Bee{}
        |> Bee.changeset(%{name: "idle-bee", status: "idle"})
        |> Repo.insert()

      {:ok, _} =
        %Bee{}
        |> Bee.changeset(%{name: "working-bee", status: "working"})
        |> Repo.insert()

      idle = Bees.list(status: "idle")
      assert Enum.all?(idle, &(&1.status == "idle"))

      working = Bees.list(status: "working")
      assert Enum.all?(working, &(&1.status == "working"))
    end
  end

  describe "get/1" do
    test "retrieves a bee by ID" do
      {:ok, created} =
        %Bee{}
        |> Bee.changeset(%{name: "get-test-bee"})
        |> Repo.insert()

      assert {:ok, found} = Bees.get(created.id)
      assert found.id == created.id
    end

    test "returns error for unknown ID" do
      assert {:error, :not_found} = Bees.get("bee-000000")
    end
  end

  describe "stop/1" do
    test "stops a running worker", ctx do
      {:ok, bee} =
        Bees.spawn(ctx.job.id, ctx.comb.id, ctx.hive_root,
          name: "stoppable-bee",
          claude_executable: "/bin/sleep",
          prompt: "30"
        )

      case Hive.Bee.Worker.lookup(bee.id) do
        {:ok, pid} -> Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
        :error -> :ok
      end

      Process.sleep(500)

      assert :ok = Bees.stop(bee.id)
      Process.sleep(200)

      {:ok, stopped_bee} = Bees.get(bee.id)
      assert stopped_bee.status == "stopped"
    end

    test "returns error for non-running bee" do
      assert {:error, :not_found} = Bees.stop("bee-nonexistent")
    end
  end

  # -- Helpers -----------------------------------------------------------------

  defp create_temp_git_repo do
    name = "hive_bees_test_#{:erlang.unique_integer([:positive])}"
    path = Path.join(@tmp_dir, name)
    File.mkdir_p!(path)

    System.cmd("git", ["init"], cd: path, stderr_to_stdout: true)
    System.cmd("git", ["config", "user.email", "test@hive.local"], cd: path)
    System.cmd("git", ["config", "user.name", "Test"], cd: path)

    readme = Path.join(path, "README.md")
    File.write!(readme, "# Test\n")
    System.cmd("git", ["add", "."], cd: path, stderr_to_stdout: true)
    System.cmd("git", ["commit", "-m", "initial"], cd: path, stderr_to_stdout: true)

    {real_path, 0} =
      System.cmd("git", ["rev-parse", "--show-toplevel"],
        cd: path,
        stderr_to_stdout: true
      )

    real_path = String.trim(real_path)
    on_exit(fn -> File.rm_rf!(path) end)
    real_path
  end

  defp create_hive_workspace do
    name = "hive_bees_ws_#{:erlang.unique_integer([:positive])}"
    path = Path.join(@tmp_dir, name)
    File.mkdir_p!(Path.join(path, ".hive"))
    on_exit(fn -> File.rm_rf!(path) end)
    path
  end
end
