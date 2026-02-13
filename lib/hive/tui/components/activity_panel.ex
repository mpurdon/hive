defmodule Hive.TUI.Components.ActivityPanel do
  @moduledoc """
  Activity panel component — right/bottom pane showing bee/quest/job status.

  Real-time updates via PubSub subscription. Shows bee status table,
  quest summary, and job progress.
  """

  import TermUI.Component.Helpers

  alias TermUI.Event
  alias TermUI.Renderer.Style

  # -- State management ------------------------------------------------------

  def init do
    %{
      bees: [],
      quests: [],
      progress: [],
      scroll_offset: 0
    }
  end

  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :scroll_up}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :scroll_down}
  def event_to_msg(_, _), do: :ignore

  def update(:scroll_up, state) do
    offset = max(0, state.scroll_offset - 1)
    {%{state | scroll_offset: offset}, []}
  end

  def update(:scroll_down, state) do
    total = length(state.bees) + length(state.quests)
    offset = min(total, state.scroll_offset + 1)
    {%{state | scroll_offset: offset}, []}
  end

  def update(_msg, state), do: {state, []}

  @doc "Refresh data from the bridge."
  @spec refresh(map()) :: map()
  def refresh(state) do
    snapshot = Hive.TUI.Bridge.state_snapshot()

    %{state | bees: snapshot.bees, quests: snapshot.quests, progress: snapshot.progress}
  end

  # -- View ------------------------------------------------------------------

  def view(state, theme, focused) do
    border_color =
      if focused, do: theme[:border_focused] || :yellow, else: theme[:border] || :white

    bee_rows = render_bees(state.bees, state.progress, theme)
    quest_rows = render_quests(state.quests, theme)

    stack(
      :vertical,
      [
        text(" Activity ", Style.new(fg: border_color, attrs: [:bold])),
        text(""),
        text(" Bees", Style.new(fg: theme[:secondary] || :cyan, attrs: [:bold]))
      ] ++
        bee_rows ++
        [
          text(""),
          text(" Quests", Style.new(fg: theme[:secondary] || :cyan, attrs: [:bold]))
        ] ++ quest_rows
    )
  end

  # -- Private ---------------------------------------------------------------

  defp render_bees([], _progress, _theme) do
    [text("  (no bees)", Style.new(fg: :bright_black))]
  end

  defp render_bees(bees, progress, theme) do
    Enum.map(bees, fn bee ->
      status_color = bee_status_color(bee.status, theme)
      prog = Enum.find(progress, fn p -> p[:bee_id] == bee.id end)
      tool = if prog, do: " [#{prog[:tool] || "..."}]", else: ""

      text(
        "  #{bee.name} [#{bee.status}]#{tool}",
        Style.new(fg: status_color)
      )
    end)
  end

  defp render_quests([], _theme) do
    [text("  (no quests)", Style.new(fg: :bright_black))]
  end

  defp render_quests(quests, theme) do
    Enum.map(quests, fn quest ->
      status_color = quest_status_color(quest.status, theme)

      text(
        "  #{quest.name} [#{quest.status}]",
        Style.new(fg: status_color)
      )
    end)
  end

  defp bee_status_color("working", theme), do: theme[:bee_working] || :green
  defp bee_status_color("idle", theme), do: theme[:bee_idle] || :white
  defp bee_status_color("stopped", theme), do: theme[:bee_stopped] || :bright_black
  defp bee_status_color("crashed", theme), do: theme[:bee_crashed] || :red
  defp bee_status_color(_, _theme), do: :white

  defp quest_status_color("active", theme), do: theme[:success] || :green
  defp quest_status_color("completed", theme), do: theme[:info] || :blue
  defp quest_status_color("pending", theme), do: theme[:warning] || :yellow
  defp quest_status_color(_, _theme), do: :white
end
