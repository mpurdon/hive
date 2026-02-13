defmodule Mix.Tasks.Hive.Gen.Plugin do
  @moduledoc """
  Generates a new Hive plugin scaffold.

      mix hive.gen.plugin my_theme --type theme
      mix hive.gen.plugin my_cmd --type command
      mix hive.gen.plugin my_channel --type channel

  Generates the module file with the appropriate behaviour, a matching
  test file with helpers, and registers in config.
  """

  use Mix.Task

  @shortdoc "Generate a Hive plugin scaffold"

  @valid_types ~w(model theme command lsp mcp channel)

  @impl true
  def run(args) do
    case parse_args(args) do
      {:ok, name, type} ->
        generate(name, type)

      {:error, message} ->
        Mix.shell().error(message)
    end
  end

  defp parse_args(args) do
    case OptionParser.parse(args, strict: [type: :string]) do
      {opts, [name], _} ->
        type = Keyword.get(opts, :type)

        cond do
          is_nil(type) ->
            {:error, "Missing --type flag. Valid types: #{Enum.join(@valid_types, ", ")}"}

          type not in @valid_types ->
            {:error, "Invalid type '#{type}'. Valid types: #{Enum.join(@valid_types, ", ")}"}

          true ->
            {:ok, name, type}
        end

      _ ->
        {:error, "Usage: mix hive.gen.plugin <name> --type <type>"}
    end
  end

  defp generate(name, type) do
    module_name = Macro.camelize(name)
    file_name = Macro.underscore(name)

    lib_path = "lib/hive/plugin/builtin/#{type}s/#{file_name}.ex"
    test_path = "test/hive/plugin/builtin/#{type}s/#{file_name}_test.exs"

    module_content = generate_module(module_name, name, type)
    test_content = generate_test(module_name, name, type)

    create_file(lib_path, module_content)
    create_file(test_path, test_content)

    Mix.shell().info("""

    Plugin generated!

      #{lib_path}
      #{test_path}

    To register, add to your Hive config or load at runtime:

      Hive.Plugin.Manager.load_plugin(Hive.Plugin.Builtin.#{type_module(type)}s.#{module_name})
    """)
  end

  defp generate_module(module_name, name, "model") do
    """
    defmodule Hive.Plugin.Builtin.Models.#{module_name} do
      @moduledoc "#{module_name} model plugin."

      use Hive.Plugin, type: :model

      @impl true
      def name, do: "#{name}"

      @impl true
      def description, do: "#{module_name} model provider"

      @impl true
      def spawn_interactive(cwd, opts \\\\ []) do
        # TODO: implement interactive session
        {:error, :not_implemented}
      end

      @impl true
      def spawn_headless(prompt, cwd, opts \\\\ []) do
        # TODO: implement headless session
        {:error, :not_implemented}
      end

      @impl true
      def parse_output(data) do
        []
      end
    end
    """
  end

  defp generate_module(module_name, name, "theme") do
    """
    defmodule Hive.Plugin.Builtin.Themes.#{module_name} do
      @moduledoc "#{module_name} theme plugin."

      use Hive.Plugin, type: :theme

      @impl true
      def name, do: "#{name}"

      @impl true
      def palette do
        %{
          primary: :cyan,
          secondary: :magenta,
          accent: :yellow,
          success: :green,
          warning: :yellow,
          error: :red,
          info: :blue,
          border: :white,
          text: :white
        }
      end
    end
    """
  end

  defp generate_module(module_name, name, "command") do
    """
    defmodule Hive.Plugin.Builtin.Commands.#{module_name} do
      @moduledoc "#{module_name} command plugin."

      use Hive.Plugin, type: :command

      @impl true
      def name, do: "#{name}"

      @impl true
      def description, do: "#{module_name} command"

      @impl true
      def execute(args, ctx) do
        # TODO: implement command
        :ok
      end

      @impl true
      def completions(_partial), do: []
    end
    """
  end

  defp generate_module(module_name, name, "channel") do
    """
    defmodule Hive.Plugin.Builtin.Channels.#{module_name} do
      @moduledoc "#{module_name} messaging channel."

      use GenServer

      @behaviour Hive.Plugin.Channel

      @impl Hive.Plugin.Channel
      def name, do: "#{name}"

      @impl Hive.Plugin.Channel
      def start_link(config) do
        GenServer.start_link(__MODULE__, config, name: __MODULE__)
      end

      @impl Hive.Plugin.Channel
      def send_message(pid, text, opts \\\\ []) do
        GenServer.call(pid, {:send_message, text, opts})
      end

      @impl Hive.Plugin.Channel
      def send_notification(pid, event, payload) do
        GenServer.cast(pid, {:notification, event, payload})
      end

      @impl Hive.Plugin.Channel
      def subscriptions, do: []

      @impl true
      def init(config) do
        {:ok, %{config: config}}
      end

      @impl true
      def handle_call({:send_message, _text, _opts}, _from, state) do
        # TODO: implement message sending
        {:reply, :ok, state}
      end

      @impl true
      def handle_cast({:notification, _event, _payload}, state) do
        # TODO: implement notification handling
        {:noreply, state}
      end
    end
    """
  end

  defp generate_module(module_name, name, "lsp") do
    """
    defmodule Hive.Plugin.Builtin.LSP.#{module_name} do
      @moduledoc "#{module_name} LSP client plugin."

      use Hive.Plugin, type: :lsp

      @impl true
      def name, do: "#{name}"

      @impl true
      def languages, do: []

      @impl true
      def start_link(root) do
        Hive.Plugin.Builtin.LSP.Generic.start_link(
          command: "TODO",
          root: root,
          name: __MODULE__
        )
      end

      @impl true
      def diagnostics(uri) do
        Hive.Plugin.Builtin.LSP.Generic.diagnostics(__MODULE__, uri)
      end
    end
    """
  end

  defp generate_module(module_name, name, "mcp") do
    """
    defmodule Hive.Plugin.Builtin.MCP.#{module_name} do
      @moduledoc "#{module_name} MCP server plugin."

      use Hive.Plugin, type: :mcp

      @impl true
      def name, do: "#{name}"

      @impl true
      def description, do: "#{module_name} MCP server"

      @impl true
      def command, do: {"TODO_binary", ["TODO_args"]}

      @impl true
      def env, do: %{}
    end
    """
  end

  defp generate_test(module_name, _name, type) do
    type_module = type_module(type)

    """
    defmodule Hive.Plugin.Builtin.#{type_module}s.#{module_name}Test do
      use ExUnit.Case, async: true

      alias Hive.Plugin.Builtin.#{type_module}s.#{module_name}

      test "implements #{type} behaviour" do
        assert function_exported?(#{module_name}, :name, 0)
      end

      test "returns a name" do
        assert is_binary(#{module_name}.name())
      end
    end
    """
  end

  defp type_module("model"), do: "Model"
  defp type_module("theme"), do: "Theme"
  defp type_module("command"), do: "Command"
  defp type_module("lsp"), do: "LSP"
  defp type_module("mcp"), do: "MCP"
  defp type_module("channel"), do: "Channel"

  defp create_file(path, content) do
    dir = Path.dirname(path)
    File.mkdir_p!(dir)

    if File.exists?(path) do
      Mix.shell().info("* skipping #{path} (already exists)")
    else
      File.write!(path, content)
      Mix.shell().info("* creating #{path}")
    end
  end
end
