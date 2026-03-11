defmodule GiTF.Plugin.Builtin.Models.Kimi do
  @moduledoc """
  Built-in Kimi model plugin. Wraps `GiTF.Runtime.Kimi` behind the
  `GiTF.Plugin.Model` behaviour.

  Kimi CLI uses the same JSONL streaming format as Claude, so output
  parsing, cost extraction, and session ID extraction all delegate to
  `GiTF.Runtime.StreamParser`.
  """

  use GiTF.Plugin, type: :model

  @impl true
  def name, do: "kimi"

  @impl true
  def description, do: "Moonshot AI Kimi via Kimi CLI"

  @impl true
  def spawn_interactive(cwd, opts \\ []) do
    GiTF.Runtime.Kimi.spawn_interactive(cwd, opts)
  end

  @impl true
  def spawn_headless(prompt, cwd, opts \\ []) do
    GiTF.Runtime.Kimi.spawn_headless(cwd, prompt, opts)
  end

  @impl true
  def parse_output(data) do
    GiTF.Runtime.StreamParser.parse_chunk(data)
  end

  @impl true
  def find_executable do
    GiTF.Runtime.Kimi.find_executable()
  end

  @impl true
  def workspace_setup(_bee_or_major, _gitf_root), do: nil

  @impl true
  def pricing do
    %{
      "kimi-k2" => %{
        input: 2.0,
        output: 8.0,
        cache_read: 0.20,
        cache_write: 2.50
      }
    }
  end

  @impl true
  def capabilities, do: [:tool_calling, :streaming, :interactive, :headless]

  @impl true
  def extract_costs(events) do
    GiTF.Runtime.StreamParser.extract_costs(events)
  end

  @impl true
  def extract_session_id(events) do
    GiTF.Runtime.StreamParser.extract_session_id(events)
  end

  @impl true
  def progress_from_events(events) do
    Enum.reduce(events, [], fn event, acc ->
      case event do
        %{"type" => "tool_use", "name" => tool} ->
          file = get_in(event, ["input", "file_path"]) || ""
          [%{tool: tool, file: file, message: "Using #{tool}"} | acc]

        %{"type" => "assistant", "content" => content} when is_binary(content) ->
          [%{tool: nil, file: nil, message: String.slice(content, 0, 120)} | acc]

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  @impl true
  def detached_command(prompt, _opts) do
    case GiTF.Runtime.Kimi.find_executable() do
      {:ok, kimi_path} ->
        escaped = "'" <> String.replace(prompt, "'", "'\\''") <> "'"

        ~s("#{kimi_path}" --print --output-format stream-json -p #{escaped})

      {:error, :not_found} ->
        raise "Kimi executable not found"
    end
  end
end
