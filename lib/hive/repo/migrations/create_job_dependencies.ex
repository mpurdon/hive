defmodule Hive.Repo.Migrations.CreateJobDependencies do
  use Ecto.Migration

  def change do
    create table(:job_dependencies, primary_key: false) do
      add :id, :string, primary_key: true
      add :job_id, references(:jobs, type: :string, on_delete: :delete_all), null: false
      add :depends_on_id, references(:jobs, type: :string, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:job_dependencies, [:job_id, :depends_on_id])
  end
end
