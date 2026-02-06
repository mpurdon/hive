defmodule Hive.Repo do
  @moduledoc "SQLite3-backed Ecto repository for Hive state persistence."

  use Ecto.Repo,
    otp_app: :hive,
    adapter: Ecto.Adapters.SQLite3

  alias Hive.Repo.Migrations

  @doc """
  Accepts runtime configuration, allowing the database path to be set
  dynamically (e.g. from the `.hive/` directory discovered at runtime).
  """
  @impl true
  def init(_type, config) do
    {:ok, config}
  end

  @doc """
  Runs all inline migrations forward. Intended for escript usage where
  file-based migrations are unavailable.
  """
  @spec ensure_migrated!() :: :ok
  def ensure_migrated! do
    Ecto.Migrator.run(__MODULE__, Migrations.all(), :up, all: true)
    :ok
  end
end
