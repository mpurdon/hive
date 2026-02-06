defmodule Hive.Repo.Migrations.CreateWaggles do
  use Ecto.Migration

  def change do
    create table(:waggles, primary_key: false) do
      add :id, :string, primary_key: true
      add :from, :string, null: false
      add :to, :string, null: false
      add :subject, :string
      add :body, :text
      add :read, :boolean, default: false, null: false
      add :metadata, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end
  end
end
