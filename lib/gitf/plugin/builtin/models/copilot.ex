defmodule GiTF.Plugin.Builtin.Models.Copilot do
  @moduledoc """
  Built-in GitHub Copilot model plugin. Wraps `GiTF.Runtime.Copilot`
  behind the `GiTF.Plugin.Model` behaviour.

  Copilot CLI outputs plain text (no JSONL streaming), so `parse_output/1`
  wraps each line as a text event. No session IDs or cost data are available.
  """

  use GiTF.Plugin, type: :model

  @impl true
  def name, do: "copilot"

  @impl true
  def description, do: "GitHub Copilot via Copilot CLI"

  @impl true
  def spawn_interactive(cwd, opts \\ []) do
    GiTF.Runtime.Copilot.spawn_interactive(cwd, opts)
  end

  @impl true
  def spawn_headless(prompt, cwd, opts \\ []) do
    GiTF.Runtime.Copilot.spawn_headless(cwd, prompt, opts)
  end

  @impl true
  def parse_output(data) do
    data
    |> String.split("\n", trim: true)
    |> Enum.map(fn line -> %{"type" => "text", "content" => line} end)
  end

  @impl true
  def find_executable do
    GiTF.Runtime.Copilot.find_executable()
  end

  @impl true
  def workspace_setup(_bee_or_major, _gitf_root), do: nil

  @impl true
  def pricing, do: %{}

  @impl true
  def capabilities, do: [:tool_calling, :interactive, :headless]

  @impl true
  def extract_costs(_events), do: []

  @impl true
  def extract_session_id(_events), do: nil

  @impl true
  def progress_from_events(events) do
    events
    |> Enum.filter(&match?(%{"type" => "text", "content" => _}, &1))
    |> Enum.map(fn %{"content" => content} ->
      %{tool: nil, file: nil, message: String.slice(content, 0, 120)}
    end)
  end

  @impl true
  def detached_command(prompt, _opts) do
    case GiTF.Runtime.Copilot.find_executable() do
      {:ok, copilot_path} ->
        escaped = "'" <> String.replace(prompt, "'", "'\\''") <> "'"

        ~s("#{copilot_path}" -p #{escaped} -s --allow-all-tools --allow-all-paths)

      {:error, :not_found} ->
        raise "Copilot executable not found"
    end
  end
end
