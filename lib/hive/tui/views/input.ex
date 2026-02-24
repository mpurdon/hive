defmodule Hive.TUI.Views.Input do
  @moduledoc """
  Helpers for the input bar.
  """

  @doc "Splits text at the cursor position into {before, at, after} segments."
  def split_at_cursor(text, cursor) do
    chars = String.graphemes(text)
    before = Enum.take(chars, cursor) |> Enum.join()
    at = Enum.at(chars, cursor) || " "
    after_ = Enum.drop(chars, cursor + 1) |> Enum.join()
    {before, at, after_}
  end
end
