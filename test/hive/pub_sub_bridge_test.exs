defmodule Hive.PubSubBridgeTest do
  use ExUnit.Case, async: false

  setup do
    Hive.Test.StoreHelper.ensure_infrastructure()

    # Ensure PubSubBridge is running. If it was killed by another test's cleanup
    # or lost its PubSub connection, restart it.
    unless Process.whereis(Hive.PubSubBridge) && Process.alive?(Process.whereis(Hive.PubSubBridge)) do
      try do
        Supervisor.terminate_child(Hive.Supervisor, Hive.PubSubBridge)
        Supervisor.delete_child(Hive.Supervisor, Hive.PubSubBridge)
      catch
        :exit, _ -> :ok
      end
      Hive.Test.StoreHelper.safe_stop(Hive.PubSubBridge)
      {:ok, _} = Hive.PubSubBridge.start_link([])
    end

    # Reattach telemetry handlers in case they were detached
    Hive.PubSubBridge.subscribe()
    :ok
  end

  test "broadcasts telemetry events to pubsub" do
    # Emit a test event
    Hive.Telemetry.emit([:hive, :bee, :spawned], %{count: 1}, %{bee_id: "test-bee"})

    # Assert we receive it
    assert_receive {:hive_event, payload}, 1000

    assert payload.event == "hive.bee.spawned"
    assert payload.measurements == %{count: 1}
    # PubSubBridge adds :node to metadata
    assert payload.metadata.bee_id == "test-bee"
    assert Map.has_key?(payload.metadata, :node)
    assert %DateTime{} = payload.timestamp
  end
end
