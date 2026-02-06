defmodule Hive.BudgetTest do
  use ExUnit.Case, async: false

  alias Hive.{Budget, Costs, Jobs, Repo}
  alias Hive.Schema.{Bee, Comb, Quest}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    {:ok, comb} =
      %Comb{}
      |> Comb.changeset(%{name: "budget-comb-#{:erlang.unique_integer([:positive])}"})
      |> Repo.insert()

    {:ok, quest} =
      %Quest{}
      |> Quest.changeset(%{name: "budget-quest-#{:erlang.unique_integer([:positive])}"})
      |> Repo.insert()

    {:ok, bee} =
      %Bee{}
      |> Bee.changeset(%{name: "budget-bee-#{:erlang.unique_integer([:positive])}"})
      |> Repo.insert()

    {:ok, job} =
      Jobs.create(%{title: "budget job", quest_id: quest.id, comb_id: comb.id})

    {:ok, _} = Jobs.assign(job.id, bee.id)

    %{comb: comb, quest: quest, bee: bee, job: job}
  end

  describe "spent_for/1" do
    test "returns 0 when no costs recorded", %{quest: quest} do
      assert Budget.spent_for(quest.id) == 0.0
    end

    test "sums costs for quest's bees", %{quest: quest, bee: bee} do
      {:ok, _} = Costs.record(bee.id, %{input_tokens: 1000, output_tokens: 500, model: "claude-sonnet-4-20250514"})

      spent = Budget.spent_for(quest.id)
      assert spent > 0.0
    end
  end

  describe "check/1" do
    test "returns ok with remaining when under budget", %{quest: quest} do
      assert {:ok, remaining} = Budget.check(quest.id)
      assert remaining > 0
    end

    test "returns error when budget exceeded", %{quest: quest, bee: bee} do
      # Record a huge cost to exceed budget
      {:ok, _} = Costs.record(bee.id, %{input_tokens: 0, output_tokens: 0, cost_usd: 999.0})

      assert {:error, :budget_exceeded, spent} = Budget.check(quest.id)
      assert spent >= 999.0
    end
  end

  describe "exceeded?/1" do
    test "returns false when under budget", %{quest: quest} do
      assert Budget.exceeded?(quest.id) == false
    end

    test "returns true when over budget", %{quest: quest, bee: bee} do
      {:ok, _} = Costs.record(bee.id, %{input_tokens: 0, output_tokens: 0, cost_usd: 999.0})
      assert Budget.exceeded?(quest.id) == true
    end
  end

  describe "remaining/1" do
    test "returns full budget when nothing spent", %{quest: quest} do
      remaining = Budget.remaining(quest.id)
      assert remaining == Budget.budget_for(quest.id)
    end
  end
end
