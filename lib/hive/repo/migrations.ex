defmodule Hive.Repo.Migrations do
  @moduledoc "Registry of inline migrations, ordered by version."

  alias Hive.Repo.Migrations.{
    CreateCombs,
    CreateQuests,
    CreateJobs,
    CreateBees,
    CreateWaggles,
    CreateCosts,
    CreateCells,
    AddMergeStrategyToCombs,
    CreateJobDependencies,
    AddValidationToCombs,
    AddGithubToCombs
  }

  @doc "Returns all migrations as `{version, module}` tuples, ordered by version."
  @spec all() :: [{integer(), module()}]
  def all do
    [
      {1, CreateCombs},
      {2, CreateBees},
      {3, CreateQuests},
      {4, CreateJobs},
      {5, CreateWaggles},
      {6, CreateCosts},
      {7, CreateCells},
      {8, AddMergeStrategyToCombs},
      {9, CreateJobDependencies},
      {10, AddValidationToCombs},
      {11, AddGithubToCombs}
    ]
  end
end
