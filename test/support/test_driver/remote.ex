defmodule Hive.TestDriver.Remote do
  @moduledoc """
  Optional distributed Erlang connection for running E2E tests
  against a live Hive instance.

  Start the target with:

      ERL_AFLAGS="-sname hive -setcookie hive_test" mix run --no-halt

  Then run tests with:

      mix hive.test.e2e --remote hive@hostname
  """

  @doc """
  Starts a local node and connects to the remote Hive instance.

  ## Options

    * `:cookie` - Erlang cookie (default: `:hive_test`)

  """
  @spec connect(String.t() | atom(), keyword()) :: :ok | {:error, term()}
  def connect(node, opts \\ []) do
    node = if is_binary(node), do: String.to_atom(node), else: node
    cookie = Keyword.get(opts, :cookie, :hive_test)

    local_name = :"hive_e2e_#{:erlang.unique_integer([:positive])}@127.0.0.1"

    case Node.start(local_name) do
      {:ok, _} ->
        Node.set_cookie(cookie)

        if Node.connect(node) do
          :ok
        else
          {:error, :connection_failed}
        end

      {:error, reason} ->
        {:error, {:node_start_failed, reason}}
    end
  end

  @doc """
  Executes a remote procedure call on the connected node.

  Wraps `:rpc.call/4` with a default timeout of 30 seconds.
  """
  @spec rpc(atom(), atom(), atom(), [term()], timeout()) :: term()
  def rpc(node, module, function, args, timeout \\ 30_000) do
    case :rpc.call(node, module, function, args, timeout) do
      {:badrpc, reason} -> {:error, {:rpc_failed, reason}}
      result -> result
    end
  end

  @doc "Returns true if connected to a remote node."
  @spec connected?() :: boolean()
  def connected? do
    Node.list() != []
  end
end
