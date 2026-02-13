defmodule Hive.Plugin.Registry do
  @moduledoc """
  ETS-backed plugin registry for fast reads.

  Stores `{type, name, module}` tuples in a named ETS table.
  The Plugin Manager owns writes (insert/delete); the TUI and other
  consumers read directly without process bottleneck.
  """

  @table :hive_plugins

  @doc "Creates the ETS table. Called once at startup."
  @spec init() :: :ok
  def init do
    :ets.new(@table, [:named_table, :public, :bag, read_concurrency: true])
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "Registers a plugin in the registry."
  @spec register(atom(), String.t(), module()) :: :ok
  def register(type, name, module) do
    :ets.insert(@table, {type, name, module})
    :ok
  end

  @doc "Unregisters a plugin from the registry."
  @spec unregister(atom(), String.t()) :: :ok
  def unregister(type, name) do
    :ets.match_delete(@table, {type, name, :_})
    :ok
  end

  @doc "Looks up a plugin by type and name."
  @spec lookup(atom(), String.t()) :: {:ok, module()} | :error
  def lookup(type, name) do
    case :ets.match(@table, {type, name, :"$1"}) do
      [[module] | _] -> {:ok, module}
      [] -> :error
    end
  rescue
    ArgumentError -> :error
  end

  @doc "Lists all plugins of a given type."
  @spec list(atom()) :: [{String.t(), module()}]
  def list(type) do
    :ets.match(@table, {type, :"$1", :"$2"})
    |> Enum.map(fn [name, module] -> {name, module} end)
  rescue
    ArgumentError -> []
  end

  @doc "Lists all registered plugins."
  @spec all() :: [{atom(), String.t(), module()}]
  def all do
    :ets.tab2list(@table)
  rescue
    ArgumentError -> []
  end
end
