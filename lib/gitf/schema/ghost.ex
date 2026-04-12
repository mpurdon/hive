defmodule GiTF.Schema.Ghost do
  @moduledoc """
  Domain struct for a ghost -- an autonomous agent working on an op.

  A ghost is spawned to execute an op within a shell (git worktree).
  It tracks the assigned model, context window usage, and runtime status.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          op_id: String.t(),
          assigned_model: String.t() | nil,
          status: String.t(),
          context_percentage: float(),
          context_tokens_used: non_neg_integer(),
          context_tokens_limit: non_neg_integer() | nil,
          context_peak_percentage: float(),
          shell_path: String.t() | nil,
          sector_id: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @enforce_keys [:id, :op_id]

  defstruct [
    :id,
    :name,
    :op_id,
    :assigned_model,
    :shell_path,
    :sector_id,
    :context_tokens_limit,
    :inserted_at,
    :updated_at,
    status: "starting",
    context_percentage: 0.0,
    context_tokens_used: 0,
    context_peak_percentage: 0.0
  ]

  @required_keys [:op_id]

  @doc """
  Creates a new ghost as a plain map suitable for Archive storage.

  Required: `:op_id`.
  Returns `{:ok, map}` or `{:error, reason}`.
  """
  @spec new(map()) :: {:ok, map()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    op_id = attrs[:op_id] || attrs["op_id"]

    if is_nil(op_id) or op_id == "" do
      {:error, {:missing_fields, @required_keys}}
    else
      {:ok,
       %{
         id: attrs[:id] || attrs["id"],
         name: attrs[:name] || attrs["name"],
         op_id: op_id,
         assigned_model: attrs[:assigned_model] || attrs["assigned_model"],
         status: attrs[:status] || attrs["status"] || "starting",
         context_percentage: attrs[:context_percentage] || attrs["context_percentage"] || 0.0,
         context_tokens_used: attrs[:context_tokens_used] || attrs["context_tokens_used"] || 0,
         context_tokens_limit: attrs[:context_tokens_limit] || attrs["context_tokens_limit"],
         context_peak_percentage: attrs[:context_peak_percentage] || attrs["context_peak_percentage"] || 0.0,
         shell_path: attrs[:shell_path] || attrs["shell_path"],
         sector_id: attrs[:sector_id] || attrs["sector_id"]
       }}
    end
  end

  @doc """
  Converts a raw map (e.g. from Archive) into a `%Ghost{}` struct.
  """
  @spec from_map(map()) :: t()
  def from_map(raw) when is_map(raw) do
    %__MODULE__{
      id: raw[:id] || raw["id"],
      name: raw[:name] || raw["name"],
      op_id: raw[:op_id] || raw["op_id"],
      assigned_model: raw[:assigned_model] || raw["assigned_model"],
      status: raw[:status] || raw["status"] || "starting",
      context_percentage: raw[:context_percentage] || raw["context_percentage"] || 0.0,
      context_tokens_used: raw[:context_tokens_used] || raw["context_tokens_used"] || 0,
      context_tokens_limit: raw[:context_tokens_limit] || raw["context_tokens_limit"],
      context_peak_percentage: raw[:context_peak_percentage] || raw["context_peak_percentage"] || 0.0,
      shell_path: raw[:shell_path] || raw["shell_path"],
      sector_id: raw[:sector_id] || raw["sector_id"],
      inserted_at: raw[:inserted_at] || raw["inserted_at"],
      updated_at: raw[:updated_at] || raw["updated_at"]
    }
  end
end
