defmodule Hive.TUI.Views.Activity do
  @moduledoc """
  Renders the activity panel with quests and their bees grouped together.
  """
  import Ratatouille.View

  def render(model) do
    %{activity: activity} = model
    bees_by_quest = Enum.group_by(activity.bees, fn b -> b[:quest_id] end)

    panel title: "Activity", height: :fill do
      if Enum.empty?(activity.quests) and Enum.empty?(activity.bees) do
        label(content: "Idle")
      else
        render_quests(activity.quests, bees_by_quest, activity.bee_logs) ++
          render_orphan_bees(bees_by_quest, activity.bee_logs)
      end
    end
  end

  defp render_quests(quests, bees_by_quest, bee_logs) do
    Enum.flat_map(quests, fn quest ->
      quest_id = quest[:id]
      quest_bees = Map.get(bees_by_quest, quest_id, [])
      phase = to_s(quest[:current_phase] || quest[:status])
      name = to_s(quest[:name] || quest[:goal] || quest[:title])
      short_name = String.slice(name, 0, 30)

      [
        label do
          text(content: short_name, color: :yellow)
          text(content: " [#{phase}]", color: :white)
        end
      ] ++ render_bees(quest_bees, bee_logs, "  ") ++ [label(content: "")]
    end)
  end

  defp render_orphan_bees(bees_by_quest, bee_logs) do
    case Map.get(bees_by_quest, nil, []) do
      [] -> []
      bees -> render_bees(bees, bee_logs, "")
    end
  end

  defp render_bees([], _bee_logs, indent) do
    [label(content: indent <> "no active bees", color: :white)]
  end

  defp render_bees(bees, bee_logs, indent) do
    Enum.flat_map(bees, fn bee ->
      bee_id = to_s(bee[:id])
      status = to_s(bee[:status] || bee[:state])
      log_lines = Map.get(bee_logs, bee[:id], [])

      [
        label do
          text(content: indent <> bee_id, color: :cyan)
          text(content: " [#{status}]", color: status_color(status))
        end
        | Enum.map(log_lines, fn line ->
            label(content: indent <> "  " <> line, color: :white)
          end)
      ]
    end)
  end

  defp to_s(nil), do: "?"
  defp to_s(val) when is_binary(val), do: val
  defp to_s(val), do: inspect(val)

  defp status_color("working"), do: :green
  defp status_color("provisioning"), do: :yellow
  defp status_color("stopped"), do: :white
  defp status_color("failed"), do: :red
  defp status_color(_), do: :white
end
