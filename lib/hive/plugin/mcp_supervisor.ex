defmodule Hive.Plugin.MCPSupervisor do
  @moduledoc """
  DynamicSupervisor for MCP server processes.

  Adding a new MCP server just starts a new child. Removing stops it.
  No restart needed for other processes.
  """

  use DynamicSupervisor

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc "Starts an MCP client child process."
  @spec start_child(module(), map()) :: DynamicSupervisor.on_start_child()
  def start_child(mcp_module, config \\ %{}) do
    spec = {Hive.Plugin.MCPClient, {mcp_module, config}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc "Stops an MCP client child process."
  @spec stop_child(pid()) :: :ok | {:error, :not_found}
  def stop_child(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
