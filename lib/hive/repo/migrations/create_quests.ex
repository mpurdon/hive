defmodule Hive.Repo.Migrations.CreateQuests do
  use Ecto.Migration

  def change do
    create table(:quests, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :status, :string, default: "pending", null: false
      add :comb_id, references(:combs, type: :string, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end
  end
end
