defmodule Hive.Plugin.MCP do
  @moduledoc """
  Behaviour for MCP (Model Context Protocol) server plugins.

  MCP servers run as child processes under `Hive.Plugin.MCPSupervisor`.
  The MCP client handles JSON-RPC over stdio/SSE and exposes tools
  to the Queen's context.
  """

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback command() :: {String.t(), [String.t()]}
  @callback env() :: %{String.t() => String.t()}

  @doc "Override for non-stdio transports. Defaults to :stdio."
  @callback transport() :: :stdio | {:sse, String.t()}

  @optional_callbacks transport: 0
end
