defmodule Hive.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs, primary_key: false) do
      add :id, :string, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :status, :string, default: "pending", null: false
      add :quest_id, references(:quests, type: :string, on_delete: :delete_all), null: false
      add :bee_id, references(:bees, type: :string, on_delete: :nilify_all)
      add :comb_id, references(:combs, type: :string, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end
  end
end
