defmodule Hive.TUI.Constants do
  @moduledoc """
  Defines constants for the TUI layout, colors, and styling.
  """

  # Colors
  def color_bg, do: :default
  def color_fg, do: :white
  def color_border, do: :cyan
  def color_prompt, do: :green
  def color_system, do: :yellow
  def color_user, do: :blue
  def color_assistant, do: :white
  def color_error, do: :red
  def color_success, do: :green

  # Dimensions
  def chat_height_ratio, do: 2
  def activity_height_ratio, do: 1
  def sidebar_width_ratio, do: 1
  def main_width_ratio, do: 3

  # Text
  def prompt_symbol, do: "> "
end
