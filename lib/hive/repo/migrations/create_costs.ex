defmodule Hive.Repo.Migrations.CreateCosts do
  use Ecto.Migration

  def change do
    create table(:costs, primary_key: false) do
      add :id, :string, primary_key: true
      add :bee_id, references(:bees, type: :string, on_delete: :delete_all), null: false
      add :input_tokens, :integer, null: false
      add :output_tokens, :integer, null: false
      add :cache_read_tokens, :integer, default: 0, null: false
      add :cache_write_tokens, :integer, default: 0, null: false
      add :cost_usd, :float, null: false
      add :model, :string
      add :recorded_at, :utc_datetime, null: false
    end
  end
end
