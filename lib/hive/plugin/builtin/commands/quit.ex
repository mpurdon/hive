defmodule Hive.Plugin.Builtin.Commands.Quit do
  @moduledoc "Built-in /quit command. Initiates graceful shutdown."

  use Hive.Plugin, type: :command

  @impl true
  def name, do: "quit"

  @impl true
  def description, do: "Quit Hive"

  @impl true
  def execute(_args, _ctx) do
    Hive.Shutdown.initiate()
    :ok
  end

  @impl true
  def completions(_partial), do: []
end
