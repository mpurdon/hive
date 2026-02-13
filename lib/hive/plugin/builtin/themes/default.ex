defmodule Hive.Plugin.Builtin.Themes.Default do
  @moduledoc """
  Default Hive TUI theme. Defines color palette for all components.
  """

  use Hive.Plugin, type: :theme

  @impl true
  def name, do: "default"

  @impl true
  def palette do
    %{
      # Primary colors
      primary: :yellow,
      secondary: :cyan,
      accent: :magenta,

      # Status colors
      success: :green,
      warning: :yellow,
      error: :red,
      info: :blue,

      # Component-specific
      border: :white,
      border_focused: :yellow,
      text: :white,
      text_dim: :light_black,
      text_bold: :white,

      # Chat pane
      user_message: :cyan,
      assistant_message: :white,
      system_message: :yellow,
      tool_use: :magenta,
      thinking: :light_black,

      # Activity panel
      bee_working: :green,
      bee_idle: :white,
      bee_stopped: :light_black,
      bee_crashed: :red,

      # Status bar
      status_bg: :blue,
      status_fg: :white,
      status_model: :yellow,
      status_cost: :green,

      # Input bar
      input_prefix: :yellow,
      input_text: :white,
      input_placeholder: :light_black
    }
  end
end
