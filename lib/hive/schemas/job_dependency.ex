defmodule Hive.Schema.JobDependency do
  @moduledoc "Links two jobs in a dependency relationship (job depends on depends_on)."

  use Ecto.Schema
  import Ecto.Changeset

  alias Hive.Schema.Job

  @primary_key {:id, :string, autogenerate: false}

  @type t :: %__MODULE__{
          id: String.t(),
          job_id: String.t(),
          depends_on_id: String.t(),
          inserted_at: DateTime.t()
        }

  schema "job_dependencies" do
    belongs_to :job, Job, type: :string
    belongs_to :depends_on, Job, type: :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required ~w(job_id depends_on_id)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(dep \\ %__MODULE__{}, attrs) do
    dep
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> unique_constraint([:job_id, :depends_on_id])
    |> maybe_generate_id()
  end

  defp maybe_generate_id(%{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Hive.ID.generate(:jdp))
  end

  defp maybe_generate_id(changeset), do: changeset
end
