defmodule GiTF.Triage do
  @moduledoc """
  Categorizes ops by complexity and determines what pipeline they need.

  Every op flows through triage before a ghost is spawned. The triage result
  determines whether the op needs scouting (read-only codebase analysis),
  tachikoma verification, and which model tier to use.

  Complexity signals are checked in priority order -- the first match wins.
  """

  alias GiTF.Ops

  @type complexity :: :simple | :moderate | :complex

  @type pipeline :: %{
          skip_drone: boolean(),
          skip_scout: boolean(),
          recommended_model: String.t()
        }

  @complex_keywords ~w(refactor redesign migration overhaul architecture)
  @simple_keywords ["fix typo", "update config", "bump version", "rename", "add comment"]

  # -- Public API --------------------------------------------------------------

  @doc """
  Triages a op map, returning `{complexity, pipeline}`.

  Checks complexity signals in priority order:
  1. Target file count (5+ files => complex)
  2. Dependencies (any => at least moderate)
  3. Architectural keywords in title/description => complex
  4. Simple keywords in title/description => simple
  5. Pre-set `complexity` field from classifier
  6. Default: moderate
  """
  @spec triage(map()) :: {complexity(), pipeline()}
  def triage(op) do
    complexity = determine_complexity(op)
    {complexity, pipeline_for(complexity)}
  end

  @doc """
  Returns the pipeline config for a given complexity atom.
  """
  @spec pipeline_for(complexity()) :: pipeline()
  def pipeline_for(:simple) do
    %{skip_drone: true, skip_scout: true, recommended_model: "haiku"}
  end

  def pipeline_for(:moderate) do
    %{skip_drone: false, skip_scout: true, recommended_model: "sonnet"}
  end

  def pipeline_for(:complex) do
    %{skip_drone: false, skip_scout: false, recommended_model: "opus"}
  end

  # -- Private: complexity determination ---------------------------------------

  defp determine_complexity(op) do
    cond do
      many_target_files?(op) -> :complex
      has_dependencies?(op) -> at_least_moderate(op)
      has_architectural_keywords?(op) -> :complex
      has_simple_keywords?(op) -> :simple
      true -> from_classifier(op)
    end
  end

  defp many_target_files?(op) do
    files = Map.get(op, :target_files, [])
    is_list(files) and length(files) >= 5
  end

  defp has_dependencies?(op) do
    op_id = Map.get(op, :id)
    op_id != nil and Ops.dependencies(op_id) != []
  rescue
    _ -> false
  end

  defp at_least_moderate(op) do
    case from_classifier(op) do
      :simple -> :moderate
      other -> other
    end
  end

  defp has_architectural_keywords?(op) do
    text = job_text(op)
    Enum.any?(@complex_keywords, &String.contains?(text, &1))
  end

  defp has_simple_keywords?(op) do
    text = job_text(op)
    Enum.any?(@simple_keywords, &String.contains?(text, &1))
  end

  defp from_classifier(op) do
    case Map.get(op, :complexity) do
      c when c in ["trivial", "low"] -> :simple
      "moderate" -> :moderate
      c when c in ["high", "critical"] -> :complex
      _ -> :moderate
    end
  end

  defp job_text(op) do
    title = Map.get(op, :title, "") || ""
    description = Map.get(op, :description, "") || ""
    String.downcase(title <> " " <> description)
  end
end
