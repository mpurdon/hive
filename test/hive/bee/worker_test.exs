defmodule Hive.Bee.WorkerTest do
  use ExUnit.Case, async: false

  alias Hive.Bee.Worker
  alias Hive.Repo
  alias Hive.Schema.{Bee, Quest}

  @tmp_dir System.tmp_dir!()

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    # Create a temp git repo to serve as a comb
    repo_path = create_temp_git_repo()
    hive_root = create_hive_workspace()

    {:ok, comb} =
      Hive.Comb.add(repo_path, name: "worker-test-comb-#{:erlang.unique_integer([:positive])}")

    {:ok, quest} =
      %Quest{}
      |> Quest.changeset(%{name: "worker-test-quest-#{:erlang.unique_integer([:positive])}"})
      |> Repo.insert()

    {:ok, job} =
      Hive.Jobs.create(%{
        title: "Test task for bee",
        description: "Do the work",
        quest_id: quest.id,
        comb_id: comb.id
      })

    {:ok, bee} =
      %Bee{}
      |> Bee.changeset(%{name: "test-worker-bee"})
      |> Repo.insert()

    # Assign the job to the bee so the transition pending->assigned works
    {:ok, _} = Hive.Jobs.assign(job.id, bee.id)

    %{
      comb: comb,
      quest: quest,
      job: job,
      bee: bee,
      hive_root: hive_root,
      repo_path: repo_path
    }
  end

  describe "start_link/1 with successful command" do
    test "provisions and runs to completion", ctx do
      # Use /bin/echo as a fake "claude" that exits immediately with 0
      {:ok, pid} =
        Worker.start_link(
          bee_id: ctx.bee.id,
          job_id: ctx.job.id,
          comb_id: ctx.comb.id,
          hive_root: ctx.hive_root,
          claude_executable: "/bin/echo",
          prompt: "hello"
        )

      # Allow the spawned GenServer access to the sandbox
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      ref = Process.monitor(pid)

      # Wait for the process to finish (echo exits quickly)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000

      # Verify DB state: bee should be stopped
      bee = Repo.get!(Bee, ctx.bee.id)
      assert bee.status == "stopped"

      # Job should be done
      {:ok, job} = Hive.Jobs.get(ctx.job.id)
      assert job.status == "done"

      # A waggle message should have been sent to the queen
      waggles = Hive.Waggle.list(from: ctx.bee.id)
      assert length(waggles) >= 1
      assert Enum.any?(waggles, &(&1.subject == "job_complete"))
    end
  end

  describe "start_link/1 with failing command" do
    test "marks bee crashed and job failed on non-zero exit", ctx do
      # Use /usr/bin/false which exits with status 1
      {:ok, pid} =
        Worker.start_link(
          bee_id: ctx.bee.id,
          job_id: ctx.job.id,
          comb_id: ctx.comb.id,
          hive_root: ctx.hive_root,
          claude_executable: "/usr/bin/false",
          prompt: "fail"
        )

      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000

      # Verify DB state: bee should be crashed
      bee = Repo.get!(Bee, ctx.bee.id)
      assert bee.status == "crashed"

      # Job should be failed
      {:ok, job} = Hive.Jobs.get(ctx.job.id)
      assert job.status == "failed"

      # A waggle message about failure
      waggles = Hive.Waggle.list(from: ctx.bee.id)
      assert Enum.any?(waggles, &(&1.subject == "job_failed"))
    end
  end

  describe "status/1" do
    test "returns the worker status while running", ctx do
      # Use /bin/sleep to keep the process alive
      {:ok, pid} =
        Worker.start_link(
          bee_id: ctx.bee.id,
          job_id: ctx.job.id,
          comb_id: ctx.comb.id,
          hive_root: ctx.hive_root,
          claude_executable: "/bin/sleep",
          prompt: "30"
        )

      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      # Give it a moment to provision
      Process.sleep(500)

      assert {:ok, status} = Worker.status(ctx.bee.id)
      assert status.bee_id == ctx.bee.id
      assert status.job_id == ctx.job.id
      assert status.status == :running

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)
    end

    test "returns error for non-running bee" do
      assert {:error, :not_found} = Worker.status("bee-nonexistent")
    end
  end

  describe "stop/1" do
    test "gracefully stops a running worker", ctx do
      {:ok, pid} =
        Worker.start_link(
          bee_id: ctx.bee.id,
          job_id: ctx.job.id,
          comb_id: ctx.comb.id,
          hive_root: ctx.hive_root,
          claude_executable: "/bin/sleep",
          prompt: "30"
        )

      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      Process.sleep(500)
      ref = Process.monitor(pid)

      assert :ok = Worker.stop(ctx.bee.id)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000

      bee = Repo.get!(Bee, ctx.bee.id)
      assert bee.status == "stopped"
    end

    test "returns error for non-running bee" do
      assert {:error, :not_found} = Worker.stop("bee-nonexistent")
    end
  end

  describe "lookup/1" do
    test "finds a running worker via Registry", ctx do
      {:ok, pid} =
        Worker.start_link(
          bee_id: ctx.bee.id,
          job_id: ctx.job.id,
          comb_id: ctx.comb.id,
          hive_root: ctx.hive_root,
          claude_executable: "/bin/sleep",
          prompt: "30"
        )

      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      Process.sleep(100)

      assert {:ok, ^pid} = Worker.lookup(ctx.bee.id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)
    end

    test "returns error when no worker running" do
      assert :error = Worker.lookup("bee-nonexistent")
    end
  end

  describe "child_spec/1" do
    test "produces a valid child spec with temporary restart" do
      spec =
        Worker.child_spec(
          bee_id: "bee-test",
          job_id: "job-test",
          comb_id: "cmb-test",
          hive_root: "/tmp"
        )

      assert spec.restart == :temporary
      assert spec.id == {Worker, "bee-test"}
    end
  end

  # -- Helpers -----------------------------------------------------------------

  defp create_temp_git_repo do
    name = "hive_worker_test_#{:erlang.unique_integer([:positive])}"
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
    name = "hive_worker_ws_#{:erlang.unique_integer([:positive])}"
    path = Path.join(@tmp_dir, name)
    File.mkdir_p!(Path.join(path, ".hive"))
    on_exit(fn -> File.rm_rf!(path) end)
    path
  end
end
