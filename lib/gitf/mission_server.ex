defmodule GiTF.MissionServer do
  @moduledoc """
  Per-mission GenServer that manages an active mission's lifecycle.

  Each active mission runs as its own process, registered in GiTF.Registry
  under `{:mission, mission_id}`. This distributes mission management
  across processes instead of funneling everything through Major.

  ## Responsibilities
  - Track op completion and advance phases when ready
  - Monitor budget utilization and pause if exceeded
  - Hold mission state in process memory (avoid repeated Archive reads)
  - Emit telemetry events for dashboard updates

  ## Lifecycle
  Started by Major.Orchestrator.start_quest, stopped on completion/failure.
  Uses :transient restart — stays down if stopped normally.
  """

  use GenServer
  require Logger

  alias GiTF.{Budget, Missions, Ops}
  alias GiTF.Major.Orchestrator

  @registry GiTF.Registry
  @budget_check_interval :timer.seconds(30)

  # -- Child spec ----------------------------------------------------------------

  @doc """
  Child spec for DynamicSupervisor usage.

  Uses `:transient` restart so the process stays down after normal exit
  (mission completed/stopped) but restarts on crashes.
  """
  def child_spec(mission_id) do
    %{
      id: {__MODULE__, mission_id},
      start: {__MODULE__, :start_link, [mission_id]},
      restart: :transient,
      type: :worker
    }
  end

  # -- Client API ----------------------------------------------------------------

  @doc """
  Starts a MissionServer for the given mission and registers it
  under `{:mission, mission_id}` in the GiTF.Registry.

  Returns `{:ok, pid}` or `{:error, reason}`.
  """
  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(mission_id) do
    GenServer.start_link(__MODULE__, mission_id, name: via(mission_id))
  end

  @doc """
  Looks up the PID of a running MissionServer by mission ID.

  Returns `{:ok, pid}` or `:error` if not running.
  """
  @spec lookup(String.t()) :: {:ok, pid()} | :error
  def lookup(mission_id) do
    case Registry.lookup(@registry, {:mission, mission_id}) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc """
  Returns a snapshot of the current mission state.

  Returns `{:ok, map()}` or `{:error, :not_found}` if the server is not running.
  """
  @spec status(String.t()) :: {:ok, map()} | {:error, :not_found}
  def status(mission_id) do
    case lookup(mission_id) do
      {:ok, pid} -> {:ok, GenServer.call(pid, :status)}
      :error -> {:error, :not_found}
    end
  end

  @doc """
  Notifies the MissionServer that an op has completed.

  Called by ghost workers when they finish an op. The server updates its
  in-memory op list, checks phase completion, and advances if ready.
  """
  @spec notify_op_complete(String.t(), String.t()) :: :ok | {:error, :not_found}
  def notify_op_complete(mission_id, op_id) do
    case lookup(mission_id) do
      {:ok, pid} -> GenServer.cast(pid, {:op_complete, op_id})
      :error -> {:error, :not_found}
    end
  end

  @doc """
  Gracefully stops the MissionServer for a mission.

  Returns `:ok` or `{:error, :not_found}` if the server is not running.
  """
  @spec stop(String.t()) :: :ok | {:error, :not_found}
  def stop(mission_id) do
    case lookup(mission_id) do
      {:ok, pid} -> GenServer.stop(pid, :normal)
      :error -> {:error, :not_found}
    end
  end

  # -- GenServer callbacks -------------------------------------------------------

  @impl true
  def init(mission_id) do
    GiTF.Logger.set_mission_context(mission_id)

    case Missions.get(mission_id) do
      {:ok, mission} ->
        ops = Map.get(mission, :ops, [])
        mission_data = Map.delete(mission, :ops)

        budget_remaining =
          case Budget.check(mission_id) do
            {:ok, remaining} -> remaining
            {:error, :budget_exceeded, _spent} -> 0.0
          end

        Phoenix.PubSub.subscribe(GiTF.PubSub, "link:major")

        schedule_budget_check()

        state = %{
          mission_id: mission_id,
          mission: mission_data,
          ops: ops,
          phase: Map.get(mission_data, :current_phase, "pending"),
          budget_remaining: budget_remaining,
          started_at: DateTime.utc_now()
        }

        Logger.info("MissionServer started for mission #{mission_id} in phase #{state.phase}")

        GiTF.Telemetry.emit([:gitf, :mission_server, :started], %{}, %{
          mission_id: mission_id,
          phase: state.phase
        })

        {:ok, state, :hibernate}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    snapshot = %{
      mission_id: state.mission_id,
      phase: state.phase,
      budget_remaining: state.budget_remaining,
      op_count: length(state.ops),
      ops_done: Enum.count(state.ops, &(&1.status == "done")),
      ops_running: Enum.count(state.ops, &(&1.status in ["running", "assigned"])),
      started_at: state.started_at
    }

    {:reply, snapshot, state}
  end

  @impl true
  def handle_cast({:op_complete, op_id}, state) do
    state = refresh_op(state, op_id)

    phase_ops = ops_for_phase(state.ops, state.phase)
    all_done? = phase_ops != [] and Enum.all?(phase_ops, &(&1.status == "done"))

    state =
      if all_done? do
        Logger.info(
          "All ops done for phase #{state.phase} on mission #{state.mission_id}, advancing"
        )

        GiTF.Telemetry.emit([:gitf, :mission_server, :phase_complete], %{}, %{
          mission_id: state.mission_id,
          phase: state.phase
        })

        # Delegate phase advancement to the Orchestrator
        case Orchestrator.advance_quest(state.mission_id) do
          {:ok, new_phase} when is_binary(new_phase) ->
            %{state | phase: new_phase}

          {:ok, _} ->
            # Reload phase from archive for non-string responses
            reload_phase(state)

          {:error, reason} ->
            Logger.warning(
              "Failed to advance mission #{state.mission_id} from phase #{state.phase}: #{inspect(reason)}"
            )

            state
        end
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info(:check_budget, state) do
    budget_remaining =
      case Budget.check(state.mission_id) do
        {:ok, remaining} ->
          remaining

        {:error, :budget_exceeded, spent} ->
          Logger.warning(
            "Mission #{state.mission_id} budget exceeded (spent: $#{Float.round(spent, 2)})"
          )

          GiTF.Telemetry.emit([:gitf, :mission_server, :budget_exceeded], %{}, %{
            mission_id: state.mission_id,
            spent: spent
          })

          Phoenix.PubSub.broadcast(
            GiTF.PubSub,
            "link:major",
            {:mission_budget_exceeded, state.mission_id, spent}
          )

          0.0
      end

    schedule_budget_check()

    if budget_remaining > 0 do
      {:noreply, %{state | budget_remaining: budget_remaining}, :hibernate}
    else
      {:noreply, %{state | budget_remaining: budget_remaining}}
    end
  end

  # Handle PubSub messages relevant to this mission
  def handle_info({:op_status_changed, %{mission_id: mid, op_id: op_id}}, state)
      when mid == state.mission_id do
    {:noreply, refresh_op(state, op_id)}
  end

  # Ignore PubSub messages for other missions
  def handle_info({:op_status_changed, _}, state), do: {:noreply, state}

  # Catch-all for other PubSub messages we don't care about
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(reason, state) do
    Logger.info(
      "MissionServer for mission #{state.mission_id} terminating: #{inspect(reason)}"
    )

    GiTF.Telemetry.emit([:gitf, :mission_server, :stopped], %{}, %{
      mission_id: state.mission_id,
      phase: state.phase,
      reason: inspect(reason)
    })

    :ok
  end

  # -- Private helpers -----------------------------------------------------------

  defp via(mission_id) do
    {:via, Registry, {@registry, {:mission, mission_id}}}
  end

  defp schedule_budget_check do
    # Jitter ±5s to avoid thundering herd when many MissionServers run
    jitter = :rand.uniform(10_000) - 5_000
    Process.send_after(self(), :check_budget, @budget_check_interval + jitter)
  end

  # Refresh a single op's data from Archive and update it in our in-memory list.
  @spec refresh_op(map(), String.t()) :: map()
  defp refresh_op(state, op_id) do
    case Ops.get(op_id) do
      {:ok, updated_op} ->
        ops =
          state.ops
          |> Enum.reject(&(&1.id == op_id))
          |> List.insert_at(0, updated_op)

        %{state | ops: ops}

      {:error, _} ->
        state
    end
  end

  # Reload the current phase from the archive after an advance.
  @spec reload_phase(map()) :: map()
  # Reload both phase and ops from Archive to pick up new phase ops
  # created by advance_quest (e.g., new implementation ops after planning).
  defp reload_phase(state) do
    case GiTF.Missions.get(state.mission_id) do
      {:ok, mission} ->
        ops = Map.get(mission, :ops, state.ops)

        %{state | phase: mission[:current_phase] || state.phase, ops: ops}

      _ ->
        state
    end
  end

  # Return ops belonging to the given phase.
  # Phase ops are identified by the phase_job flag or by matching the mission's
  # current implementation ops when in the "implementation" phase.
  @spec ops_for_phase([map()], String.t()) :: [map()]
  defp ops_for_phase(ops, "implementation") do
    Enum.reject(ops, & &1[:phase_job])
  end

  defp ops_for_phase(ops, phase) do
    Enum.filter(ops, fn op ->
      op[:phase_job] == true and op[:phase] == phase
    end)
  end
end
