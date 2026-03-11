defmodule GiTF.Major.Audit do
  @moduledoc """
  File access auditing for the Major process.

  The Major should only coordinate -- she must not write code or modify
  files outside her workspace. This module provides path-checking utilities
  that enforce those boundaries.

  All functions are pure (no GenServer, no state). They normalize paths
  via `Path.expand/1` to prevent `../` traversal attacks and return
  tagged tuples so callers can decide how to respond.
  """

  require Logger

  @doc """
  Checks whether `path` is inside the section directory.

  Returns `:ok` if the path is within the `.gitf/` directory rooted at
  `gitf_root`, or `{:error, :delegation_required}` if it falls outside.

  ## Examples

      iex> GiTF.Major.Audit.check_file_access("/project/.gitf/queen/notes.md", "/project")
      :ok

      iex> GiTF.Major.Audit.check_file_access("/project/src/app.ex", "/project")
      {:error, :delegation_required}
  """
  @spec check_file_access(String.t(), String.t()) :: :ok | {:error, :delegation_required}
  def check_file_access(path, gitf_root) do
    gitf_dir = Path.join(Path.expand(gitf_root), ".gitf")
    expanded = Path.expand(path)

    if inside_gitf_dir?(expanded, gitf_dir) do
      :ok
    else
      Logger.warning("Major file access outside .gitf/: #{expanded}")
      {:error, :delegation_required}
    end
  end

  @doc """
  Returns `true` if `expanded_path` is inside `gitf_dir`.

  Both paths should already be expanded (absolute, no `..`).
  Public for testability.

  ## Examples

      iex> GiTF.Major.Audit.inside_gitf_dir?("/project/.gitf/queen/MAJOR.md", "/project/.gitf")
      true

      iex> GiTF.Major.Audit.inside_gitf_dir?("/project/src/app.ex", "/project/.gitf")
      false
  """
  @spec inside_gitf_dir?(String.t(), String.t()) :: boolean()
  def inside_gitf_dir?(expanded_path, gitf_dir) do
    # Ensure gitf_dir ends with "/" for prefix matching
    normalized_dir = String.trim_trailing(gitf_dir, "/") <> "/"

    expanded_path == gitf_dir or String.starts_with?(expanded_path, normalized_dir)
  end
end
