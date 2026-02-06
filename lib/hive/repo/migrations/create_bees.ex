defmodule Hive.Repo.Migrations.CreateBees do
  use Ecto.Migration

  def change do
    create table(:bees, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :status, :string, default: "starting", null: false
      add :job_id, :string
      add :cell_path, :string
      add :pid, :string

      timestamps(type: :utc_datetime)
    end
  end
end
