defmodule Hive.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Hive.Progress.init()
    Hive.Telemetry.attach_default_handlers()

    children = [
      {Phoenix.PubSub, name: Hive.PubSub},
      {Registry, keys: :unique, name: Hive.Registry},
      {Hive.CombSupervisor, []},
      {Hive.Plugin.MCPSupervisor, []},
      {Hive.Plugin.ChannelSupervisor, []},
      {Hive.Plugin.Manager, []},
      {Hive.Shutdown, []}
    ]

    opts = [strategy: :one_for_one, name: Hive.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
