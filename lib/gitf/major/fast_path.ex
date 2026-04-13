defmodule GiTF.Major.FastPath do
  @moduledoc """
  Fast path for missions that don't need the full multi-strategy pipeline.

  Instead of skipping phases entirely, the fast path runs the same
  research → requirements → design → planning → implementation pipeline
  but in streamlined mode:

  - **Design**: single "minimal" strategy (not 3 competing designs)
  - **Review**: auto-approved (no comparison needed with 1 design)
  - **All other phases**: run normally but benefit from the focused scope

  This ensures validation always has requirements to check against,
  while keeping execution fast for simple tasks.
  """

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
  Returns true if the mission is running in fast pipeline mode.
  Used by orchestrator to streamline individual phases.
  """
  @spec fast_mode?(map()) :: boolean()
  def fast_mode?(mission) do
    Map.get(mission, :pipeline_mode) == "fast"
  end

  # -- Private ---------------------------------------------------------------

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
