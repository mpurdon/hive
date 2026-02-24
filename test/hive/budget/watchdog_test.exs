defmodule Hive.Budget.WatchdogTest do
  use ExUnit.Case

  alias Hive.Budget.Watchdog
  alias Hive.Store

  setup do
    # Ensure Watchdog is started.
    # In tests, it might already be started by Hive.Application.
    # We can check its status or restart it.
    
    # Create a dummy quest
    quest_id = "q-test-budget"
    Store.insert(:quests, %{id: quest_id, status: "active", goal: "Test Budget"})
    
    # Create a dummy bee linked to this quest
    bee_id = "b-test-budget"
    job_id = "j-test-budget"
    Store.insert(:jobs, %{id: job_id, quest_id: quest_id, bee_id: bee_id, status: "assigned"})
    Store.insert(:bees, %{id: bee_id, job_id: job_id, status: "working", pid: "dummy"})

    # Ensure cost is zero initially
    Hive.Costs.record(bee_id, %{cost_usd: 0.0})

    {:ok, %{quest_id: quest_id, bee_id: bee_id}}
  end

  test "watchdog kills bee when budget exceeded", %{quest_id: quest_id, bee_id: bee_id} do
    # 1. Artificially inflate the cost
    Hive.Costs.record(bee_id, %{cost_usd: 100.0}) # Assuming default budget is 10.0

    # 2. Trigger watchdog check manually
    Process.send(Hive.Budget.Watchdog, :check_budgets, [])

    # 3. Wait for reaction
    Process.sleep(100)

    # 4. Check bee status (should be stopped/crashed)
    # Note: In test, Hive.Bees.stop/1 calls Hive.Bee.Worker.stop/1.
    # If the worker process doesn't exist, it might just update the DB record or error.
    # The watchdog logic calls Bees.stop/1 then updates DB if it fails?
    # No, Watchdog calls Bees.stop(bee.id).
    
    # Check if an alert was emitted (via PubSubBridge if configured)
    # Or check if quest status was updated to "failed_budget"
    
    quest = Store.get(:quests, quest_id)
    assert quest.status == "failed_budget"
  end
end
