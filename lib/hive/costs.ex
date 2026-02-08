defmodule Hive.Costs do
  @moduledoc """
  Context module for token usage and cost tracking.

  Records per-bee cost data extracted from Claude Code transcripts and
  provides aggregation queries for reporting.
  """

  alias Hive.Store

  # -- Pricing tables (USD per million tokens) ---------------------------------

  @pricing %{
    "claude-sonnet-4-20250514" => %{
      input: 3.0,
      output: 15.0,
      cache_read: 0.30,
      cache_write: 3.75
    },
    "claude-opus-4-20250514" => %{
      input: 15.0,
      output: 75.0,
      cache_read: 1.50,
      cache_write: 18.75
    }
  }

  @default_model "claude-sonnet-4-20250514"

  # -- Public API --------------------------------------------------------------

  @doc """
  Records a cost entry for a bee.

  Automatically calculates `cost_usd` from token counts and model if not
  already provided. Sets `recorded_at` to now if not provided.

  Returns `{:ok, cost}` or `{:error, reason}`.
  """
  @spec record(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def record(bee_id, attrs) do
    attrs =
      attrs
      |> Map.put(:bee_id, bee_id)
      |> maybe_set_recorded_at()
      |> maybe_calculate_cost()

    record = %{
      bee_id: attrs[:bee_id],
      input_tokens: attrs[:input_tokens] || 0,
      output_tokens: attrs[:output_tokens] || 0,
      cache_read_tokens: attrs[:cache_read_tokens] || 0,
      cache_write_tokens: attrs[:cache_write_tokens] || 0,
      cost_usd: attrs[:cost_usd],
      model: attrs[:model],
      recorded_at: attrs[:recorded_at]
    }

    {:ok, cost} = Store.insert(:costs, record)
    broadcast_cost_update(cost)
    {:ok, cost}
  end

  @doc "Returns all cost records for a given bee."
  @spec for_bee(String.t()) :: [map()]
  def for_bee(bee_id) do
    Store.filter(:costs, fn c -> c.bee_id == bee_id end)
    |> Enum.sort_by(& &1.recorded_at, {:desc, DateTime})
  end

  @doc """
  Returns all cost records for bees participating in a quest.
  """
  @spec for_quest(String.t()) :: [map()]
  def for_quest(quest_id) do
    bee_ids =
      Hive.Jobs.list(quest_id: quest_id)
      |> Enum.map(& &1.bee_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    case bee_ids do
      [] ->
        []

      ids ->
        Store.filter(:costs, fn c -> c.bee_id in ids end)
        |> Enum.sort_by(& &1.recorded_at, {:desc, DateTime})
    end
  end

  @doc "Sums the `cost_usd` field across a list of cost records."
  @spec total([map()]) :: float()
  def total(costs) do
    costs
    |> Enum.reduce(0.0, fn c, acc -> acc + c.cost_usd end)
    |> Float.round(6)
  end

  @doc """
  Returns an aggregate summary of all recorded costs.
  """
  @spec summary() :: map()
  def summary do
    costs = Store.all(:costs)

    %{
      total_cost: total(costs),
      total_input_tokens: costs |> Enum.map(& &1.input_tokens) |> Enum.sum(),
      total_output_tokens: costs |> Enum.map(& &1.output_tokens) |> Enum.sum(),
      by_model: group_costs_by(costs, & &1.model),
      by_bee: group_costs_by(costs, & &1.bee_id)
    }
  end

  @doc """
  Calculates the USD cost from token counts and model.
  Pure function -- no store access.
  """
  @spec calculate_cost(map()) :: float()
  def calculate_cost(attrs) do
    model = Map.get(attrs, :model) || Map.get(attrs, "model") || @default_model
    prices = Map.get(@pricing, model, @pricing[@default_model])

    input = token_count(attrs, :input_tokens) * prices.input
    output = token_count(attrs, :output_tokens) * prices.output
    cache_read = token_count(attrs, :cache_read_tokens) * prices.cache_read
    cache_write = token_count(attrs, :cache_write_tokens) * prices.cache_write

    ((input + output + cache_read + cache_write) / 1_000_000)
    |> Float.round(6)
  end

  # -- Private helpers ---------------------------------------------------------

  defp broadcast_cost_update(cost) do
    Phoenix.PubSub.broadcast(Hive.PubSub, "hive:costs", {:cost_recorded, cost})
  rescue
    _ -> :ok
  end

  defp maybe_set_recorded_at(%{recorded_at: _} = attrs), do: attrs

  defp maybe_set_recorded_at(attrs) do
    Map.put(attrs, :recorded_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp maybe_calculate_cost(%{cost_usd: _} = attrs), do: attrs

  defp maybe_calculate_cost(attrs) do
    Map.put(attrs, :cost_usd, calculate_cost(attrs))
  end

  defp token_count(attrs, key) do
    string_key = Atom.to_string(key)
    (Map.get(attrs, key) || Map.get(attrs, string_key) || 0) * 1.0
  end

  defp group_costs_by(costs, key_fn) do
    costs
    |> Enum.group_by(key_fn)
    |> Map.new(fn {key, group} ->
      {key || "unknown",
       %{
         cost: total(group),
         input_tokens: Enum.reduce(group, 0, fn c, acc -> acc + c.input_tokens end),
         output_tokens: Enum.reduce(group, 0, fn c, acc -> acc + c.output_tokens end)
       }}
    end)
  end
end
