defmodule Hive.Queen.Audit do
  @moduledoc """
  File access auditing for the Queen process.

  The Queen should only coordinate -- she must not write code or modify
  files outside her workspace. This module provides path-checking utilities
  that enforce those boundaries.

  All functions are pure (no GenServer, no state). They normalize paths
  via `Path.expand/1` to prevent `../` traversal attacks and return
  tagged tuples so callers can decide how to respond.
  """

  require Logger

  @doc """
  Checks whether `path` is inside the hive directory.

  Returns `:ok` if the path is within the `.hive/` directory rooted at
  `hive_root`, or `{:error, :delegation_required}` if it falls outside.

  ## Examples

      iex> Hive.Queen.Audit.check_file_access("/project/.hive/queen/notes.md", "/project")
      :ok

      iex> Hive.Queen.Audit.check_file_access("/project/src/app.ex", "/project")
      {:error, :delegation_required}
  """
  @spec check_file_access(String.t(), String.t()) :: :ok | {:error, :delegation_required}
  def check_file_access(path, hive_root) do
    hive_dir = Path.join(Path.expand(hive_root), ".hive")
    expanded = Path.expand(path)

    if inside_hive_dir?(expanded, hive_dir) do
      :ok
    else
      Logger.warning("Queen file access outside .hive/: #{expanded}")
      {:error, :delegation_required}
    end
  end

  @doc """
  Returns `true` if `expanded_path` is inside `hive_dir`.

  Both paths should already be expanded (absolute, no `..`).
  Public for testability.

  ## Examples

      iex> Hive.Queen.Audit.inside_hive_dir?("/project/.hive/queen/QUEEN.md", "/project/.hive")
      true

      iex> Hive.Queen.Audit.inside_hive_dir?("/project/src/app.ex", "/project/.hive")
      false
  """
  @spec inside_hive_dir?(String.t(), String.t()) :: boolean()
  def inside_hive_dir?(expanded_path, hive_dir) do
    # Ensure hive_dir ends with "/" for prefix matching
    normalized_dir = String.trim_trailing(hive_dir, "/") <> "/"

    expanded_path == hive_dir or String.starts_with?(expanded_path, normalized_dir)
  end
end
