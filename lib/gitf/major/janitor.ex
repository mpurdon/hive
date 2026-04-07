defmodule GiTF.Major.Janitor do
  @moduledoc """
  Autonomous maintenance agent for the Dark Factory.

  The Janitor identifies "passive" codebase improvements when the factory is idle:
  - Documentation gaps (missing @doc, @moduledoc)
  - Type spec gaps
  - Linter warnings
  - Dead code identification
  - Code duplication
  """

  require Logger
  alias GiTF.Archive

  @doc """
  Evaluates the factory state and spawns janitor missions if idle.
  """
  def run_if_idle do
    if GiTF.Config.dark_factory?() and idle?() do
      Logger.info("Factory is idle, spawning janitor mission...")
      spawn_janitor_mission()
    else
      :ok
    end
  end

  defp idle? do
    active_missions = Archive.filter(:missions, &(&1.status == "active"))
    length(active_missions) == 0
  end

  defp spawn_janitor_mission do
    # Pick a sector at random (or based on last maintenance)
    sectors = Archive.all(:sectors)
    if sectors != [] do
      sector = Enum.random(sectors)
      goal = pick_janitor_goal()
      
      case GiTF.Missions.create(%{
        goal: goal,
        sector_id: sector.id,
        name: "janitor-#{GiTF.ID.generate(:msn)}",
        status: "pending"
      }) do
        {:ok, mission} ->
          Logger.info("Janitor: created mission #{mission.id} for sector #{sector.name}")
          # Start it in fast-path (single ghost) for simple cleanup
          GiTF.Major.Orchestrator.start_quest(mission.id, force_fast_path: true)
        _ -> :ok
      end
    end
  end

  @goals [
    "Identify and add missing @doc and @moduledoc strings to public modules and functions.",
    "Add Elixir type specifications (@spec) to public functions that are missing them.",
    "Identify and remove unused private functions or variables.",
    "Check for TODO or FIXME comments and resolve the ones that are simple fixes.",
    "Identify code blocks that are duplicated and suggest a shared helper function."
  ]

  defp pick_janitor_goal do
    Enum.random(@goals)
  end
end
