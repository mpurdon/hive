defmodule Hive.Costs do
  @moduledoc """
  Context module for token usage and cost tracking.

  Records per-bee cost data extracted from Claude Code transcripts and
  provides aggregation queries for reporting. Pricing is hardcoded per
  model and applied via `calculate_cost/1`, a pure function.

  This is a context module: no process state, just data transformations
  against the database.
  """

  import Ecto.Query

  alias Hive.Repo
  alias Hive.Schema.Cost

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

  Returns `{:ok, cost}` or `{:error, changeset}`.
  """
  @spec record(String.t(), map()) :: {:ok, Cost.t()} | {:error, Ecto.Changeset.t()}
  def record(bee_id, attrs) do
    attrs =
      attrs
      |> Map.put(:bee_id, bee_id)
      |> maybe_set_recorded_at()
      |> maybe_calculate_cost()

    case %Cost{} |> Cost.changeset(attrs) |> Repo.insert() do
      {:ok, cost} ->
        broadcast_cost_update(cost)
        {:ok, cost}

      error ->
        error
    end
  end

  @doc """
  Returns all cost records for a given bee.
  """
  @spec for_bee(String.t()) :: [Cost.t()]
  def for_bee(bee_id) do
    Cost
    |> where([c], c.bee_id == ^bee_id)
    |> order_by([c], desc: c.recorded_at)
    |> Repo.all()
  end

  @doc """
  Returns all cost records for bees participating in a quest.

  Joins costs through jobs to find bees assigned to the given quest.
  """
  @spec for_quest(String.t()) :: [Cost.t()]
  def for_quest(quest_id) do
    # Find bee_ids that worked on this quest's jobs, then fetch their costs.
    # Two-step approach avoids SQLite's lack of multi-column DISTINCT.
    bee_ids =
      from(j in Hive.Schema.Job,
        where: j.quest_id == ^quest_id and not is_nil(j.bee_id),
        select: j.bee_id,
        group_by: j.bee_id
      )
      |> Repo.all()

    case bee_ids do
      [] ->
        []

      ids ->
        from(c in Cost,
          where: c.bee_id in ^ids,
          order_by: [desc: c.recorded_at]
        )
        |> Repo.all()
    end
  end

  @doc """
  Sums the `cost_usd` field across a list of cost records.
  """
  @spec total([Cost.t()]) :: float()
  def total(costs) do
    costs
    |> Enum.reduce(0.0, fn c, acc -> acc + c.cost_usd end)
    |> Float.round(6)
  end

  @doc """
  Returns an aggregate summary of all recorded costs.

  Returns a map with:
    * `:total_cost` - sum of all cost_usd
    * `:total_input_tokens` - sum of input tokens
    * `:total_output_tokens` - sum of output tokens
    * `:by_model` - costs grouped by model name
    * `:by_bee` - costs grouped by bee_id
  """
  @spec summary() :: map()
  def summary do
    costs = Repo.all(Cost)

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

  This is a pure function -- no database access. Takes a map with
  `:input_tokens`, `:output_tokens`, and optionally `:cache_read_tokens`,
  `:cache_write_tokens`, `:model`.

  Returns the cost in USD as a float.
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
