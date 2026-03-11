defmodule GiTF.Major.FastPath do
  @moduledoc """
  Fast path for simple missions that don't need the full 7-phase pipeline.

  Trivial missions (typo fixes, doc updates, version bumps, simple renames) skip
  research → requirements → design → review → planning and go straight to
  implementation with a single op and a single ghost.
  """

  require Logger

  @complex_keywords ~w(migration security auth deploy database infrastructure
    refactor architect redesign integration credential secret)

  @simple_indicators ~w(fix typo update rename doc bump comment format lint
    spelling whitespace changelog version readme license)

  @max_goal_length 500

  @doc """
  Returns true if a mission is simple enough for the fast path.

  Checks:
  - Goal is short (< 500 chars)
  - No complex keywords (migration, security, auth, deploy, etc.)
  - No multi-file references (more than 2 file paths)
  - Has at least one simple indicator keyword
  - No existing artifacts (hasn't started the pipeline)
  """
  @spec eligible?(map()) :: boolean()
  def eligible?(mission) do
    goal = Map.get(mission, :goal, "")
    goal_lower = String.downcase(goal)
    artifacts = Map.get(mission, :artifacts, %{})

    short_goal?(goal) and
      no_complex_keywords?(goal_lower) and
      no_multi_file_refs?(goal) and
      has_simple_indicator?(goal_lower) and
      no_existing_artifacts?(artifacts)
  end

  @doc """
  Executes the fast path: transitions directly to implementation, creates
  a single op, and spawns a single ghost.

  Returns `{:ok, "implementation"}` or `{:error, reason}`.
  """
  @spec execute(String.t()) :: {:ok, String.t()} | {:error, term()}
  def execute(mission_id) do
    with {:ok, mission} <- GiTF.Missions.get(mission_id),
         {:ok, _} <- GiTF.Missions.transition_phase(mission_id, "implementation", "Fast path: simple mission") do

      # Create a single implementation op
      job_attrs = %{
        title: mission.goal,
        description: mission.goal,
        mission_id: mission_id,
        sector_id: mission.sector_id,
        phase_job: false
      }

      case GiTF.Ops.create(job_attrs) do
        {:ok, op} ->
          Logger.info("Fast path: created op #{op.id} for mission #{mission_id}")

          # Spawn a ghost for the op
          case GiTF.gitf_dir() do
            {:ok, gitf_root} ->
              case GiTF.Ghosts.spawn_detached(op.id, mission.sector_id, gitf_root) do
                {:ok, ghost} ->
                  Logger.info("Fast path: spawned ghost #{ghost.id} for mission #{mission_id}")

                {:error, reason} ->
                  Logger.warning("Fast path: ghost spawn failed: #{inspect(reason)}")
              end

            {:error, _} ->
              Logger.warning("Fast path: no gitf root, op #{op.id} will be picked up by scheduler")
          end

          {:ok, "implementation"}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # -- Private ---------------------------------------------------------------

  defp short_goal?(goal), do: String.length(goal) < @max_goal_length

  defp no_complex_keywords?(goal_lower) do
    not Enum.any?(@complex_keywords, &String.contains?(goal_lower, &1))
  end

  defp no_multi_file_refs?(goal) do
    # Count things that look like file paths (contain / or end with common extensions)
    file_refs =
      goal
      |> String.split(~r/\s+/)
      |> Enum.count(fn word ->
        String.contains?(word, "/") or Regex.match?(~r/\.\w{1,4}$/, word)
      end)

    file_refs <= 2
  end

  defp has_simple_indicator?(goal_lower) do
    Enum.any?(@simple_indicators, &String.contains?(goal_lower, &1))
  end

  defp no_existing_artifacts?(artifacts) when map_size(artifacts) == 0, do: true
  defp no_existing_artifacts?(_), do: false
end
