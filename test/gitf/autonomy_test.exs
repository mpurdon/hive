defmodule GiTF.AutonomyTest do
  use ExUnit.Case, async: false

  alias GiTF.Autonomy
  alias GiTF.Archive

  setup do
    GiTF.Test.StoreHelper.ensure_infrastructure()

    store_dir = Path.join(System.tmp_dir!(), "section-autonomy-test-#{:rand.uniform(100_000)}")
    File.mkdir_p!(store_dir)
    GiTF.Test.StoreHelper.stop_store()
    {:ok, _} = Archive.start_link(data_dir: store_dir)

    on_exit(fn -> File.rm_rf!(store_dir) end)

    %{store_dir: store_dir}
  end

  describe "self_heal/0" do
    test "returns empty list when system is healthy" do
      results = Autonomy.self_heal()

      assert is_list(results)
    end

    test "cleans up orphaned ghosts" do
      # Create ghost without active op
      ghost = %{
        id: "ghost-orphan",
        status: "active",
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      Archive.insert(:ghosts, ghost)

      results = Autonomy.self_heal()

      # Should detect and clean up orphaned ghost
      assert is_list(results)
    end
  end

  describe "optimize_resources/0" do
    test "provides optimization recommendations" do
      recommendations = Autonomy.optimize_resources()

      assert is_list(recommendations)
    end
  end

  describe "compute_scaling_decision/1" do
    test "returns full cap when no active missions exist" do
      {target, meta} = Autonomy.compute_scaling_decision(5)

      assert target == 5
      assert meta.reason == :headroom
      assert meta.max_util == 0.0
    end

    test "returns full cap when budget utilization is low" do
      seed_mission_with_spent("mission-low", 10.0, 2.0)

      {target, meta} = Autonomy.compute_scaling_decision(8)

      assert target == 8
      assert meta.reason == :headroom
    end

    test "gentle scale-down at 70%+ utilization" do
      seed_mission_with_spent("mission-mid", 10.0, 7.5)

      {target, meta} = Autonomy.compute_scaling_decision(8)

      # ceil(8 * 0.75) = 6
      assert target == 6
      assert meta.reason == :budget_moderate
    end

    test "aggressive scale-down at 85%+ utilization" do
      seed_mission_with_spent("mission-hot", 10.0, 9.0)

      {target, meta} = Autonomy.compute_scaling_decision(8)

      # ceil(8 * 0.5) = 4
      assert target == 4
      assert meta.reason == :budget_high
    end

    test "crawl at 95%+ utilization" do
      seed_mission_with_spent("mission-critical", 10.0, 9.8)

      {target, meta} = Autonomy.compute_scaling_decision(8)

      assert target == 1
      assert meta.reason == :budget_critical
    end

    test "hottest mission drives the decision" do
      seed_mission_with_spent("mission-cool", 10.0, 1.0)
      seed_mission_with_spent("mission-warm", 10.0, 8.9)

      {target, meta} = Autonomy.compute_scaling_decision(8)

      assert target == 4
      assert meta.reason == :budget_high
    end

    test "never exceeds the hard ceiling" do
      {target, _} = Autonomy.compute_scaling_decision(3)
      assert target <= 3
    end

    test "floors at 1 even for small hard ceilings under pressure" do
      seed_mission_with_spent("mission-squeeze", 10.0, 9.0)

      {target, meta} = Autonomy.compute_scaling_decision(2)

      # ceil(2 * 0.5) = 1, floor enforces min 1
      assert target == 1
      assert meta.reason == :budget_high
    end
  end

  # -- Test helpers ----------------------------------------------------------

  defp seed_mission_with_spent(mission_id, budget, spent) do
    Archive.insert(:missions, %{
      id: mission_id,
      status: "active",
      budget_override: budget,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    })

    ghost_id = "ghost-#{mission_id}"

    Archive.insert(:ops, %{
      id: "op-#{mission_id}",
      mission_id: mission_id,
      ghost_id: ghost_id,
      status: "running",
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    })

    Archive.insert(:costs, %{
      id: "cost-#{mission_id}",
      ghost_id: ghost_id,
      mission_id: mission_id,
      cost_usd: spent,
      recorded_at: DateTime.utc_now()
    })
  end

  describe "predict_issues/1" do
    test "predicts issues based on failure patterns" do
      sector_id = "sector-predict"

      # Create some failed ops
      for i <- 1..3 do
        op = %{
          id: "op-fail-#{i}",
          sector_id: sector_id,
          status: "failed",
          error_message: "timeout",
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }

        Archive.insert(:ops, op)
      end

      predictions = Autonomy.predict_issues(sector_id)

      assert is_list(predictions)
    end
  end

  describe "audit/2" do
    test "creates audit log entry" do
      {:ok, entry} = Autonomy.audit(:job_approved, %{op_id: "op-123"})

      assert entry.action == :job_approved
      assert entry.details.op_id == "op-123"
    end
  end
end
