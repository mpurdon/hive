defmodule GiTF.Major.FastPath do
  @moduledoc """
  Fast path for missions that don't need the full 7-phase pipeline.

  Bug fixes, single features, doc updates, and focused tasks skip
  research → requirements → design → review → planning and go straight
  to implementation with a single op and ghost. Verification still runs
  (Tachikoma reviews the work and SyncQueue merges it).

  The fast path enriches the op description with sector intelligence
  (key files, patterns, tech stack) so the ghost has codebase context
  even without a dedicated research phase.
  """

  require Logger

  # Keywords that signal multi-system complexity requiring the full pipeline
  @complex_keywords ~w(migration infrastructure architect redesign
    credential secret multi-service distributed)

  @max_goal_length 1000

  @doc """
  Returns true if a mission is simple enough for the fast path.

  Checks:
  - Goal is under 1000 chars (focused, not a spec)
  - No multi-system complexity keywords
  - No excessive file references (more than 5 file paths)
  - No existing artifacts (hasn't started the pipeline)

  Can be bypassed with `force: true` in opts.
  """
  @spec eligible?(map(), keyword()) :: boolean()
  def eligible?(mission, opts \\ []) do
    if Keyword.get(opts, :force, false) do
      true
    else
      goal = Map.get(mission, :goal, "")
      goal_lower = String.downcase(goal)
      artifacts = Map.get(mission, :artifacts, %{})

      short_goal?(goal) and
        no_complex_keywords?(goal_lower) and
        no_multi_file_refs?(goal) and
        no_existing_artifacts?(artifacts)
    end
  end

  @doc """
  Executes the fast path: transitions directly to implementation, creates
  a single op with enriched context, and spawns a single ghost.
  Verification is NOT skipped — the op goes through the standard
  Tachikoma review and merge pipeline.

  Returns `{:ok, "implementation"}` or `{:error, reason}`.
  """
  @spec execute(String.t()) :: {:ok, String.t()} | {:error, term()}
  def execute(mission_id) do
    with {:ok, mission} <- GiTF.Missions.get(mission_id),
         {:ok, _} <-
           GiTF.Missions.transition_phase(mission_id, "implementation", "Fast path: focused task") do
      description = build_enriched_description(mission)

      job_attrs = %{
        title: mission.goal,
        description: description,
        mission_id: mission_id,
        sector_id: mission.sector_id,
        phase_job: false,
        skip_verification: false
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
                  {:ok, "implementation"}

                {:error, reason} ->
                  Logger.error(
                    "Fast path: ghost spawn failed for mission #{mission_id}: #{inspect(reason)}"
                  )

                  {:error, {:spawn_failed, reason}}
              end

            {:error, _} ->
              Logger.warning(
                "Fast path: no gitf root, op #{op.id} will be picked up by scheduler"
              )

              {:ok, "implementation"}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # -- Private ---------------------------------------------------------------

  defp build_enriched_description(mission) do
    goal = mission.goal
    sector_id = mission.sector_id

    context_parts = [goal, "", "## Instructions", ""]

    context_parts =
      context_parts ++
        [
          "1. First, read the relevant source files to understand the codebase structure",
          "2. Identify the specific file(s) that need to change",
          "3. Make the minimal, focused changes needed",
          "4. Verify your changes are correct (run tests if available)",
          "5. Commit your changes with a clear message",
          ""
        ]

    # Add sector intelligence context if available
    context_parts =
      if sector_id do
        case sector_context(sector_id) do
          nil -> context_parts
          ctx -> context_parts ++ ["## Codebase Context", "", ctx, ""]
        end
      else
        context_parts
      end

    Enum.join(context_parts, "\n")
  end

  defp sector_context(sector_id) do
    profile = GiTF.Intel.SectorProfile.get_or_compute(sector_id)
    prompt_ctx = Map.get(profile, :prompt_context)

    # Also try to get key files from any previous research artifacts
    research_ctx =
      case GiTF.Archive.filter(:missions, fn m -> m[:sector_id] == sector_id end)
           |> Enum.find_value(fn m ->
             GiTF.Missions.get_artifact(m.id, "research")
           end) do
        nil ->
          nil

        research ->
          key_files = Map.get(research, "key_files", [])
          tech_stack = Map.get(research, "tech_stack", [])
          architecture = Map.get(research, "architecture", "")

          parts = []

          parts =
            if architecture != "",
              do: parts ++ ["Architecture: #{architecture}"],
              else: parts

          parts =
            if tech_stack != [],
              do: parts ++ ["Tech stack: #{Enum.join(tech_stack, ", ")}"],
              else: parts

          parts =
            if key_files != [],
              do: parts ++ ["Key files: #{Enum.join(key_files, ", ")}"],
              else: parts

          if parts != [], do: Enum.join(parts, "\n"), else: nil
      end

    [prompt_ctx, research_ctx]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      parts -> Enum.join(parts, "\n\n")
    end
  end

  defp short_goal?(goal), do: String.length(goal) < @max_goal_length

  defp no_complex_keywords?(goal_lower) do
    not Enum.any?(@complex_keywords, &String.contains?(goal_lower, &1))
  end

  defp no_multi_file_refs?(goal) do
    file_refs =
      goal
      |> String.split(~r/\s+/)
      |> Enum.count(fn word ->
        String.contains?(word, "/") or Regex.match?(~r/\.\w{1,4}$/, word)
      end)

    file_refs <= 5
  end

  defp no_existing_artifacts?(artifacts) when map_size(artifacts) == 0, do: true
  defp no_existing_artifacts?(_), do: false
end
