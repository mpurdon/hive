defmodule GiTF.Plugin.Builtin.Commands.Quest do
  @moduledoc "Built-in /mission command. Create, list, and show missions."

  use GiTF.Plugin, type: :command

  @impl true
  def name, do: "mission"

  @impl true
  def description, do: "Manage missions (new, list, show)"

  @impl true
  def execute(args, ctx) do
    case String.trim(args) |> String.split(" ", parts: 2) do
      ["new", goal] -> do_new(goal, ctx)
      ["new" | _] -> send_output(ctx, "Usage: /mission new <goal>")
      ["list" | _] -> do_list(ctx)
      ["show", id] -> do_show(id, ctx)
      ["show" | _] -> send_output(ctx, "Usage: /mission show <id>")
      [other | _] -> send_output(ctx, "Unknown subcommand: #{other}. Try: new, list, show")
      _ -> do_list(ctx)
    end

    :ok
  end

  @impl true
  def completions(partial) do
    subs = ["new", "list", "show"]
    Enum.filter(subs, &String.starts_with?(&1, partial))
  end

  defp do_new(goal, ctx) do
    case GiTF.Missions.create(%{goal: goal}) do
      {:ok, mission} ->
        send_output(ctx, "Quest \"#{mission.name}\" created (#{mission.id})")

      {:error, reason} ->
        send_output(ctx, "Failed: #{inspect(reason)}")
    end
  end

  defp do_list(ctx) do
    case GiTF.Missions.list() do
      [] ->
        send_output(ctx, "No missions. Use /mission new <goal> to create one.")

      missions ->
        lines =
          Enum.map(missions, fn q ->
            "  #{q.id}  #{q.name}  [#{q.status}]"
          end)

        send_output(ctx, ["Missions:", "" | lines] |> Enum.join("\n"))
    end
  end

  defp do_show(id, ctx) do
    case GiTF.Missions.get(id) do
      {:ok, mission} ->
        lines =
          [
            "Quest: #{mission.name} (#{mission.id})",
            "Status: #{mission.status}",
            "Goal: #{mission[:goal] || "-"}"
          ]

        jobs_lines =
          case mission.ops do
            [] ->
              ["", "No ops."]

            ops ->
              ["", "Jobs:"] ++
                Enum.map(ops, fn j ->
                  "  #{j.id}  #{j.title}  [#{j.status}]  #{j.ghost_id || "-"}"
                end)
          end

        send_output(ctx, Enum.join(lines ++ jobs_lines, "\n"))

      {:error, :not_found} ->
        send_output(ctx, "Quest not found: #{id}")
    end
  end

  defp send_output(%{pid: pid}, text) when is_pid(pid), do: send(pid, {:command_output, text})
  defp send_output(_ctx, text), do: IO.puts(text)
end
