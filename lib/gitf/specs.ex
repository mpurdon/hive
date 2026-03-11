defmodule GiTF.Specs do
  @moduledoc """
  Context module for mission spec file I/O.

  Spec files are markdown documents stored at `.gitf/missions/{mission_id}/{phase}.md`.
  Each mission progresses through three planning phases: requirements → design → tasks.
  This module provides read/write access to those files.
  """

  @phases ~w(requirements design tasks)

  @doc "Returns the list of valid spec phases."
  @spec phases() :: [String.t()]
  def phases, do: @phases

  @doc """
  Writes a spec file for the given mission and phase.

  Creates the mission directory if it doesn't exist. Returns `{:ok, path}`
  on success or `{:error, reason}` on failure.
  """
  @spec write(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def write(mission_id, phase, content) when phase in @phases do
    dir = quest_dir(mission_id)
    File.mkdir_p!(dir)
    path = Path.join(dir, "#{phase}.md")

    case File.write(path, content) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  def write(_mission_id, phase, _content), do: {:error, {:invalid_phase, phase}}

  @doc """
  Reads a spec file for the given mission and phase.

  Returns `{:ok, content}` or `{:error, :not_found}`.
  """
  @spec read(String.t(), String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def read(mission_id, phase) when phase in @phases do
    path = Path.join(quest_dir(mission_id), "#{phase}.md")

    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, _} -> {:error, :not_found}
    end
  end

  def read(_mission_id, phase), do: {:error, {:invalid_phase, phase}}

  @doc """
  Lists which spec phases exist for a mission.

  Returns a sorted list of phase names that have files on disk,
  e.g. `["requirements", "design"]`.
  """
  @spec list_phases(String.t()) :: [String.t()]
  def list_phases(mission_id) do
    dir = quest_dir(mission_id)

    case File.ls(dir) do
      {:ok, entries} ->
        entries
        |> Enum.map(&Path.rootname/1)
        |> Enum.filter(&(&1 in @phases))
        |> Enum.sort_by(&Enum.find_index(@phases, fn p -> p == &1 end))

      {:error, _} ->
        []
    end
  end

  @doc "Returns the directory path for a mission's spec files."
  @spec quest_dir(String.t()) :: String.t()
  def quest_dir(mission_id) do
    case GiTF.gitf_dir() do
      {:ok, root} -> Path.join([root, ".gitf", "missions", mission_id])
      {:error, _} -> Path.join([".gitf", "missions", mission_id])
    end
  end
end
