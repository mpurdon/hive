defmodule Hive.Repo.Migrations.AddGithubToCombs do
  use Ecto.Migration

  def change do
    alter table(:combs) do
      add :github_owner, :string
      add :github_repo, :string
    end
  end
end
