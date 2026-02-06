defmodule Hive.Schema.Waggle do
  @moduledoc "A waggle is an inter-agent message passed between bees."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}

  @type t :: %__MODULE__{
          id: String.t(),
          from: String.t(),
          to: String.t(),
          subject: String.t() | nil,
          body: String.t() | nil,
          read: boolean(),
          metadata: String.t() | nil,
          inserted_at: DateTime.t()
        }

  schema "waggles" do
    field :from, :string
    field :to, :string
    field :subject, :string
    field :body, :string
    field :read, :boolean, default: false
    field :metadata, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required ~w(from to)a
  @optional ~w(subject body read metadata)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(waggle \\ %__MODULE__{}, attrs) do
    waggle
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> maybe_generate_id()
  end

  defp maybe_generate_id(%{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Hive.ID.generate(:wag))
  end

  defp maybe_generate_id(changeset), do: changeset
end
