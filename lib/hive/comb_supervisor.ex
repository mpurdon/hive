defmodule Hive.CombSupervisor do
  @moduledoc """
  DynamicSupervisor for bee processes.

  Each bee runs as a temporary child under this supervisor. When a bee
  crashes or finishes, it is not automatically restarted -- the Queen
  decides whether to respawn.

  The supervisor itself uses `:one_for_one` strategy and lives in the
  Application supervision tree. It starts empty and children are added
  dynamically when bees are spawned.
  """

  use DynamicSupervisor

  @name Hive.CombSupervisor

  @doc "Starts the CombSupervisor."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Starts a child process under this supervisor.

  The child spec should define a `:temporary` restart strategy so that
  finished or crashed bees are not automatically restarted.
  """
  @spec start_child(Supervisor.child_spec() | {module(), term()}) ::
          DynamicSupervisor.on_start_child()
  def start_child(child_spec) do
    DynamicSupervisor.start_child(@name, child_spec)
  end

  @doc "Returns the count of active children."
  @spec active_count() :: non_neg_integer()
  def active_count do
    %{active: count} = DynamicSupervisor.count_children(@name)
    count
  end

  @doc "Lists all running child PIDs."
  @spec children() :: [pid()]
  def children do
    DynamicSupervisor.which_children(@name)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.filter(&is_pid/1)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
