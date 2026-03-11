defmodule GiTF.Plugin.ChannelSupervisor do
  @moduledoc """
  DynamicSupervisor for messaging channel processes.

  Channels are long-running GenServers that bridge PubSub <-> external
  services. Start/stop channels at runtime without affecting other processes.
  """

  use DynamicSupervisor

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc "Starts a channel child process."
  @spec start_child(module(), map()) :: DynamicSupervisor.on_start_child()
  def start_child(channel_module, config) do
    spec = %{
      id: channel_module,
      start: {channel_module, :start_link, [config]},
      restart: :permanent
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc "Stops a channel child process."
  @spec stop_child(pid()) :: :ok | {:error, :not_found}
  def stop_child(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
