defmodule Hive.Schema.Cell do
  @moduledoc "A cell is a git worktree assigned to a bee for isolated work."

  use Ecto.Schema
  import Ecto.Changeset

  alias Hive.Schema.{Bee, Comb}

  @primary_key {:id, :string, autogenerate: false}

  @statuses ~w(active merged removed)

  @type t :: %__MODULE__{
          id: String.t(),
          bee_id: String.t(),
          comb_id: String.t(),
          worktree_path: String.t(),
          branch: String.t(),
          status: String.t(),
          inserted_at: DateTime.t(),
          removed_at: DateTime.t() | nil,
          bee: Bee.t() | Ecto.Association.NotLoaded.t(),
          comb: Comb.t() | Ecto.Association.NotLoaded.t()
        }

  schema "cells" do
    field :worktree_path, :string
    field :branch, :string
    field :status, :string, default: "active"
    field :removed_at, :utc_datetime

    belongs_to :bee, Bee, type: :string
    belongs_to :comb, Comb, type: :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required ~w(bee_id comb_id worktree_path branch)a
  @optional ~w(status removed_at)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(cell \\ %__MODULE__{}, attrs) do
    cell
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, @statuses)
    |> maybe_generate_id()
  end

  defp maybe_generate_id(%{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Hive.ID.generate(:cel))
  end

  defp maybe_generate_id(changeset), do: changeset
end
