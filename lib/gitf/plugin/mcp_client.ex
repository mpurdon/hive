defmodule GiTF.Plugin.MCPClient do
  @moduledoc """
  JSON-RPC client for MCP servers.

  Handles communication with MCP servers over stdio or SSE transport.
  Exposes discovered tools to the Queen's context.
  """

  use GenServer

  require Logger

  # -- Public API ------------------------------------------------------------

  def start_link({mcp_module, config}) do
    GenServer.start_link(__MODULE__, {mcp_module, config})
  end

  @doc "Lists tools available from this MCP server."
  @spec list_tools(GenServer.server()) :: [map()]
  def list_tools(server) do
    GenServer.call(server, :list_tools)
  end

  @doc "Calls a tool on the MCP server."
  @spec call_tool(GenServer.server(), String.t(), map()) :: {:ok, term()} | {:error, term()}
  def call_tool(server, tool_name, args) do
    GenServer.call(server, {:call_tool, tool_name, args}, 30_000)
  end

  # -- GenServer callbacks ---------------------------------------------------

  @impl true
  def init({mcp_module, _config}) do
    {cmd, args} = mcp_module.command()
    env = mcp_module.env()

    env_charlist =
      Enum.map(env, fn {k, v} -> {to_charlist(k), to_charlist(v)} end)

    port =
      Port.open({:spawn_executable, cmd}, [
        :binary,
        :exit_status,
        :use_stdio,
        args: args,
        env: env_charlist
      ])

    state = %{
      module: mcp_module,
      port: port,
      tools: [],
      pending: %{},
      next_id: 1,
      buffer: ""
    }

    # Initialize the MCP connection
    send_jsonrpc(state, "initialize", %{
      protocolVersion: "2024-11-05",
      capabilities: %{},
      clientInfo: %{name: "gitf", version: GiTF.version()}
    })

    {:ok, state}
  end

  @impl true
  def handle_call(:list_tools, _from, state) do
    {:reply, state.tools, state}
  end

  def handle_call({:call_tool, tool_name, args}, from, state) do
    {state, _id} = send_jsonrpc(state, "tools/call", %{name: tool_name, arguments: args}, from)
    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    buffer = state.buffer <> data
    {messages, remaining} = parse_jsonrpc_messages(buffer)

    state = %{state | buffer: remaining}
    state = Enum.reduce(messages, state, &handle_jsonrpc_message/2)

    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.warning("MCP server #{state.module.name()} exited with status #{status}")
    {:stop, {:mcp_exit, status}, %{state | port: nil}}
  end

  @impl true
  def terminate(_reason, state) do
    if state.port != nil do
      try do
        Port.close(state.port)
      rescue
        _ -> :ok
      end
    end

    # Reply to any pending callers so they don't hang
    Enum.each(state.pending, fn {_id, from} ->
      GenServer.reply(from, {:error, :mcp_shutdown})
    end)

    :ok
  end

  # -- Private ---------------------------------------------------------------

  defp send_jsonrpc(state, method, params, from \\ nil) do
    id = state.next_id

    message =
      Jason.encode!(%{jsonrpc: "2.0", id: id, method: method, params: params})

    Port.command(state.port, message <> "\n")

    pending =
      if from do
        Map.put(state.pending, id, from)
      else
        state.pending
      end

    {%{state | next_id: id + 1, pending: pending}, id}
  end

  defp parse_jsonrpc_messages(buffer) do
    lines = String.split(buffer, "\n")
    {complete, [remaining]} = Enum.split(lines, -1)

    messages =
      Enum.reduce(complete, [], fn line, acc ->
        line = String.trim(line)

        if line == "" do
          acc
        else
          case Jason.decode(line) do
            {:ok, parsed} -> [parsed | acc]
            {:error, _} -> acc
          end
        end
      end)
      |> Enum.reverse()

    {messages, remaining}
  end

  defp handle_jsonrpc_message(%{"id" => id, "result" => result}, state) do
    case Map.pop(state.pending, id) do
      {nil, pending} ->
        # Response to initialize — discover tools
        if is_map(result) and Map.has_key?(result, "capabilities") do
          send_jsonrpc(state, "tools/list", %{})
        end

        %{state | pending: pending}

      {from, pending} ->
        GenServer.reply(from, {:ok, result})
        %{state | pending: pending}
    end
  end

  defp handle_jsonrpc_message(%{"result" => %{"tools" => tools}}, state) do
    %{state | tools: tools}
  end

  defp handle_jsonrpc_message(%{"id" => id, "error" => error}, state) do
    case Map.pop(state.pending, id) do
      {nil, _} ->
        state

      {from, pending} ->
        GenServer.reply(from, {:error, error})
        %{state | pending: pending}
    end
  end

  defp handle_jsonrpc_message(_msg, state), do: state
end
