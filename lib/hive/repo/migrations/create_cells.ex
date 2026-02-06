defmodule Hive.Repo.Migrations.CreateCells do
  use Ecto.Migration

  def change do
    create table(:cells, primary_key: false) do
      add :id, :string, primary_key: true
      add :bee_id, references(:bees, type: :string, on_delete: :nilify_all), null: false
      add :comb_id, references(:combs, type: :string, on_delete: :delete_all), null: false
      add :worktree_path, :string, null: false
      add :branch, :string, null: false
      add :status, :string, default: "active", null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    alter table(:cells) do
      add :removed_at, :utc_datetime
    end
  end
end
