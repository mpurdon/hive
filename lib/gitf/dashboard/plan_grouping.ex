defmodule GiTF.Dashboard.PlanGrouping do
  @moduledoc "Groups ops or plan specs by inferred topic for the plan checklist view."

  @dir_labels %{
    "web" => "Web",
    "dashboard" => "Dashboard",
    "ghost" => "Ghosts",
    "major" => "Orchestration",
    "runtime" => "Runtime",
    "sync" => "Sync",
    "ops" => "Ops",
    "tui" => "TUI",
    "observability" => "Observability",
    "mcp_server" => "MCP Server",
    "config" => "Config",
    "intel" => "Intel"
  }

  @doc "Groups ops by inferred topic. Returns [{label, [ops]}] sorted by activity."
  def group_ops(ops) do
    ops
    |> Enum.group_by(&infer_group/1)
    |> Enum.map(fn {label, items} -> {label, items} end)
    |> sort_groups()
  end

  @doc "Groups plan spec maps (string keys) by inferred topic."
  def group_specs(specs) when is_list(specs) do
    specs
    |> Enum.group_by(&infer_group_from_spec/1)
    |> Enum.map(fn {label, items} -> {label, items} end)
    |> Enum.sort_by(fn {label, _} -> label end)
  end

  def group_specs(_), do: []

  # -- Private ---------------------------------------------------------------

  defp infer_group(op) do
    title = (Map.get(op, :title) || "") |> String.downcase()
    target_files = Map.get(op, :target_files) || []

    cond do
      String.contains?(title, "test") -> "Testing"
      target_files == [] -> "General"
      true -> directory_group(target_files)
    end
  end

  defp infer_group_from_spec(spec) do
    title = (Map.get(spec, "title") || "") |> String.downcase()
    target_files = Map.get(spec, "target_files") || []

    cond do
      String.contains?(title, "test") -> "Testing"
      target_files == [] -> "General"
      true -> directory_group(target_files)
    end
  end

  defp directory_group(files) do
    files
    |> Enum.map(&extract_dir_segment/1)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_k, v} -> v end, fn -> {"general", 0} end)
    |> elem(0)
    |> humanize_dir()
  end

  defp extract_dir_segment(path) do
    case String.split(path, "/") do
      ["lib", _app, segment | _] -> segment
      ["test" | _] -> "test"
      [segment | _] -> segment
      _ -> "general"
    end
  end

  defp humanize_dir(dir) do
    Map.get(@dir_labels, dir, String.capitalize(dir))
  end

  # Sort: groups with running ops first, then by completion %, then alphabetical
  defp sort_groups(groups) do
    Enum.sort_by(groups, fn {label, ops} ->
      running = Enum.count(ops, &(&1.status in ["running", "assigned"]))
      done = Enum.count(ops, &(&1.status == "done"))
      total = length(ops)
      pct = if total > 0, do: done / total, else: 0

      # Negate running so more running sorts first; then lower completion %, then alpha
      {-running, pct, label}
    end)
  end
end
