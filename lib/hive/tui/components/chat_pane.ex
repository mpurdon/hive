defmodule Hive.TUI.Components.ChatPane do
  @moduledoc """
  Chat pane component — left/top pane showing conversation with Queen.

  Scrollable message history with distinct styling for user messages,
  assistant responses, system messages, tool use, and errors.
  """

  import TermUI.Component.Helpers

  alias TermUI.Event
  alias TermUI.Renderer.Style

  @max_messages 500

  # -- State management ------------------------------------------------------

  def init do
    %{
      messages: [],
      scroll_offset: 0,
      auto_scroll: true
    }
  end

  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :scroll_up}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :scroll_down}
  def event_to_msg(%Event.Key{key: :page_up}, _state), do: {:msg, :page_up}
  def event_to_msg(%Event.Key{key: :page_down}, _state), do: {:msg, :page_down}
  def event_to_msg(_, _), do: :ignore

  def update(:scroll_up, state) do
    offset = max(0, state.scroll_offset - 1)
    {%{state | scroll_offset: offset, auto_scroll: false}, []}
  end

  def update(:scroll_down, state) do
    offset = min(length(state.messages) - 1, state.scroll_offset + 1)
    auto = offset >= length(state.messages) - 1
    {%{state | scroll_offset: offset, auto_scroll: auto}, []}
  end

  def update(:page_up, state) do
    offset = max(0, state.scroll_offset - 10)
    {%{state | scroll_offset: offset, auto_scroll: false}, []}
  end

  def update(:page_down, state) do
    offset = min(length(state.messages) - 1, state.scroll_offset + 10)
    auto = offset >= length(state.messages) - 1
    {%{state | scroll_offset: offset, auto_scroll: auto}, []}
  end

  def update(_msg, state), do: {state, []}

  @doc "Add a message to the chat history."
  @spec add_message(map(), atom(), String.t()) :: map()
  def add_message(state, type, content) do
    msg = %{type: type, text: content, timestamp: DateTime.utc_now()}

    messages =
      (state.messages ++ [msg])
      |> Enum.take(-@max_messages)

    offset =
      if state.auto_scroll do
        max(0, length(messages) - 1)
      else
        state.scroll_offset
      end

    %{state | messages: messages, scroll_offset: offset}
  end

  # -- View ------------------------------------------------------------------

  def view(state, theme, focused) do
    border_color =
      if focused, do: theme[:border_focused] || :yellow, else: theme[:border] || :white

    messages_view =
      state.messages
      |> Enum.map(fn msg -> render_message(msg, theme) end)

    stack(:vertical, [
      text(
        " Chat ",
        Style.new(fg: border_color, attrs: [:bold])
      )
      | messages_view
    ])
  end

  # -- Private ---------------------------------------------------------------

  defp render_message(%{type: :user, text: content}, theme) do
    color = theme[:user_message] || :cyan
    text("> #{content}", Style.new(fg: color))
  end

  defp render_message(%{type: :assistant, text: content}, theme) do
    color = theme[:assistant_message] || :white
    text(content, Style.new(fg: color))
  end

  defp render_message(%{type: :system, text: content}, theme) do
    color = theme[:system_message] || :yellow
    text("[system] #{content}", Style.new(fg: color))
  end

  defp render_message(%{type: :tool_use, text: content}, theme) do
    color = theme[:tool_use] || :magenta
    text("[tool] #{content}", Style.new(fg: color))
  end

  defp render_message(%{type: :error, text: content}, theme) do
    color = theme[:error] || :red
    text("[error] #{content}", Style.new(fg: color))
  end

  defp render_message(%{type: _, text: content}, _theme) do
    text(content)
  end
end
