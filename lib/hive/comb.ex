defmodule Hive.Comb do
  @moduledoc """
  Context module for managing combs -- the git repositories tracked by a hive.

  A comb can be either a local directory that already exists on disk or a
  remote URL that gets cloned. This module handles registration, lookup,
  and removal of comb records in the database.

  This is a pure context module with no process state. Every function
  transforms input data into a database operation and returns the result.
  """

  import Ecto.Query

  alias Hive.Repo
  alias Hive.Schema.Comb, as: CombSchema

  @doc """
  Registers a comb with the hive.

  For a local path, validates that the directory exists. For a remote URL,
  clones the repository into the hive workspace.

  ## Options

    * `:name` - a human-friendly name. Defaults to the basename of the path or repo URL.

  Returns `{:ok, comb}` or `{:error, changeset | reason}`.
  """
  @spec add(String.t(), keyword()) :: {:ok, CombSchema.t()} | {:error, term()}
  def add(path_or_url, opts \\ []) do
    if Hive.Git.local_path?(path_or_url) do
      add_local(path_or_url, opts)
    else
      add_remote(path_or_url, opts)
    end
  end

  @doc """
  Returns all registered combs.
  """
  @spec list() :: [CombSchema.t()]
  def list do
    Repo.all(CombSchema)
  end

  @doc """
  Finds a comb by name or ID.

  Returns `{:ok, comb}` or `{:error, :not_found}`.
  """
  @spec get(String.t()) :: {:ok, CombSchema.t()} | {:error, :not_found}
  def get(name_or_id) do
    query =
      from(c in CombSchema,
        where: c.name == ^name_or_id or c.id == ^name_or_id,
        limit: 1
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      comb -> {:ok, comb}
    end
  end

  @doc """
  Removes a comb record from the database.

  ## Options

    * `:delete_files` - when `true`, also removes the comb directory from disk.
      Defaults to `false`.

  Returns `{:ok, comb}` or `{:error, :not_found}`.
  """
  @spec remove(String.t(), keyword()) :: {:ok, CombSchema.t()} | {:error, :not_found}
  def remove(name_or_id, opts \\ []) do
    with {:ok, comb} <- get(name_or_id) do
      if Keyword.get(opts, :delete_files, false) && comb.path do
        File.rm_rf(comb.path)
      end

      Repo.delete(comb)
    end
  end

  # -- Private helpers -------------------------------------------------------

  defp add_local(path, opts) do
    expanded = Path.expand(path)

    with :ok <- validate_directory(expanded) do
      name = Keyword.get(opts, :name, Path.basename(expanded))

      attrs = %{
        name: name,
        path: expanded,
        merge_strategy: Keyword.get(opts, :merge_strategy, "manual")
      }

      %CombSchema{}
      |> CombSchema.changeset(attrs)
      |> Repo.insert()
    end
  end

  defp add_remote(url, opts) do
    name = Keyword.get(opts, :name, repo_name_from_url(url))

    with {:ok, hive_root} <- Hive.hive_dir(),
         destination = Path.join([hive_root, ".hive", "combs", name]),
         :ok <- File.mkdir_p(Path.dirname(destination)),
         {:ok, cloned_path} <- Hive.Git.clone(url, destination) do
      attrs = %{
        name: name,
        repo_url: url,
        path: cloned_path,
        merge_strategy: Keyword.get(opts, :merge_strategy, "manual")
      }

      %CombSchema{}
      |> CombSchema.changeset(attrs)
      |> Repo.insert()
    end
  end

  defp validate_directory(path) do
    if File.dir?(path), do: :ok, else: {:error, :path_not_found}
  end

  defp repo_name_from_url(url) do
    url
    |> String.split("/")
    |> List.last()
    |> String.replace(~r/\.git$/, "")
  end
end
