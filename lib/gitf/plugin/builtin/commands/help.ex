defmodule GiTF.Plugin.Builtin.Commands.Help do
  @moduledoc "Built-in /help command. Lists all available commands."

  use GiTF.Plugin, type: :command

  @impl true
  def name, do: "help"

  @impl true
  def description, do: "Show available commands"

  @impl true
  def execute(_args, ctx) do
    commands = GiTF.Plugin.Manager.list(:command)

    lines =
      commands
      |> Enum.sort_by(fn {name, _mod} -> name end)
      |> Enum.map(fn {cmd_name, mod} ->
        desc = mod.description()
        "  /#{cmd_name} — #{desc}"
      end)

    output = ["Available commands:", "" | lines] |> Enum.join("\n")
    send_output(ctx, output)
    :ok
  end

  @impl true
  def completions(_partial), do: []

  defp send_output(%{pid: pid}, text) when is_pid(pid) do
    send(pid, {:command_output, text})
  end

  defp send_output(_ctx, text) do
    IO.puts(text)
  end
end
