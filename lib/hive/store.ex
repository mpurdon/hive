defmodule Hive.Store do
  @moduledoc """
  Pure-Elixir key-value store backed by an ETF (Erlang Term Format) file.

  Provides a Repo-like CRUD interface for Hive entities using plain maps.
  Data is stored as a single `.hive/store/hive.etf` file.

  Concurrent cross-process safety is achieved via:
  - `mkdir`-based advisory locking (POSIX `mkdir` is atomic)
  - Atomic `rename(2)` for writes (write to `.tmp`, rename into place)
  - Lock-free reads (readers always see a complete, consistent snapshot)
  """

  use GenServer

  @name __MODULE__
  @lock_stale_seconds 5

  # -- Client API ------------------------------------------------------------

  @doc "Starts the store, creating the data directory at `data_dir`."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Inserts a record into a collection. Generates an `:id` if missing."
  @spec insert(atom(), map()) :: {:ok, map()}
  def insert(collection, record) do
    record = ensure_id(collection, record)
    record = ensure_timestamps(record)

    with_lock(fn data ->
      col = Map.get(data, collection, %{})
      col = Map.put(col, record.id, record)
      Map.put(data, collection, col)
    end)

    {:ok, record}
  end

  @doc "Gets a record by ID. Returns the record or nil."
  @spec get(atom(), String.t()) :: map() | nil
  def get(collection, id) do
    data = read_data()
    get_in(data, [collection, id])
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

    with_lock(fn data ->
      col = Map.get(data, collection, %{})
      col = Map.put(col, record.id, record)
      Map.put(data, collection, col)
    end)

    {:ok, record}
  end

  @doc "Deletes a record by collection and ID."
  @spec delete(atom(), String.t()) :: :ok
  def delete(collection, id) do
    with_lock(fn data ->
      col = Map.get(data, collection, %{})
      col = Map.delete(col, id)
      Map.put(data, collection, col)
    end)

    :ok
  end

  @doc "Returns all records in a collection."
  @spec all(atom()) :: [map()]
  def all(collection) do
    data = read_data()
    data |> Map.get(collection, %{}) |> Map.values()
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
    # Read current data to find matching records
    matching = filter(collection, filter_fun)
    count = length(matching)

    if count > 0 do
      with_lock(fn data ->
        col = Map.get(data, collection, %{})

        updated_col =
          Enum.reduce(matching, col, fn record, acc ->
            updated = update_fun.(record) |> ensure_updated_at()
            Map.put(acc, record.id, updated)
          end)

        Map.put(data, collection, updated_col)
      end)
    end

    count
  end

  # -- GenServer callbacks ---------------------------------------------------

  @impl true
  def init(opts) do
    data_dir = Keyword.fetch!(opts, :data_dir)
    File.mkdir_p!(data_dir)

    data_path = Path.join(data_dir, "hive.etf")
    lock_path = Path.join(data_dir, ".lock")

    # Store paths in persistent_term so API functions can access them
    # without going through the GenServer process
    :persistent_term.put({__MODULE__, :data_path}, data_path)
    :persistent_term.put({__MODULE__, :lock_path}, lock_path)

    {:ok, %{data_dir: data_dir, data_path: data_path, lock_path: lock_path}}
  end

  # -- File I/O (lock-free reads, mkdir-locked writes) -----------------------

  defp data_path, do: :persistent_term.get({__MODULE__, :data_path})
  defp lock_path, do: :persistent_term.get({__MODULE__, :lock_path})

  defp read_data do
    case File.read(data_path()) do
      {:ok, binary} -> :erlang.binary_to_term(binary, [:safe])
      {:error, :enoent} -> %{}
    end
  end

  defp write_data(data) do
    path = data_path()
    tmp_path = path <> ".tmp"
    binary = :erlang.term_to_binary(data)
    File.write!(tmp_path, binary)
    File.rename!(tmp_path, path)
  end

  defp with_lock(mutate_fn) do
    acquire_lock()

    try do
      data = read_data()
      new_data = mutate_fn.(data)
      write_data(new_data)
    after
      release_lock()
    end
  end

  defp acquire_lock, do: acquire_lock(0)

  defp acquire_lock(attempts) do
    lock = lock_path()

    case File.mkdir(lock) do
      :ok ->
        :ok

      {:error, :eexist} ->
        if lock_stale?(lock) do
          # Stale lock from a crashed process — steal it
          File.rmdir(lock)
          acquire_lock(attempts)
        else
          if attempts >= 200 do
            # ~2s of waiting (200 * 10ms) — force steal
            File.rmdir(lock)
            acquire_lock(0)
          else
            Process.sleep(10)
            acquire_lock(attempts + 1)
          end
        end
    end
  end

  defp release_lock do
    File.rmdir(lock_path())
  end

  defp lock_stale?(lock_path) do
    case File.stat(lock_path) do
      {:ok, %{mtime: mtime}} ->
        lock_time = NaiveDateTime.from_erl!(mtime)
        now = NaiveDateTime.utc_now()
        NaiveDateTime.diff(now, lock_time, :second) > @lock_stale_seconds

      {:error, _} ->
        # Lock disappeared between check and stat — not stale
        false
    end
  end

  # -- Private helpers -------------------------------------------------------

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
