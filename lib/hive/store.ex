defmodule Hive.Store do
  @moduledoc """
  Pure-Elixir key-value store backed by CubDB.

  Provides a Repo-like CRUD interface for Hive entities using plain maps
  instead of Ecto schemas. Data is stored as `{:collection, "id"}` => map.

  CubDB data directory: `.hive/store/`
  """

  use GenServer

  @name __MODULE__

  # -- Client API ------------------------------------------------------------

  @doc "Starts the store, opening the CubDB data directory at `data_dir`."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Inserts a record into a collection. Generates an `:id` if missing."
  @spec insert(atom(), map()) :: {:ok, map()}
  def insert(collection, record) do
    record = ensure_id(collection, record)
    record = ensure_timestamps(record)
    key = {collection, record.id}
    CubDB.put(db(), key, record)
    {:ok, record}
  end

  @doc "Gets a record by ID. Returns the record or nil."
  @spec get(atom(), String.t()) :: map() | nil
  def get(collection, id) do
    CubDB.get(db(), {collection, id})
  end

  @doc "Fetches a record by ID. Returns `{:ok, record}` or `{:error, :not_found}`."
  @spec fetch(atom(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def fetch(collection, id) do
    case get(collection, id) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end

  @doc "Overwrites a record in the collection."
  @spec put(atom(), map()) :: {:ok, map()}
  def put(collection, record) do
    record = ensure_updated_at(record)
    key = {collection, record.id}
    CubDB.put(db(), key, record)
    {:ok, record}
  end

  @doc "Deletes a record by collection and ID."
  @spec delete(atom(), String.t()) :: :ok
  def delete(collection, id) do
    CubDB.delete(db(), {collection, id})
    :ok
  end

  @doc "Returns all records in a collection."
  @spec all(atom()) :: [map()]
  def all(collection) do
    db()
    |> CubDB.select(min_key: {collection, ""}, max_key: {collection, "~"})
    |> Enum.map(fn {_key, value} -> value end)
  end

  @doc "Returns records matching a filter function."
  @spec filter(atom(), (map() -> boolean())) :: [map()]
  def filter(collection, fun) do
    all(collection) |> Enum.filter(fun)
  end

  @doc "Returns the first record matching a filter function, or nil."
  @spec find_one(atom(), (map() -> boolean())) :: map() | nil
  def find_one(collection, fun) do
    all(collection) |> Enum.find(fun)
  end

  @doc "Counts records in a collection."
  @spec count(atom()) :: non_neg_integer()
  def count(collection) do
    all(collection) |> length()
  end

  @doc "Counts records matching a filter function."
  @spec count(atom(), (map() -> boolean())) :: non_neg_integer()
  def count(collection, fun) do
    filter(collection, fun) |> length()
  end

  @doc "Updates all matching records with an update function. Returns count updated."
  @spec update_matching(atom(), (map() -> boolean()), (map() -> map())) :: non_neg_integer()
  def update_matching(collection, filter_fun, update_fun) do
    records = filter(collection, filter_fun)

    Enum.each(records, fn record ->
      updated = update_fun.(record) |> ensure_updated_at()
      CubDB.put(db(), {collection, record.id}, updated)
    end)

    length(records)
  end

  # -- GenServer callbacks ---------------------------------------------------

  @impl true
  def init(opts) do
    data_dir = Keyword.fetch!(opts, :data_dir)
    File.mkdir_p!(data_dir)

    case CubDB.start_link(data_dir: data_dir, name: Hive.Store.DB) do
      {:ok, _pid} -> {:ok, %{data_dir: data_dir}}
      {:error, {:already_started, _pid}} -> {:ok, %{data_dir: data_dir}}
      {:error, reason} -> {:stop, reason}
    end
  end

  # -- Private helpers -------------------------------------------------------

  defp db, do: Hive.Store.DB

  defp ensure_id(_collection, %{id: id} = record) when is_binary(id) and id != "" do
    record
  end

  defp ensure_id(collection, record) do
    prefix = collection_prefix(collection)
    Map.put(record, :id, Hive.ID.generate(prefix))
  end

  defp collection_prefix(:combs), do: :cmb
  defp collection_prefix(:bees), do: :bee
  defp collection_prefix(:jobs), do: :job
  defp collection_prefix(:quests), do: :qst
  defp collection_prefix(:waggles), do: :wag
  defp collection_prefix(:costs), do: :cst
  defp collection_prefix(:cells), do: :cel
  defp collection_prefix(:job_dependencies), do: :jdp
  defp collection_prefix(_), do: :hiv

  defp ensure_timestamps(record) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    record
    |> Map.put_new(:inserted_at, now)
    |> Map.put_new(:updated_at, now)
  end

  defp ensure_updated_at(record) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Map.put(record, :updated_at, now)
  end
end
