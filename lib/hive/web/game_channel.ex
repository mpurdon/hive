defmodule Hive.Web.GameChannel do
  use Phoenix.Channel
  require Logger

  alias Hive.PubSubBridge

  @doc """
  Authorized clients join "game:control".
  They receive the initial world state immediately.
  """
  @impl true
  def join("game:control", _payload, socket) do
    # Subscribe to internal telemetry bridge to forward events to this socket
    PubSubBridge.subscribe()
    
    # Send initial world dump so the game can bootstrap
    send(self(), :send_initial_state)
    
    {:ok, socket}
  end

  # -- Inbound Commands (Game Client -> Hive) --------------------------------

  @doc """
  Handles inbound commands from the game client.
  
  Supported commands:
  - `spawn_quest`: Create a new work order.
  - `emergency_stop`: Kill all active bees.
  """
  @impl true
  def handle_in("spawn_quest", %{"goal" => goal} = payload, socket) do
    # Default to first comb if not provided (demo mode)
    comb_id = Map.get(payload, "comb_id") || default_comb_id()
    
    case Hive.Quests.create(%{goal: goal, comb_id: comb_id, source: "game_ui"}) do
      {:ok, quest} ->
        {:reply, {:ok, %{quest_id: quest.id}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("emergency_stop", _payload, socket) do
    Logger.warning("Emergency Stop received from Game Client")
    
    # Kill active bees
    active_bees = Hive.Store.filter(:bees, fn b -> b.status == "working" end)
    Enum.each(active_bees, fn bee -> Hive.Bees.stop(bee.id) end)
    
    {:reply, :ok, socket}
  end

  # -- Outbound Events (Hive -> Game Client) ---------------------------------

  @doc """
  Forward internal PubSub events to the game client.
  We transform the internal payload into a cleaner "Game Protocol".
  """
  @impl true
  def handle_info({:hive_event, payload}, socket) do
    # payload is %{event: "hive.bee.spawned", measurements: %{}, metadata: %{...}}
    
    # Simplify for the game client
    game_event = %{
      type: payload.event,
      data: payload.metadata,
      timestamp: DateTime.to_unix(payload.timestamp, :millisecond)
    }
    
    push(socket, "hive_event", game_event)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:send_initial_state, socket) do
    # Snapshot of the world
    state = %{
      quests: Hive.Store.all(:quests),
      bees: Hive.Store.all(:bees),
      combs: Hive.Store.all(:combs)
    }
    
    push(socket, "world_state", state)
    {:noreply, socket}
  end
  
  defp default_comb_id do
    case Hive.Comb.list() do
      [first | _] -> first.id
      _ -> nil
    end
  end
end
