defmodule Hive.Schema.Comb do
  @moduledoc "A comb represents a git repository tracked by the hive."

  use Ecto.Schema
  import Ecto.Changeset

  alias Hive.Schema.{Cell, Job, Quest}

  @primary_key {:id, :string, autogenerate: false}

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          repo_url: String.t() | nil,
          path: String.t() | nil,
          merge_strategy: String.t(),
          inserted_at: DateTime.t(),
          jobs: [Job.t()] | Ecto.Association.NotLoaded.t(),
          cells: [Cell.t()] | Ecto.Association.NotLoaded.t(),
          quests: [Quest.t()] | Ecto.Association.NotLoaded.t()
        }

  schema "combs" do
    field :name, :string
    field :repo_url, :string
    field :path, :string
    field :merge_strategy, :string, default: "manual"
    field :validation_command, :string
    field :github_owner, :string
    field :github_repo, :string

    has_many :jobs, Job
    has_many :cells, Cell
    has_many :quests, Quest

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required ~w(name)a
  @optional ~w(repo_url path merge_strategy validation_command github_owner github_repo)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(comb \\ %__MODULE__{}, attrs) do
    comb
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:merge_strategy, ~w(manual auto_merge pr_branch))
    |> unique_constraint(:name)
    |> maybe_generate_id()
  end

  defp maybe_generate_id(%{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Hive.ID.generate(:cmb))
  end

  defp maybe_generate_id(changeset), do: changeset
end
