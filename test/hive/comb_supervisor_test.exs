defmodule Hive.CombSupervisorTest do
  use ExUnit.Case, async: false

  alias Hive.CombSupervisor

  # The CombSupervisor is already started by the Application supervisor,
  # so we test against the running instance.

  describe "active_count/0" do
    test "returns zero when no children are running" do
      # Clean up any leftover children first
      for pid <- CombSupervisor.children() do
        DynamicSupervisor.terminate_child(Hive.CombSupervisor, pid)
      end

      assert CombSupervisor.active_count() == 0
    end
  end

  describe "children/0" do
    test "returns an empty list when no children are running" do
      for pid <- CombSupervisor.children() do
        DynamicSupervisor.terminate_child(Hive.CombSupervisor, pid)
      end

      assert CombSupervisor.children() == []
    end
  end

  describe "start_child/1" do
    test "starts a temporary child process" do
      # Use a simple Task as a child
      child_spec = %{
        id: :test_child,
        start: {Task, :start_link, [fn -> Process.sleep(:infinity) end]},
        restart: :temporary
      }

      assert {:ok, pid} = CombSupervisor.start_child(child_spec)
      assert is_pid(pid)
      assert Process.alive?(pid)

      assert CombSupervisor.active_count() >= 1
      assert pid in CombSupervisor.children()

      # Clean up
      DynamicSupervisor.terminate_child(Hive.CombSupervisor, pid)
    end
  end
end
