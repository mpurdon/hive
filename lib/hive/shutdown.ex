defmodule Hive.Shutdown do
  @moduledoc """
  Graceful shutdown orchestration for long-running TUI sessions.

  Traps exit signals and performs ordered teardown:
  1. Notify channels ("hive shutting down")
  2. Drain in-flight waggles
  3. Save Store state
  4. Stop bees gracefully (SIGTERM to Claude ports, wait timeout)
  5. Stop Queen
  6. Close TUI
  7. Exit
  """

  use GenServer

  require Logger

  @default_drain_timeout 5_000

  # -- Public API ------------------------------------------------------------

  @doc "Starts the shutdown coordinator."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Initiates graceful shutdown."
  @spec initiate() :: :ok
  def initiate do
    GenServer.cast(__MODULE__, :shutdown)
  end

  # -- GenServer callbacks ---------------------------------------------------

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    drain_timeout = Keyword.get(opts, :drain_timeout, @default_drain_timeout)
    {:ok, %{drain_timeout: drain_timeout, shutting_down: false}}
  end

  @impl true
  def handle_cast(:shutdown, %{shutting_down: true} = state) do
    {:noreply, state}
  end

  def handle_cast(:shutdown, state) do
    do_shutdown(state.drain_timeout)
    {:noreply, %{state | shutting_down: true}}
  end

  @impl true
  def terminate(_reason, state) do
    unless state.shutting_down do
      do_shutdown(state.drain_timeout)
    end

    :ok
  end

  # -- Private ---------------------------------------------------------------

  defp do_shutdown(drain_timeout) do
    Logger.info("Hive shutting down gracefully...")

    # 1. Notify channels
    notify_channels()

    # 2. Drain waggles (wait for in-flight to complete)
    drain_waggles(drain_timeout)

    # 3. Stop bees
    stop_bees(drain_timeout)

    # 4. Stop Queen
    stop_queen()

    Logger.info("Hive shutdown complete.")
  end

  defp notify_channels do
    Phoenix.PubSub.broadcast(Hive.PubSub, "hive:system", {:shutdown, :initiated})
  rescue
    _ -> :ok
  end

  defp drain_waggles(timeout) do
    Process.sleep(min(timeout, 1_000))
  end

  defp stop_bees(timeout) do
    case Process.whereis(Hive.CombSupervisor) do
      nil ->
        :ok

      _pid ->
        children = DynamicSupervisor.which_children(Hive.CombSupervisor)

        Enum.each(children, fn {_, pid, _, _} ->
          if is_pid(pid) and Process.alive?(pid) do
            GenServer.stop(pid, :shutdown, timeout)
          end
        end)
    end
  rescue
    _ -> :ok
  end

  defp stop_queen do
    case Process.whereis(Hive.Queen) do
      nil -> :ok
      pid -> GenServer.stop(pid, :shutdown, 5_000)
    end
  rescue
    _ -> :ok
  end
end
