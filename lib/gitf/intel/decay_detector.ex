defmodule GiTF.Intel.DecayDetector do
  @moduledoc """
  Detects model performance decay using sliding window comparison.

  Compares a recent window of ops against the historical baseline.
  Triggers `:declining` when recent success rate drops >15% below baseline
  or recent avg quality drops >10 points.

  Time weighting: ops in the last 24h get 2× weight, ops older than 7d
  get 0.5× weight. This ensures acute degradation is caught quickly
  without overreacting to a single bad run.
  """

  alias GiTF.Archive

  require Logger

  @min_baseline 5
  @min_recent 3
  @decline_rate_threshold 0.15
  @decline_quality_threshold 10
  @severe_rate_threshold 0.25
  @severe_quality_threshold 20

  # -- Public API --------------------------------------------------------------

  @doc """
  Checks a model's performance trend, optionally scoped to a sector.

  Returns `:stable`, `:improving`, `:declining`, or `:unknown`.
  """
  @spec check_model(String.t(), String.t() | nil) :: :stable | :improving | :declining | :unknown
  def check_model(model, sector_id \\ nil) do
    ops = load_scored_ops(model, sector_id)
    compute_trend(ops)
  rescue
    _ -> :unknown
  end

  @doc """
  Returns all models currently in decline for a sector.

  Each entry has `:model`, `:severity` (`:mild` or `:severe`), and
  the `:metric` that triggered the decline (`:success_rate` or `:quality`).
  """
  @spec declining_models(String.t()) :: [%{model: String.t(), severity: atom(), metric: atom()}]
  def declining_models(sector_id) do
    ops = Archive.filter(:ops, fn op ->
      op.sector_id == sector_id and
        op[:assigned_model] != nil and
        op.status in ["done", "failed"]
    end)

    ops
    |> Enum.group_by(&normalize_model(&1.assigned_model))
    |> Enum.reject(fn {model, _} -> is_nil(model) end)
    |> Enum.flat_map(fn {model, model_ops} ->
      case analyze_decay(model_ops) do
        {:declining, severity, metric} ->
          [%{model: model, severity: severity, metric: metric}]

        _ ->
          []
      end
    end)
  rescue
    _ -> []
  end

  @doc """
  Returns global health status for all models that have been used.

  Maps model names to `:healthy`, `:degraded`, or `:failing`.
  """
  @spec global_health() :: %{String.t() => :healthy | :degraded | :failing}
  def global_health do
    ops =
      Archive.filter(:ops, fn op ->
        op[:assigned_model] != nil and op.status in ["done", "failed"]
      end)

    ops
    |> Enum.group_by(&normalize_model(&1.assigned_model))
    |> Enum.reject(fn {model, _} -> is_nil(model) end)
    |> Map.new(fn {model, model_ops} ->
      status =
        case analyze_decay(model_ops) do
          {:declining, :severe, _} -> :failing
          {:declining, :mild, _} -> :degraded
          _ -> :healthy
        end

      {model, status}
    end)
  rescue
    _ -> %{}
  end

  # -- Private: Analysis -------------------------------------------------------

  defp load_scored_ops(model, nil) do
    Archive.filter(:ops, fn op ->
      normalize_model(op[:assigned_model]) == normalize_model(model) and
        op.status in ["done", "failed"]
    end)
    |> sort_by_time()
  end

  defp load_scored_ops(model, sector_id) do
    Archive.filter(:ops, fn op ->
      op.sector_id == sector_id and
        normalize_model(op[:assigned_model]) == normalize_model(model) and
        op.status in ["done", "failed"]
    end)
    |> sort_by_time()
  end

  defp sort_by_time(ops) do
    Enum.sort_by(ops, &(&1[:created_at] || &1[:inserted_at] || DateTime.utc_now()), {:asc, DateTime})
  end

  defp compute_trend(ops) do
    total = length(ops)
    recent_n = min(10, max(div(total, 3), @min_recent))

    if total - recent_n < @min_baseline or recent_n < @min_recent do
      :unknown
    else
      case analyze_decay(ops) do
        {:declining, _, _} -> :declining
        :improving -> :improving
        _ -> :stable
      end
    end
  end

  defp analyze_decay(ops) do
    now = DateTime.utc_now()
    total = length(ops)
    recent_n = min(10, max(div(total, 3), @min_recent))

    sorted = sort_by_time(ops)
    baseline_ops = Enum.take(sorted, total - recent_n)
    recent_ops = Enum.take(sorted, -recent_n)

    if length(baseline_ops) < @min_baseline or length(recent_ops) < @min_recent do
      :unknown
    else
      baseline_rate = weighted_success_rate(baseline_ops, now)
      recent_rate = weighted_success_rate(recent_ops, now)

      baseline_quality = weighted_avg_quality(baseline_ops, now)
      recent_quality = weighted_avg_quality(recent_ops, now)

      rate_diff = recent_rate - baseline_rate
      quality_diff = if baseline_quality && recent_quality, do: recent_quality - baseline_quality, else: nil

      cond do
        rate_diff < -@severe_rate_threshold ->
          {:declining, :severe, :success_rate}

        quality_diff && quality_diff < -@severe_quality_threshold ->
          {:declining, :severe, :quality}

        rate_diff < -@decline_rate_threshold ->
          {:declining, :mild, :success_rate}

        quality_diff && quality_diff < -@decline_quality_threshold ->
          {:declining, :mild, :quality}

        rate_diff > 0.10 ->
          :improving

        true ->
          :stable
      end
    end
  end

  defp weighted_success_rate(ops, now) do
    {weighted_success, total_weight} =
      Enum.reduce(ops, {0.0, 0.0}, fn op, {ws, tw} ->
        w = time_weight(op, now)
        success = if op.status == "done", do: 1.0, else: 0.0
        {ws + success * w, tw + w}
      end)

    if total_weight > 0, do: weighted_success / total_weight, else: 0.0
  end

  defp weighted_avg_quality(ops, now) do
    quality_ops =
      Enum.filter(ops, &(&1.status == "done" and is_number(&1[:quality_score])))

    if Enum.empty?(quality_ops) do
      nil
    else
      {weighted_sum, total_weight} =
        Enum.reduce(quality_ops, {0.0, 0.0}, fn op, {ws, tw} ->
          w = time_weight(op, now)
          {ws + op.quality_score * w, tw + w}
        end)

      if total_weight > 0, do: weighted_sum / total_weight, else: nil
    end
  end

  defp time_weight(op, now) do
    timestamp = op[:created_at] || op[:inserted_at] || now
    age_hours = DateTime.diff(now, timestamp, :second) / 3600

    cond do
      age_hours < 24 -> 2.0
      age_hours > 168 -> 0.5
      true -> 1.0
    end
  end

  defp normalize_model(nil), do: nil

  defp normalize_model(model) when is_binary(model) do
    model
    |> String.split(":")
    |> List.last()
    |> String.replace("claude-", "")
    |> String.split("-")
    |> hd()
  end

  defp normalize_model(model) when is_atom(model), do: normalize_model(Atom.to_string(model))
end
