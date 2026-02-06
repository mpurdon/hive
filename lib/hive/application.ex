defmodule Hive.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Hive.Progress.init()

    children = [
      {Phoenix.PubSub, name: Hive.PubSub},
      {Registry, keys: :unique, name: Hive.Registry},
      {Hive.CombSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: Hive.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
