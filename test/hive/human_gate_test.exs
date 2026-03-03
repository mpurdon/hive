defmodule Hive.HumanGateTest do
  use ExUnit.Case, async: false

  alias Hive.HumanGate
  alias Hive.Store
  alias Hive.Test.StoreHelper

  setup do
    data_dir = Path.join(System.tmp_dir!(), "hive_test_gate_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(data_dir)
    StoreHelper.restart_store!(data_dir)

    on_exit(fn ->
      StoreHelper.stop_store()
      File.rm_rf!(data_dir)
    end)

    :ok
  end

  defp create_quest(opts \\ %{}) do
    goal = Map.get(opts, :goal, "Test quest")
    comb_id = Map.get(opts, :comb_id, "cmb_test")

    # Create comb
    comb_attrs = Map.get(opts, :comb, %{})
    comb = Map.merge(%{id: comb_id, path: "/tmp/test", name: "test"}, comb_attrs)
    Store.insert(:combs, comb)

    {:ok, quest} = Hive.Quests.create(%{goal: goal, comb_id: comb_id})
    quest
  end

  defp add_job(quest, opts \\ %{}) do
    risk = Map.get(opts, :risk_level, :low)

    {:ok, job} = Hive.Jobs.create(%{
      title: "Test job",
      quest_id: quest.id,
      comb_id: quest.comb_id
    })

    # Set risk_level directly (classifier may override attrs)
    updated = %{job | risk_level: risk}
    Store.put(:jobs, updated)
    updated
  end

  describe "requires_approval?/1" do
    test "returns false when all jobs are low risk" do
      quest = create_quest()
      add_job(quest, %{risk_level: :low})
      {:ok, quest} = Hive.Quests.get(quest.id)

      refute HumanGate.requires_approval?(quest)
    end

    test "returns true when a job has high risk" do
      quest = create_quest()
      add_job(quest, %{risk_level: :high})
      {:ok, quest} = Hive.Quests.get(quest.id)

      assert HumanGate.requires_approval?(quest)
    end

    test "returns true when a job has critical risk" do
      quest = create_quest()
      add_job(quest, %{risk_level: :critical})
      {:ok, quest} = Hive.Quests.get(quest.id)

      assert HumanGate.requires_approval?(quest)
    end

    test "returns true when comb has require_human_approval" do
      quest = create_quest(%{comb: %{require_human_approval: true}})
      add_job(quest, %{risk_level: :low})
      {:ok, quest} = Hive.Quests.get(quest.id)

      assert HumanGate.requires_approval?(quest)
    end

    test "returns false when no jobs exist" do
      quest = create_quest()
      {:ok, quest} = Hive.Quests.get(quest.id)

      refute HumanGate.requires_approval?(quest)
    end
  end

  describe "approve/1 and reject/2" do
    test "approve stores artifact and updates status" do
      quest = create_quest()

      {:ok, artifact} = HumanGate.approve(quest.id)
      assert artifact["approved"] == true

      assert HumanGate.approval_status(quest.id) == :approved
    end

    test "reject stores artifact with reason" do
      quest = create_quest()

      {:ok, artifact} = HumanGate.reject(quest.id, "Not ready")
      assert artifact["approved"] == false
      assert artifact["reason"] == "Not ready"

      assert HumanGate.approval_status(quest.id) == :rejected
    end
  end

  describe "approval_status/1" do
    test "returns :not_required when no request exists" do
      quest = create_quest()
      assert HumanGate.approval_status(quest.id) == :not_required
    end

    test "returns :pending after request_approval" do
      quest = create_quest()
      add_job(quest, %{risk_level: :high})
      {:ok, _request} = HumanGate.request_approval(quest.id)

      assert HumanGate.approval_status(quest.id) == :pending
    end

    test "returns :approved after approve" do
      quest = create_quest()
      {:ok, _request} = HumanGate.request_approval(quest.id)
      {:ok, _} = HumanGate.approve(quest.id)

      assert HumanGate.approval_status(quest.id) == :approved
    end
  end

  describe "pending_approvals/0" do
    test "lists pending requests" do
      quest1 = create_quest(%{goal: "Quest 1"})
      quest2 = create_quest(%{goal: "Quest 2"})

      {:ok, _} = HumanGate.request_approval(quest1.id)
      {:ok, _} = HumanGate.request_approval(quest2.id)

      pending = HumanGate.pending_approvals()
      assert length(pending) == 2

      # Approve one
      HumanGate.approve(quest1.id)
      pending = HumanGate.pending_approvals()
      assert length(pending) == 1
    end
  end

  describe "request_approval/1" do
    test "creates request with quest metadata" do
      quest = create_quest(%{goal: "Deploy new auth"})
      add_job(quest, %{risk_level: :high})

      {:ok, request} = HumanGate.request_approval(quest.id)
      assert request.quest_id == quest.id
      assert request.goal == "Deploy new auth"
      assert request.status == "pending"
      assert :high in request.risk_levels
    end
  end
end
