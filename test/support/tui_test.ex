defmodule Hive.TUITest do
  @moduledoc """
  Test helpers for TUI component testing.

  Provides simulation of user input, keypresses, and render output
  assertions without needing a real terminal.
  """

  @doc "Simulates typing text into the input bar."
  def send_input(input_state, text) do
    text
    |> String.graphemes()
    |> Enum.reduce(input_state, fn char, state ->
      {state, _cmds} = Hive.TUI.Components.InputBar.update({:char, char}, state)
      state
    end)
  end

  @doc "Simulates a keypress event on the input bar."
  def send_key(input_state, key) do
    msg =
      case Hive.TUI.Components.InputBar.event_to_msg(
             %TermUI.Event.Key{key: key},
             input_state
           ) do
        {:msg, m} -> m
        :ignore -> nil
      end

    if msg do
      {state, _cmds} = Hive.TUI.Components.InputBar.update(msg, input_state)
      state
    else
      input_state
    end
  end

  @doc "Checks that the input state text contains a pattern."
  def assert_input_contains(input_state, pattern) do
    unless String.contains?(input_state.text, pattern) do
      raise ExUnit.AssertionError,
        message:
          "Expected input to contain #{inspect(pattern)}, got: #{inspect(input_state.text)}"
    end
  end

  @doc "Checks that chat messages contain a pattern."
  def assert_chat_contains(chat_state, pattern) do
    has_match =
      Enum.any?(chat_state.messages, fn msg ->
        String.contains?(msg.text, pattern)
      end)

    unless has_match do
      texts = Enum.map(chat_state.messages, & &1.text) |> Enum.join("\n")

      raise ExUnit.AssertionError,
        message: "Expected chat to contain #{inspect(pattern)}, messages:\n#{texts}"
    end
  end
end
