defmodule Hive.Repo.Migrations.AddMergeStrategyToCombs do
  use Ecto.Migration

  def change do
    alter table(:combs) do
      add :merge_strategy, :string, default: "manual"
    end
  end
end
