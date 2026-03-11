defmodule GiTF.Plugin.Builtin.LSP.Generic do
  @moduledoc """
  Generic stdio LSP client. Configurable per-language in `.gitf/config.toml`.

  Communicates with language servers via JSON-RPC over stdio, providing
  diagnostics and other language features.
  """

  use GenServer

  require Logger

  # -- Public API ------------------------------------------------------------

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Gets diagnostics for a file URI."
  @spec diagnostics(GenServer.server(), String.t()) :: [map()]
  def diagnostics(server, uri) do
    GenServer.call(server, {:diagnostics, uri})
  end

  # -- GenServer callbacks ---------------------------------------------------

  @impl true
  def init(opts) do
    cmd = Keyword.fetch!(opts, :command)
    args = Keyword.get(opts, :args, [])
    root = Keyword.get(opts, :root, File.cwd!())

    port =
      Port.open({:spawn_executable, cmd}, [
        :binary,
        :exit_status,
        :use_stdio,
        args: args
      ])

    state = %{
      port: port,
      root: root,
      diagnostics: %{},
      pending: %{},
      next_id: 1,
      buffer: ""
    }

    # Send initialize request
    state =
      send_request(state, "initialize", %{
        processId: System.pid() |> String.to_integer(),
        rootUri: "file://#{root}",
        capabilities: %{}
      })

    {:ok, state}
  end

  @impl true
  def handle_call({:diagnostics, uri}, _from, state) do
    diags = Map.get(state.diagnostics, uri, [])
    {:reply, diags, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    buffer = state.buffer <> data
    {messages, remaining} = parse_lsp_messages(buffer)
    state = %{state | buffer: remaining}
    state = Enum.reduce(messages, state, &handle_lsp_message/2)
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.warning("LSP server exited with status #{status}")
    {:stop, {:lsp_exit, status}, %{state | port: nil}}
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

    :ok
  end

  # -- Private ---------------------------------------------------------------

  defp send_request(state, method, params) do
    id = state.next_id
    body = Jason.encode!(%{jsonrpc: "2.0", id: id, method: method, params: params})
    header = "Content-Length: #{byte_size(body)}\r\n\r\n"
    Port.command(state.port, header <> body)
    %{state | next_id: id + 1}
  end

  defp parse_lsp_messages(buffer) do
    case Regex.run(~r/Content-Length: (\d+)\r\n\r\n(.+)/s, buffer) do
      [_full, length_str, rest] ->
        length = String.to_integer(length_str)

        if byte_size(rest) >= length do
          <<body::binary-size(length), remaining::binary>> = rest

          case Jason.decode(body) do
            {:ok, message} ->
              {more_messages, final_remaining} = parse_lsp_messages(remaining)
              {[message | more_messages], final_remaining}

            {:error, _} ->
              {[], buffer}
          end
        else
          {[], buffer}
        end

      _ ->
        {[], buffer}
    end
  end

  defp handle_lsp_message(
         %{"method" => "textDocument/publishDiagnostics", "params" => params},
         state
       ) do
    uri = params["uri"]
    diags = params["diagnostics"] || []
    %{state | diagnostics: Map.put(state.diagnostics, uri, diags)}
  end

  defp handle_lsp_message(%{"id" => _id, "result" => _result}, state) do
    # Response to our request — for now just acknowledge
    state
  end

  defp handle_lsp_message(_msg, state), do: state
end
