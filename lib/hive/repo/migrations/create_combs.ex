defmodule Hive.Repo.Migrations.CreateCombs do
  use Ecto.Migration

  def change do
    create table(:combs, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :repo_url, :string
      add :path, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:combs, [:name])
  end
end
