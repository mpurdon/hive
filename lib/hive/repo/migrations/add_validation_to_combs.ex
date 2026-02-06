defmodule Hive.Repo.Migrations.AddValidationToCombs do
  use Ecto.Migration

  def change do
    alter table(:combs) do
      add :validation_command, :string
    end
  end
end
