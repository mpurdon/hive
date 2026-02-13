defmodule Hive.TUI.Components.InputBar do
  @moduledoc """
  Input bar component — bottom text input with prefix detection.

  Supports:
  - `/` for slash commands (dispatched to command plugins)
  - `@` for file references
  - `!` for bash commands
  - Tab completion using command plugin `completions/1`
  """

  import TermUI.Component.Helpers

  alias TermUI.Event
  alias TermUI.Renderer.Style

  # -- State management ------------------------------------------------------

  def init do
    %{
      text: "",
      cursor: 0,
      history: [],
      history_index: -1,
      completions: [],
      completion_index: -1
    }
  end

  def event_to_msg(%Event.Key{key: :enter}, _state), do: {:msg, :submit}
  def event_to_msg(%Event.Key{key: :backspace}, _state), do: {:msg, :backspace}
  def event_to_msg(%Event.Key{key: :delete}, _state), do: {:msg, :delete}
  def event_to_msg(%Event.Key{key: :left}, _state), do: {:msg, :cursor_left}
  def event_to_msg(%Event.Key{key: :right}, _state), do: {:msg, :cursor_right}
  def event_to_msg(%Event.Key{key: :home}, _state), do: {:msg, :cursor_home}
  def event_to_msg(%Event.Key{key: :end_key}, _state), do: {:msg, :cursor_end}
  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :history_prev}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :history_next}
  def event_to_msg(%Event.Key{key: :tab}, _state), do: {:msg, :tab_complete}
  def event_to_msg(%Event.Key{key: :a, modifiers: [:ctrl]}, _state), do: {:msg, :cursor_home}
  def event_to_msg(%Event.Key{key: :e, modifiers: [:ctrl]}, _state), do: {:msg, :cursor_end}
  def event_to_msg(%Event.Key{key: :u, modifiers: [:ctrl]}, _state), do: {:msg, :clear_line}

  def event_to_msg(%Event.Key{char: char}, _state)
      when is_binary(char) and byte_size(char) >= 1 do
    {:msg, {:char, char}}
  end

  def event_to_msg(_, _), do: :ignore

  def update(:submit, state) do
    input_text = String.trim(state.text)

    if input_text == "" do
      {state, []}
    else
      cmds = parse_input(input_text)
      history = [input_text | state.history] |> Enum.take(100)

      {%{state | text: "", cursor: 0, history: history, history_index: -1, completions: []}, cmds}
    end
  end

  def update({:char, char}, state) do
    {before, after_cursor} = String.split_at(state.text, state.cursor)
    new_text = before <> char <> after_cursor
    {%{state | text: new_text, cursor: state.cursor + String.length(char), completions: []}, []}
  end

  def update(:backspace, state) do
    if state.cursor > 0 do
      {before, after_cursor} = String.split_at(state.text, state.cursor)
      new_text = String.slice(before, 0, String.length(before) - 1) <> after_cursor
      {%{state | text: new_text, cursor: state.cursor - 1, completions: []}, []}
    else
      {state, []}
    end
  end

  def update(:delete, state) do
    {before, after_cursor} = String.split_at(state.text, state.cursor)

    if String.length(after_cursor) > 0 do
      new_text = before <> String.slice(after_cursor, 1..-1//1)
      {%{state | text: new_text, completions: []}, []}
    else
      {state, []}
    end
  end

  def update(:cursor_left, state) do
    cursor = max(0, state.cursor - 1)
    {%{state | cursor: cursor}, []}
  end

  def update(:cursor_right, state) do
    cursor = min(String.length(state.text), state.cursor + 1)
    {%{state | cursor: cursor}, []}
  end

  def update(:cursor_home, state), do: {%{state | cursor: 0}, []}
  def update(:cursor_end, state), do: {%{state | cursor: String.length(state.text)}, []}

  def update(:clear_line, state) do
    {%{state | text: "", cursor: 0, completions: []}, []}
  end

  def update(:history_prev, state) do
    if state.history_index < length(state.history) - 1 do
      idx = state.history_index + 1
      hist_text = Enum.at(state.history, idx, "")
      {%{state | text: hist_text, cursor: String.length(hist_text), history_index: idx}, []}
    else
      {state, []}
    end
  end

  def update(:history_next, state) do
    if state.history_index > 0 do
      idx = state.history_index - 1
      hist_text = Enum.at(state.history, idx, "")
      {%{state | text: hist_text, cursor: String.length(hist_text), history_index: idx}, []}
    else
      {%{state | text: "", cursor: 0, history_index: -1}, []}
    end
  end

  def update(:tab_complete, state) do
    if String.starts_with?(state.text, "/") do
      do_tab_complete(state)
    else
      {state, []}
    end
  end

  def update(_msg, state), do: {state, []}

  # -- View ------------------------------------------------------------------

  def view(state, theme, focused) do
    prefix_color = theme[:input_prefix] || :yellow

    text_color =
      if focused, do: theme[:input_text] || :white, else: theme[:text_dim] || :bright_black

    prefix =
      cond do
        String.starts_with?(state.text, "/") -> "/"
        String.starts_with?(state.text, "@") -> "@"
        String.starts_with?(state.text, "!") -> "!"
        true -> ">"
      end

    display =
      if state.text == "" do
        "Type a message, /command, @file, or !bash..."
      else
        state.text
      end

    display_style =
      if state.text == "" do
        Style.new(fg: theme[:input_placeholder] || :bright_black)
      else
        Style.new(fg: text_color)
      end

    stack(:horizontal, [
      text(" #{prefix} ", Style.new(fg: prefix_color, attrs: [:bold])),
      text(display, display_style)
    ])
  end

  # -- Private ---------------------------------------------------------------

  defp parse_input(input_text) do
    cond do
      String.starts_with?(input_text, "/") ->
        [cmd | rest] = String.trim_leading(input_text, "/") |> String.split(" ", parts: 2)
        args = Enum.join(rest, " ")
        [{:command, cmd, args}]

      true ->
        [{:submit, input_text}]
    end
  end

  defp do_tab_complete(state) do
    # Extract command name so far
    partial = String.trim_leading(state.text, "/") |> String.split(" ") |> List.first("")

    if state.completions == [] do
      # Generate completions
      commands = Hive.Plugin.Registry.list(:command)

      completions =
        commands
        |> Enum.map(fn {name, _mod} -> name end)
        |> Enum.filter(&String.starts_with?(&1, partial))
        |> Enum.sort()

      case completions do
        [] ->
          {state, []}

        [single] ->
          new_text = "/#{single} "
          {%{state | text: new_text, cursor: String.length(new_text), completions: []}, []}

        multiple ->
          {%{state | completions: multiple, completion_index: 0}, []}
      end
    else
      # Cycle through existing completions
      idx = rem(state.completion_index + 1, length(state.completions))
      completed = Enum.at(state.completions, idx)
      new_text = "/#{completed} "
      {%{state | text: new_text, cursor: String.length(new_text), completion_index: idx}, []}
    end
  end
end
