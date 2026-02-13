defmodule Hive.TUI.Components.StatusBar do
  @moduledoc """
  Status bar component — bottom status line.

  Shows active model, token costs, quest status, and bee count.
  """

  import TermUI.Component.Helpers

  alias TermUI.Renderer.Style

  # -- State management ------------------------------------------------------

  def init do
    %{
      model: "claude",
      total_cost: 0.0
    }
  end

  # -- View ------------------------------------------------------------------

  def view(state, theme) do
    # Refresh counts from bridge
    bees = Hive.TUI.Bridge.list_bees()
    quests = Hive.TUI.Bridge.list_quests()

    active_bees = Enum.count(bees, fn b -> b.status == "working" end)
    active_quests = Enum.count(quests, fn q -> q.status == "active" end)

    cost_str = :erlang.float_to_binary(state.total_cost, decimals: 4)

    model_color = theme[:status_model] || :yellow
    cost_color = theme[:status_cost] || :green
    fg = theme[:status_fg] || :white

    stack(:horizontal, [
      text(" #{state.model} ", Style.new(fg: model_color, attrs: [:bold])),
      text(" | ", Style.new(fg: fg)),
      text("$#{cost_str}", Style.new(fg: cost_color)),
      text(" | ", Style.new(fg: fg)),
      text("#{active_bees} bees", Style.new(fg: fg)),
      text(" | ", Style.new(fg: fg)),
      text("#{active_quests} quests", Style.new(fg: fg)),
      text(" | ", Style.new(fg: fg)),
      text(
        "Tab: focus  Ctrl+P: palette  Ctrl+Q: quit",
        Style.new(fg: theme[:text_dim] || :bright_black)
      )
    ])
  end
end
