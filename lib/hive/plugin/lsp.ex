defmodule Hive.Plugin.LSP do
  @moduledoc """
  Behaviour for LSP client plugins.

  LSP plugins connect to language servers via JSON-RPC over stdio,
  providing diagnostics and other language features to the TUI.
  """

  @callback name() :: String.t()
  @callback languages() :: [String.t()]
  @callback start_link(root :: String.t()) :: GenServer.on_start()
  @callback diagnostics(uri :: String.t()) :: [map()]
end
