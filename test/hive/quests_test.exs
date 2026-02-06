defmodule Hive.QuestsTest do
  use ExUnit.Case, async: false

  alias Hive.Quests
  alias Hive.Repo
  alias Hive.Schema.{Comb, Quest}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    {:ok, comb} =
      %Comb{}
      |> Comb.changeset(%{name: "quests-test-comb-#{:erlang.unique_integer([:positive])}"})
      |> Repo.insert()

    %{comb: comb}
  end

  describe "create/1" do
    test "creates a quest with a name" do
      assert {:ok, quest} = Quests.create(%{name: "Refactor auth"})
      assert quest.name == "Refactor auth"
      assert quest.status == "pending"
      assert String.starts_with?(quest.id, "qst-")
    end

    test "accepts optional comb_id", %{comb: comb} do
      assert {:ok, quest} = Quests.create(%{name: "Build feature", comb_id: comb.id})
      assert quest.comb_id == comb.id
    end

    test "requires name" do
      assert {:error, changeset} = Quests.create(%{})
      assert %{name: _} = errors_on(changeset)
    end
  end

  describe "get/1" do
    test "retrieves a quest by ID and preloads jobs" do
      {:ok, quest} = Quests.create(%{name: "Find quest"})

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
      {:ok, _} = Quests.create(%{name: "Quest 1"})
      {:ok, _} = Quests.create(%{name: "Quest 2"})

      quests = Quests.list()
      assert length(quests) >= 2
    end

    test "filters by status" do
      {:ok, _} = Quests.create(%{name: "Pending quest"})
      {:ok, q} = Quests.create(%{name: "Active quest"})

      q
      |> Quest.changeset(%{status: "active"})
      |> Repo.update!()

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
      {:ok, quest} = Quests.create(%{name: "Update status quest"})

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
      {:ok, quest} = Quests.create(%{name: "Complete quest"})

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
      {:ok, quest} = Quests.create(%{name: "Quest with jobs"})

      assert {:ok, job} =
               Quests.add_job(quest.id, %{title: "Do something", comb_id: comb.id})

      assert job.quest_id == quest.id
      assert job.title == "Do something"
    end
  end

  # -- Helpers -----------------------------------------------------------------

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
