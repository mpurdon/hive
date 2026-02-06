defmodule Hive.Schema.Bee do
  @moduledoc "A bee is a Claude Code agent process working on a job."

  use Ecto.Schema
  import Ecto.Changeset

  alias Hive.Schema.{Cell, Cost, Job}

  @primary_key {:id, :string, autogenerate: false}

  @statuses ~w(starting idle working paused stopped crashed)

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          status: String.t(),
          job_id: String.t() | nil,
          cell_path: String.t() | nil,
          pid: String.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          job: Job.t() | Ecto.Association.NotLoaded.t() | nil,
          cell: Cell.t() | Ecto.Association.NotLoaded.t() | nil,
          costs: [Cost.t()] | Ecto.Association.NotLoaded.t()
        }

  schema "bees" do
    field :name, :string
    field :status, :string, default: "starting"
    field :job_id, :string
    field :cell_path, :string
    field :pid, :string

    has_one :job, Job
    has_one :cell, Cell
    has_many :costs, Cost

    timestamps(type: :utc_datetime)
  end

  @required ~w(name)a
  @optional ~w(status job_id cell_path pid)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(bee \\ %__MODULE__{}, attrs) do
    bee
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, @statuses)
    |> maybe_generate_id()
  end

  defp maybe_generate_id(%{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Hive.ID.generate(:bee))
  end

  defp maybe_generate_id(changeset), do: changeset
end
