defmodule Hive.Budget.Watchdog do
  @moduledoc """
  Active budget enforcement for the Hive.

  Periodically checks the accumulated cost of all active Quests and Bees.
  If a budget is exceeded, it:
  1. Identifies the running Bees associated with the over-budget entity.
  2. Terminates them immediately via `Hive.Bees.stop/1`.
  3. Emits a high-priority alert.

  This prevents "runaway" costs from infinite loops or excessive retry cycles.
  """

  use GenServer
  require Logger

  alias Hive.Store
  alias Hive.Budget

  @check_interval :timer.seconds(10)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    Logger.info("Budget Watchdog started")
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_budgets, state) do
    check_active_quests()
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_budgets, @check_interval)
  end

  defp check_active_quests do
    # Get all active quests
    active_quests = Store.filter(:quests, fn q -> q.status == "active" end)

    Enum.each(active_quests, fn quest ->
      case Budget.check(quest.id) do
        {:error, :budget_exceeded, spent} ->
          enforce_budget(quest, spent)
        _ ->
          :ok
      end
    end)
  end

  defp enforce_budget(quest, spent) do
    Logger.warning("Quest #{quest.id} exceeded budget ($#{spent}). Terminating active bees...")

    quest_id = quest.id
    
    active_bees = Store.filter(:bees, fn b -> 
      b.job_id != nil and 
      b.status == "working"
    end)
    |> Enum.filter(fn b ->
      case Store.get(:jobs, b.job_id) do
        %{quest_id: ^quest_id} -> true
        _ -> false
      end
    end)

    if Enum.empty?(active_bees) do
      # No bees running, just mark quest as failed/paused if not already
      update_quest_status(quest.id, "paused_budget")
    else
      Enum.each(active_bees, fn bee ->
        Logger.warning("Watchdog stopping bee #{bee.id} (Quest #{quest.id} over budget)")
        Hive.Bees.stop(bee.id)
        
        # Emit alert
        Hive.Telemetry.emit([:hive, :alert, :raised], %{}, %{
          type: :budget_kill,
          message: "Bee #{bee.id} killed. Quest #{quest.id} over budget ($#{spent})"
        })
      end)
      
      update_quest_status(quest.id, "failed_budget")
    end
  end

  defp update_quest_status(quest_id, status) do
    case Store.get(:quests, quest_id) do
      nil -> :ok
      quest -> Store.put(:quests, Map.put(quest, :status, status))
    end
  end
end
