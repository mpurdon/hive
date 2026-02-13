defmodule Hive.PluginTest do
  @moduledoc """
  Test helpers for Hive plugin development.

  Provides assertion helpers for validating plugins implement their
  behaviours correctly, mock managers, and telemetry simulation.
  """

  @doc "Validates a module implements the expected plugin behaviour."
  def assert_valid_plugin(module, type) do
    behaviour = Hive.Plugin.behaviour_for(type)
    callbacks = behaviour.behaviour_info(:callbacks)

    for {fun, arity} <- callbacks do
      unless function_exported?(module, fun, arity) do
        raise ExUnit.AssertionError,
          message:
            "#{inspect(module)} does not implement #{fun}/#{arity} from #{inspect(behaviour)}"
      end
    end

    :ok
  end

  @doc "Sets up an ETS registry with test plugins."
  def mock_manager(plugins) do
    Hive.Plugin.Registry.init()

    for {type, name, module} <- plugins do
      Hive.Plugin.Registry.register(type, name, module)
    end

    :ok
  end

  @doc "Fires a telemetry event in test."
  def simulate_telemetry(event, measurements \\ %{}, metadata \\ %{}) do
    :telemetry.execute(event, measurements, metadata)
  end

  @doc "Cleans up the plugin registry."
  def cleanup_registry do
    for {type, name, _module} <- Hive.Plugin.Registry.all() do
      Hive.Plugin.Registry.unregister(type, name)
    end

    :ok
  rescue
    _ -> :ok
  end
end
