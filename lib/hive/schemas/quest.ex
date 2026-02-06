defmodule Hive.Schema.Quest do
  @moduledoc "A quest is a high-level objective decomposed into jobs."

  use Ecto.Schema
  import Ecto.Changeset

  alias Hive.Schema.{Comb, Job}

  @primary_key {:id, :string, autogenerate: false}

  @statuses ~w(pending active completed failed cancelled)

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          status: String.t(),
          comb_id: String.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          comb: Comb.t() | Ecto.Association.NotLoaded.t() | nil,
          jobs: [Job.t()] | Ecto.Association.NotLoaded.t()
        }

  schema "quests" do
    field :name, :string
    field :status, :string, default: "pending"

    belongs_to :comb, Comb, type: :string
    has_many :jobs, Job

    timestamps(type: :utc_datetime)
  end

  @required ~w(name)a
  @optional ~w(status comb_id)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(quest \\ %__MODULE__{}, attrs) do
    quest
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, @statuses)
    |> maybe_generate_id()
  end

  defp maybe_generate_id(%{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Hive.ID.generate(:qst))
  end

  defp maybe_generate_id(changeset), do: changeset
end
