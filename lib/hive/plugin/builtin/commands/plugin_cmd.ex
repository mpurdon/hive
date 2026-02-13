defmodule Hive.Plugin.Builtin.Commands.PluginCmd do
  @moduledoc "Built-in /plugin command. Load, unload, and list plugins."

  use Hive.Plugin, type: :command

  @impl true
  def name, do: "plugin"

  @impl true
  def description, do: "Manage plugins (list, load, unload)"

  @impl true
  def execute(args, ctx) do
    case String.trim(args) |> String.split(" ", parts: 3) do
      ["list" | _] -> do_list(ctx)
      ["load", path] -> do_load(path, ctx)
      ["load" | _] -> send_output(ctx, "Usage: /plugin load <path_or_module>")
      ["unload", type_name] -> do_unload(type_name, ctx)
      ["unload" | _] -> send_output(ctx, "Usage: /plugin unload <type:name>")
      [other | _] -> send_output(ctx, "Unknown subcommand: #{other}. Try: list, load, unload")
      _ -> do_list(ctx)
    end

    :ok
  end

  @impl true
  def completions(partial) do
    subs = ["list", "load", "unload"]
    Enum.filter(subs, &String.starts_with?(&1, partial))
  end

  defp do_list(ctx) do
    all = Hive.Plugin.Registry.all()

    if all == [] do
      send_output(ctx, "No plugins loaded.")
    else
      grouped =
        Enum.group_by(all, fn {type, _name, _module} -> type end)

      lines =
        Enum.flat_map(grouped, fn {type, plugins} ->
          ["", "#{type}:"] ++
            Enum.map(plugins, fn {_type, name, module} ->
              "  #{name} (#{inspect(module)})"
            end)
        end)

      send_output(ctx, ["Loaded plugins:" | lines] |> Enum.join("\n"))
    end
  end

  defp do_load(path, ctx) do
    if String.ends_with?(path, ".ex") do
      case Hive.Plugin.Manager.load_plugin_file(path) do
        :ok -> send_output(ctx, "Plugin loaded from #{path}")
        {:error, reason} -> send_output(ctx, "Failed: #{inspect(reason)}")
      end
    else
      module = String.to_atom("Elixir.#{path}")

      case Hive.Plugin.Manager.load_plugin(module) do
        :ok -> send_output(ctx, "Plugin #{path} loaded")
        {:error, reason} -> send_output(ctx, "Failed: #{inspect(reason)}")
      end
    end
  end

  defp do_unload(type_name, ctx) do
    case String.split(type_name, ":", parts: 2) do
      [type_str, name_str] ->
        type = String.to_atom(type_str)

        case Hive.Plugin.Manager.unload_plugin(type, name_str) do
          :ok -> send_output(ctx, "Plugin #{type}:#{name_str} unloaded")
          {:error, :not_found} -> send_output(ctx, "Plugin not found: #{type_name}")
        end

      _ ->
        send_output(ctx, "Usage: /plugin unload <type:name> (e.g., theme:monokai)")
    end
  end

  defp send_output(%{pid: pid}, text) when is_pid(pid), do: send(pid, {:command_output, text})
  defp send_output(_ctx, text), do: IO.puts(text)
end
