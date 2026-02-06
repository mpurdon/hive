defmodule Hive.Schema.Job do
  @moduledoc "A job is a unit of work assigned to a bee within a quest."

  use Ecto.Schema
  import Ecto.Changeset

  alias Hive.Schema.{Bee, Comb, JobDependency, Quest}

  @primary_key {:id, :string, autogenerate: false}

  @statuses ~w(pending assigned running done failed blocked)

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          description: String.t() | nil,
          status: String.t(),
          quest_id: String.t(),
          bee_id: String.t() | nil,
          comb_id: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          quest: Quest.t() | Ecto.Association.NotLoaded.t(),
          bee: Bee.t() | Ecto.Association.NotLoaded.t() | nil,
          comb: Comb.t() | Ecto.Association.NotLoaded.t()
        }

  schema "jobs" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "pending"

    belongs_to :quest, Quest, type: :string
    belongs_to :bee, Bee, type: :string
    belongs_to :comb, Comb, type: :string

    has_many :dependencies, JobDependency, foreign_key: :job_id
    has_many :dependents, JobDependency, foreign_key: :depends_on_id

    timestamps(type: :utc_datetime)
  end

  @required ~w(title quest_id comb_id)a
  @optional ~w(description status bee_id)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(job \\ %__MODULE__{}, attrs) do
    job
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, @statuses)
    |> maybe_generate_id()
  end

  defp maybe_generate_id(%{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Hive.ID.generate(:job))
  end

  defp maybe_generate_id(changeset), do: changeset
end
