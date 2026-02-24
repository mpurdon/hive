defmodule Hive.PubSubBridgeTest do
  use ExUnit.Case
  
  setup do
    # Ensure PubSub is started (it should be part of the app, but safe to check)
    # The Bridge is started by Application, so we just subscribe.
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
    assert payload.metadata == %{bee_id: "test-bee"}
    assert %DateTime{} = payload.timestamp
  end
end
