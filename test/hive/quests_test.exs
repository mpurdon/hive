defmodule Hive.QuestsTest do
  use ExUnit.Case, async: false

  alias Hive.Quests
  alias Hive.Store

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "hive_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    if Process.whereis(Hive.Store), do: GenServer.stop(Hive.Store)
    {:ok, _} = Hive.Store.start_link(data_dir: tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    {:ok, comb} =
      Store.insert(:combs, %{name: "quests-test-comb-#{:erlang.unique_integer([:positive])}"})

    %{comb: comb}
  end

  describe "create/1" do
    test "creates a quest with a goal and auto-generates name" do
      assert {:ok, quest} = Quests.create(%{goal: "Refactor the auth module"})
      assert quest.goal == "Refactor the auth module"
      assert quest.name == "refactor-the-auth-module"
      assert quest.status == "pending"
      assert String.starts_with?(quest.id, "qst-")
    end

    test "accepts optional comb_id", %{comb: comb} do
      assert {:ok, quest} = Quests.create(%{goal: "Build feature", comb_id: comb.id})
      assert quest.comb_id == comb.id
    end

    test "accepts explicit name override" do
      assert {:ok, quest} = Quests.create(%{goal: "Do the thing", name: "custom-name"})
      assert quest.name == "custom-name"
      assert quest.goal == "Do the thing"
    end

    test "requires goal" do
      assert {:error, {:missing_fields, [:goal]}} = Quests.create(%{})
    end
  end

  describe "get/1" do
    test "retrieves a quest by ID and preloads jobs" do
      {:ok, quest} = Quests.create(%{goal: "Find quest"})

      assert {:ok, found} = Quests.get(quest.id)
      assert found.id == quest.id
      assert found.jobs == []
    end

    test "returns error for unknown ID" do
      assert {:error, :not_found} = Quests.get("qst-000000")
    end
  end

  describe "list/1" do
    test "returns all quests" do
      {:ok, _} = Quests.create(%{goal: "Quest 1"})
      {:ok, _} = Quests.create(%{goal: "Quest 2"})

      quests = Quests.list()
      assert length(quests) >= 2
    end

    test "filters by status" do
      {:ok, _} = Quests.create(%{goal: "Pending quest"})
      {:ok, q} = Quests.create(%{goal: "Active quest"})

      Store.put(:quests, %{q | status: "active"})

      pending = Quests.list(status: "pending")
      assert Enum.all?(pending, &(&1.status == "pending"))

      active = Quests.list(status: "active")
      assert length(active) >= 1
    end
  end

  describe "compute_status/1" do
    test "returns pending for empty job list" do
      assert Quests.compute_status([]) == "pending"
    end

    test "returns pending when all jobs are pending" do
      assert Quests.compute_status(["pending", "pending"]) == "pending"
    end

    test "returns completed when all jobs are done" do
      assert Quests.compute_status(["done", "done", "done"]) == "completed"
    end

    test "returns failed when any job has failed" do
      assert Quests.compute_status(["done", "failed", "pending"]) == "failed"
    end

    test "returns active when any job is running" do
      assert Quests.compute_status(["done", "running", "pending"]) == "active"
    end

    test "returns active when any job is assigned" do
      assert Quests.compute_status(["pending", "assigned"]) == "active"
    end

    test "returns pending for mixed pending and blocked" do
      assert Quests.compute_status(["pending", "blocked"]) == "pending"
    end

    test "failed takes precedence over active" do
      assert Quests.compute_status(["running", "failed"]) == "failed"
    end
  end

  describe "update_status!/1" do
    test "recomputes status from job statuses", %{comb: comb} do
      {:ok, quest} = Quests.create(%{goal: "Update status quest"})

      {:ok, _} =
        Hive.Jobs.create(%{
          title: "Done job",
          quest_id: quest.id,
          comb_id: comb.id,
          status: "done"
        })

      {:ok, _} =
        Hive.Jobs.create(%{
          title: "Running job",
          quest_id: quest.id,
          comb_id: comb.id,
          status: "running"
        })

      assert {:ok, updated} = Quests.update_status!(quest.id)
      assert updated.status == "active"
    end

    test "sets completed when all jobs done", %{comb: comb} do
      {:ok, quest} = Quests.create(%{goal: "Complete quest"})

      {:ok, _} =
        Hive.Jobs.create(%{
          title: "Job 1",
          quest_id: quest.id,
          comb_id: comb.id,
          status: "done"
        })

      {:ok, _} =
        Hive.Jobs.create(%{
          title: "Job 2",
          quest_id: quest.id,
          comb_id: comb.id,
          status: "done"
        })

      assert {:ok, updated} = Quests.update_status!(quest.id)
      assert updated.status == "completed"
    end
  end

  describe "add_job/2" do
    test "creates a job linked to the quest", %{comb: comb} do
      {:ok, quest} = Quests.create(%{goal: "Quest with jobs"})

      assert {:ok, job} =
               Quests.add_job(quest.id, %{title: "Do something", comb_id: comb.id})

      assert job.quest_id == quest.id
      assert job.title == "Do something"
    end
  end
end
