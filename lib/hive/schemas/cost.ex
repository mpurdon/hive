defmodule Hive.Schema.Cost do
  @moduledoc "Tracks token usage and dollar cost for a single bee interaction."

  use Ecto.Schema
  import Ecto.Changeset

  alias Hive.Schema.Bee

  @primary_key {:id, :string, autogenerate: false}

  @type t :: %__MODULE__{
          id: String.t(),
          bee_id: String.t(),
          input_tokens: integer(),
          output_tokens: integer(),
          cache_read_tokens: integer(),
          cache_write_tokens: integer(),
          cost_usd: float(),
          model: String.t() | nil,
          recorded_at: DateTime.t(),
          bee: Bee.t() | Ecto.Association.NotLoaded.t()
        }

  schema "costs" do
    field :input_tokens, :integer
    field :output_tokens, :integer
    field :cache_read_tokens, :integer, default: 0
    field :cache_write_tokens, :integer, default: 0
    field :cost_usd, :float
    field :model, :string
    field :recorded_at, :utc_datetime

    belongs_to :bee, Bee, type: :string
  end

  @required ~w(bee_id input_tokens output_tokens cost_usd recorded_at)a
  @optional ~w(cache_read_tokens cache_write_tokens model)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(cost \\ %__MODULE__{}, attrs) do
    cost
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:input_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:output_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:cost_usd, greater_than_or_equal_to: 0.0)
    |> maybe_generate_id()
  end

  defp maybe_generate_id(%{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Hive.ID.generate(:cst))
  end

  defp maybe_generate_id(changeset), do: changeset
end
