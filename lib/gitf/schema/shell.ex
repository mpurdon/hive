defmodule GiTF.Schema.Shell do
  @moduledoc """
  Domain struct for a shell -- an isolated git worktree assigned to a ghost.

  A shell provides a ghost with its own working directory, branch, and
  drift-tracking state so that multiple ghosts can work concurrently
  within the same sector without stepping on each other.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          sector_id: String.t(),
          ghost_id: String.t() | nil,
          worktree_path: String.t() | nil,
          branch: String.t() | nil,
          status: String.t(),
          base_commit_sha: String.t() | nil,
          base_ref: String.t() | nil,
          drift_state: atom(),
          drift_checked_at: DateTime.t() | nil,
          drift_meta: map() | nil,
          removed_at: DateTime.t() | nil,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @enforce_keys [:id, :sector_id]

  defstruct [
    :id,
    :sector_id,
    :ghost_id,
    :worktree_path,
    :branch,
    :base_commit_sha,
    :base_ref,
    :drift_checked_at,
    :drift_meta,
    :removed_at,
    :created_at,
    :updated_at,
    status: "active",
    drift_state: :unknown
  ]

  @required_keys [:sector_id]

  @doc """
  Creates a new shell as a plain map suitable for Archive storage.

  Required: `:sector_id`.
  Returns `{:ok, map}` or `{:error, reason}`.
  """
  @spec new(map()) :: {:ok, map()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    sector_id = attrs[:sector_id] || attrs["sector_id"]

    if is_nil(sector_id) or sector_id == "" do
      {:error, {:missing_fields, @required_keys}}
    else
      {:ok,
       %{
         id: attrs[:id] || attrs["id"],
         sector_id: sector_id,
         ghost_id: attrs[:ghost_id] || attrs["ghost_id"],
         worktree_path: attrs[:worktree_path] || attrs["worktree_path"],
         branch: attrs[:branch] || attrs["branch"],
         status: attrs[:status] || attrs["status"] || "active",
         base_commit_sha: attrs[:base_commit_sha] || attrs["base_commit_sha"],
         base_ref: attrs[:base_ref] || attrs["base_ref"],
         drift_state: attrs[:drift_state] || attrs["drift_state"] || :unknown,
         drift_checked_at: attrs[:drift_checked_at] || attrs["drift_checked_at"],
         drift_meta: attrs[:drift_meta] || attrs["drift_meta"],
         removed_at: attrs[:removed_at] || attrs["removed_at"],
         created_at: attrs[:created_at] || attrs["created_at"],
         updated_at: attrs[:updated_at] || attrs["updated_at"]
       }}
    end
  end

  @doc """
  Converts a raw map (e.g. from Archive) into a `%Shell{}` struct.
  """
  @spec from_map(map()) :: t()
  def from_map(raw) when is_map(raw) do
    %__MODULE__{
      id: raw[:id] || raw["id"],
      sector_id: raw[:sector_id] || raw["sector_id"],
      ghost_id: raw[:ghost_id] || raw["ghost_id"],
      worktree_path: raw[:worktree_path] || raw["worktree_path"],
      branch: raw[:branch] || raw["branch"],
      status: raw[:status] || raw["status"] || "active",
      base_commit_sha: raw[:base_commit_sha] || raw["base_commit_sha"],
      base_ref: raw[:base_ref] || raw["base_ref"],
      drift_state: raw[:drift_state] || raw["drift_state"] || :unknown,
      drift_checked_at: raw[:drift_checked_at] || raw["drift_checked_at"],
      drift_meta: raw[:drift_meta] || raw["drift_meta"],
      removed_at: raw[:removed_at] || raw["removed_at"],
      created_at: raw[:created_at] || raw["created_at"],
      updated_at: raw[:updated_at] || raw["updated_at"]
    }
  end
end
