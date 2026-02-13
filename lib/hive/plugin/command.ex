defmodule Hive.Plugin.Command do
  @moduledoc """
  Behaviour for slash command plugins.

  Commands are invoked via `/name args` in the TUI input bar.
  They can also be discovered via the command palette (Ctrl+P).
  """

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback execute(args :: String.t(), ctx :: map()) :: :ok | {:error, String.t()}
  @callback completions(partial :: String.t()) :: [String.t()]
end
