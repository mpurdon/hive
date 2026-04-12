defmodule GiTF.ModelPerformance do
  @moduledoc """
  Aggregates model performance data across ops, costs, and scores.

  Answers questions like "which model is most cost-effective for design?"
  and "which model has the lowest retry rate?" by correlating existing
  data from Archive collections.
  """

  alias GiTF.{Archive, Costs}

  @doc """
  Returns a performance summary for all models that have been used.

  Each entry includes success rate, average quality, retry rate,
  total cost, cost per successful op, and breakdowns by phase and op_type.
  """
  @spec summary() :: [map()]
  def summary do
    ops = Archive.all(:ops) |> Enum.filter(&(&1[:assigned_model] != nil))
    costs = Archive.all(:costs)
    scores = Archive.all(:model_scores)

    models = extract_unique_models(ops, costs)

    Enum.map(models, fn model ->
      model_ops = Enum.filter(ops, &(&1.assigned_model == model))
      model_costs = Enum.filter(costs, &(&1.model == model))
      model_scores = Enum.filter(scores, &(&1.model == model))

      %{
        model: model,
        total_ops: length(model_ops),
        success_rate: success_rate(model_ops),
        avg_quality: avg_quality(model_ops),
        retry_rate: retry_rate(model_ops),
        total_cost: Costs.total(model_costs),
        cost_per_success: cost_per_success(model_ops, model_costs),
        by_phase: phase_breakdown(model, costs),
        by_op_type: op_type_breakdown(model_ops, model_scores)
      }
    end)
    |> Enum.sort_by(& &1.total_cost, :desc)
  end

  @doc """
  Returns a phase-level comparison across all models.

  For each phase, shows which models were used and their performance metrics.
  Helps answer "should design use Opus or Sonnet?"
  """
  @spec phase_comparison() :: %{String.t() => [map()]}
  def phase_comparison do
    costs = Archive.all(:costs)
    ops = Archive.all(:ops) |> Enum.filter(&(&1[:assigned_model] != nil))

    # Group costs by phase
    phases =
      costs
      |> Enum.filter(&(&1[:phase] != nil and &1.phase != "unknown"))
      |> Enum.group_by(& &1.phase)

    Map.new(phases, fn {phase, phase_costs} ->
      # Group by model within this phase
      by_model =
        phase_costs
        |> Enum.group_by(& &1.model)
        |> Enum.map(fn {model, model_costs} ->
          phase_ops =
            Enum.filter(ops, fn op ->
              op.assigned_model == model and
                op[:phase_job] == true and
                op[:phase] == phase
            end)

          %{
            model: model,
            cost: Costs.total(model_costs),
            ops: length(phase_ops),
            success_rate: success_rate(phase_ops),
            avg_quality: avg_quality(phase_ops)
          }
        end)
        |> Enum.sort_by(& &1.cost, :desc)

      {phase, by_model}
    end)
  end

  @doc """
  Recommends the best model for a given phase based on cost-effectiveness.

  Returns the model with the lowest cost_per_success that has at least
  `min_ops` completed ops (default 3) for statistical significance.
  """
  @spec recommend_for(String.t(), keyword()) :: String.t() | nil
  def recommend_for(phase, opts \\ []) do
    min_ops = Keyword.get(opts, :min_ops, 3)
    comparison = phase_comparison()

    case Map.get(comparison, phase) do
      nil ->
        nil

      models ->
        models
        |> Enum.filter(&(&1.ops >= min_ops and &1.success_rate > 0))
        |> Enum.min_by(
          fn m ->
            if m.success_rate > 0, do: m.cost / m.success_rate, else: :infinity
          end,
          fn -> nil end
        )
        |> case do
          nil -> nil
          m -> m.model
        end
    end
  end

  # -- Private helpers -------------------------------------------------------

  defp extract_unique_models(ops, costs) do
    op_models = ops |> Enum.map(& &1.assigned_model) |> Enum.reject(&is_nil/1)
    cost_models = costs |> Enum.map(& &1.model) |> Enum.reject(&is_nil/1)
    Enum.uniq(op_models ++ cost_models)
  end

  defp success_rate([]), do: 0.0

  defp success_rate(ops) do
    terminal = Enum.filter(ops, &(&1.status in ["done", "failed"]))

    if terminal == [],
      do: 0.0,
      else: Float.round(Enum.count(terminal, &(&1.status == "done")) / length(terminal), 3)
  end

  defp avg_quality(ops) do
    scores =
      ops
      |> Enum.filter(&(&1.status == "done" and is_number(&1[:quality_score])))
      |> Enum.map(& &1.quality_score)

    if scores == [], do: nil, else: Float.round(Enum.sum(scores) / length(scores), 1)
  end

  defp retry_rate([]), do: 0.0

  defp retry_rate(ops) do
    retried = Enum.count(ops, &((&1[:retry_count] || 0) > 0))
    Float.round(retried / length(ops), 3)
  end

  defp cost_per_success(ops, costs) do
    successful = Enum.count(ops, &(&1.status == "done"))
    total_cost = Costs.total(costs)
    if successful > 0, do: Float.round(total_cost / successful, 4), else: nil
  end

  defp phase_breakdown(model, costs) do
    costs
    |> Enum.filter(&(&1.model == model and &1[:phase] != nil))
    |> Enum.group_by(& &1.phase)
    |> Map.new(fn {phase, group} ->
      {phase, %{cost: Costs.total(group), count: length(group)}}
    end)
  end

  defp op_type_breakdown(model_ops, model_scores) do
    # From model_scores (richer data)
    score_data =
      model_scores
      |> Enum.group_by(& &1.op_type)
      |> Map.new(fn {op_type, group} ->
        passed = Enum.count(group, & &1.passed)

        {op_type,
         %{
           total: length(group),
           passed: passed,
           pass_rate: if(length(group) > 0, do: Float.round(passed / length(group), 3), else: 0.0)
         }}
      end)

    # Supplement with op counts for types not in model_scores
    op_data =
      model_ops
      |> Enum.group_by(&(&1[:op_type] || "unknown"))
      |> Map.new(fn {op_type, group} ->
        {op_type,
         %{
           total: length(group),
           passed: Enum.count(group, &(&1.status == "done")),
           pass_rate: success_rate(group)
         }}
      end)

    Map.merge(op_data, score_data)
  end
end
