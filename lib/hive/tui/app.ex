defmodule Hive.TUI.App do
  @moduledoc """
  Root TUI component using the Elm Architecture (term_ui).

  Manages the overall layout: chat pane, activity panel, input bar,
  and status bar. Subscribes to PubSub for real-time updates.
  """

  use TermUI.Elm

  alias TermUI.Event

  alias Hive.TUI.Components.ChatPane
  alias Hive.TUI.Components.ActivityPanel
  alias Hive.TUI.Components.InputBar
  alias Hive.TUI.Components.StatusBar

  # -- Elm Architecture callbacks -------------------------------------------

  def init(_opts) do
    # Start Queen if not already running
    hive_root = start_queen()

    # Subscribe to PubSub topics for real-time updates
    Hive.TUI.Bridge.subscribe()

    theme = Hive.Plugin.Manager.active_theme()

    %{
      hive_root: hive_root,
      theme: theme,
      chat: ChatPane.init(),
      activity: ActivityPanel.init(),
      input: InputBar.init(),
      status: StatusBar.init(),
      focus: :input,
      show_command_palette: false
    }
  end

  def event_to_msg(%Event.Key{key: :q, modifiers: [:ctrl]}, _state), do: {:msg, :quit}
  def event_to_msg(%Event.Key{key: :c, modifiers: [:ctrl]}, _state), do: {:msg, :quit}

  def event_to_msg(%Event.Key{key: :p, modifiers: [:ctrl]}, _state),
    do: {:msg, :toggle_command_palette}

  def event_to_msg(%Event.Key{key: :tab}, _state), do: {:msg, :cycle_focus}

  # Delegate key events to the focused component
  def event_to_msg(%Event.Key{} = event, %{focus: :input} = state) do
    case InputBar.event_to_msg(event, state.input) do
      {:msg, msg} -> {:msg, {:input, msg}}
      :ignore -> :ignore
    end
  end

  def event_to_msg(%Event.Key{} = event, %{focus: :chat} = state) do
    case ChatPane.event_to_msg(event, state.chat) do
      {:msg, msg} -> {:msg, {:chat, msg}}
      :ignore -> :ignore
    end
  end

  def event_to_msg(%Event.Key{} = event, %{focus: :activity} = state) do
    case ActivityPanel.event_to_msg(event, state.activity) do
      {:msg, msg} -> {:msg, {:activity, msg}}
      :ignore -> :ignore
    end
  end

  def event_to_msg(_event, _state), do: :ignore

  def update(:quit, state) do
    Hive.Shutdown.initiate()
    {state, [:quit]}
  end

  def update(:toggle_command_palette, state) do
    {%{state | show_command_palette: not state.show_command_palette}, []}
  end

  def update(:cycle_focus, state) do
    next =
      case state.focus do
        :input -> :chat
        :chat -> :activity
        :activity -> :input
      end

    {%{state | focus: next}, []}
  end

  def update({:input, msg}, state) do
    {input_state, cmds} = InputBar.update(msg, state.input)
    state = %{state | input: input_state}

    # Process input commands
    state =
      Enum.reduce(cmds, state, fn
        {:submit, text}, acc -> handle_submit(text, acc)
        {:command, name, args}, acc -> handle_command(name, args, acc)
        _, acc -> acc
      end)

    {state, []}
  end

  def update({:chat, msg}, state) do
    {chat_state, _cmds} = ChatPane.update(msg, state.chat)
    {%{state | chat: chat_state}, []}
  end

  def update({:activity, msg}, state) do
    {activity_state, _cmds} = ActivityPanel.update(msg, state.activity)
    {%{state | activity: activity_state}, []}
  end

  # Bridge messages from PubSub
  def update({:bridge, :waggle, waggle}, state) do
    chat = ChatPane.add_message(state.chat, :system, "Waggle: #{waggle.subject}")
    activity = ActivityPanel.refresh(state.activity)
    {%{state | chat: chat, activity: activity}, []}
  end

  def update({:bridge, :bee_progress, _bee_id, _entry}, state) do
    activity = ActivityPanel.refresh(state.activity)
    {%{state | activity: activity}, []}
  end

  def update({:bridge, :plugin_loaded, _type, _name, _module}, state) do
    theme = Hive.Plugin.Manager.active_theme()
    {%{state | theme: theme}, []}
  end

  def update({:command_output, text}, state) do
    chat = ChatPane.add_message(state.chat, :system, text)
    {%{state | chat: chat}, []}
  end

  def update(_msg, state), do: {state, []}

  def view(state) do
    theme = state.theme

    stack(:vertical, [
      # Main content area (chat + activity side by side)
      stack(:horizontal, [
        ChatPane.view(state.chat, theme, state.focus == :chat),
        ActivityPanel.view(state.activity, theme, state.focus == :activity)
      ]),
      # Input bar
      InputBar.view(state.input, theme, state.focus == :input),
      # Status bar
      StatusBar.view(state.status, theme)
    ])
  end

  # -- Private helpers -------------------------------------------------------

  defp start_queen do
    case Hive.hive_dir() do
      {:ok, hive_root} ->
        case Hive.Queen.start_link(hive_root: hive_root) do
          {:ok, _pid} -> Hive.Queen.start_session()
          {:error, {:already_started, _pid}} -> :ok
          _ -> :ok
        end

        hive_root

      {:error, _} ->
        nil
    end
  end

  defp handle_submit(text, state) do
    # Add user message to chat
    chat = ChatPane.add_message(state.chat, :user, text)

    # Forward to Queen's Claude port via bridge
    Hive.TUI.Bridge.send_to_queen(text)

    %{state | chat: chat}
  end

  defp handle_command(name, args, state) do
    case Hive.Plugin.Registry.lookup(:command, name) do
      {:ok, module} ->
        ctx = %{pid: self()}
        module.execute(args, ctx)
        state

      :error ->
        chat = ChatPane.add_message(state.chat, :error, "Unknown command: /#{name}")
        %{state | chat: chat}
    end
  end
end
