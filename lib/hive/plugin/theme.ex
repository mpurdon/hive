defmodule Hive.Plugin.Theme do
  @moduledoc """
  Behaviour for theme plugins.

  Themes define color palettes for TUI components. The active theme
  is stored in `:persistent_term` for near-zero-cost reads at 60fps.
  """

  @callback name() :: String.t()
  @callback palette() :: %{atom() => term()}
end
