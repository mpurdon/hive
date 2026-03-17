defmodule Mix.Tasks.Gitf.Mcp.Serve do
  @moduledoc "Starts the GiTF MCP server over stdio for Claude Code integration."
  @shortdoc "Start MCP server (stdio)"

  use Mix.Task

  @impl true
  def run(_args) do
    # Redirect all logging to stderr so stdout stays clean for JSON-RPC
    :logger.remove_handler(:default)

    :logger.add_handler(:mcp_stderr, :logger_std_h, %{
      config: %{type: :standard_error},
      level: :warning,
      formatter: {:logger_formatter, %{template: [:level, ~c" ", :msg, ~c"\n"]}}
    })

    {:ok, _} = Application.ensure_all_started(:gitf)

    GiTF.MCPServer.run()
  end
end
