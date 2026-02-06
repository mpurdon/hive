defmodule Hive do
  @moduledoc "The Hive - Multi-agent orchestration for Claude Code."

  @version Mix.Project.config()[:version]

  @spec version() :: String.t()
  def version, do: @version

  @doc """
  Locates the root directory of a Hive project.

  Checks the HIVE_PATH environment variable first, then walks up from the
  current working directory looking for a `.hive/` directory marker.
  """
  @spec hive_dir() :: {:ok, String.t()} | {:error, :not_in_hive}
  def hive_dir do
    case System.get_env("HIVE_PATH") do
      nil -> find_hive_dir(File.cwd!())
      path -> validate_hive_path(Path.expand(path))
    end
  end

  defp validate_hive_path(expanded) do
    if File.dir?(Path.join(expanded, ".hive")),
      do: {:ok, expanded},
      else: {:error, :not_in_hive}
  end

  defp find_hive_dir("/"), do: {:error, :not_in_hive}

  defp find_hive_dir(path) do
    if File.dir?(Path.join(path, ".hive")),
      do: {:ok, path},
      else: find_hive_dir(Path.dirname(path))
  end
end
