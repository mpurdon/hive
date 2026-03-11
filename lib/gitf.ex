defmodule GiTF do
  @moduledoc "The GiTF - Multi-agent orchestration for Claude Code."

  @version Mix.Project.config()[:version]

  @spec version() :: String.t()
  def version, do: @version

  @doc """
  Locates the root directory of a GiTF project.

  Checks the GITF_PATH environment variable first, then walks up from the
  current working directory looking for a `.gitf/` directory marker.
  """
  @spec gitf_dir() :: {:ok, String.t()} | {:error, :not_in_gitf}
  def gitf_dir do
    case System.get_env("GITF_PATH") do
      nil -> find_gitf_dir(File.cwd!())
      path -> validate_gitf_path(Path.expand(path))
    end
  end

  defp validate_gitf_path(expanded) do
    if initialized?(expanded),
      do: {:ok, expanded},
      else: {:error, :not_in_gitf}
  end

  defp find_gitf_dir("/"), do: {:error, :not_in_gitf}

  defp find_gitf_dir(path) do
    if initialized?(path),
      do: {:ok, path},
      else: find_gitf_dir(Path.dirname(path))
  end

  defp initialized?(path) do
    File.exists?(Path.join([path, ".gitf", "config.toml"]))
  end
end
