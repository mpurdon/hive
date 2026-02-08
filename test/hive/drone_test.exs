defmodule Hive.DroneTest do
  use ExUnit.Case, async: false

  alias Hive.Drone

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "hive_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    if Process.whereis(Hive.Store), do: GenServer.stop(Hive.Store)
    {:ok, _} = Hive.Store.start_link(data_dir: tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    # Ensure no drone is running before each test
    case Drone.lookup() do
      {:ok, pid} -> GenServer.stop(pid)
      :error -> :ok
    end

    :ok
  end

  describe "start_link/1" do
    test "starts the drone GenServer" do
      assert {:ok, pid} = Drone.start_link(poll_interval: 60_000)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "rejects duplicate start" do
      {:ok, pid} = Drone.start_link(poll_interval: 60_000)
      assert {:error, {:already_started, ^pid}} = Drone.start_link(poll_interval: 60_000)
      GenServer.stop(pid)
    end
  end

  describe "lookup/0" do
    test "finds running drone via Registry" do
      {:ok, pid} = Drone.start_link(poll_interval: 60_000)
      assert {:ok, ^pid} = Drone.lookup()
      GenServer.stop(pid)
    end

    test "returns :error when no drone is running" do
      assert :error = Drone.lookup()
    end
  end

  describe "last_results/0" do
    test "returns empty list initially" do
      {:ok, pid} = Drone.start_link(poll_interval: 60_000)
      assert Drone.last_results() == []
      GenServer.stop(pid)
    end
  end

  describe "check_now/0" do
    test "triggers an immediate patrol and returns results" do
      {:ok, pid} = Drone.start_link(poll_interval: 60_000)
      results = Drone.check_now()
      assert is_list(results)
      assert length(results) > 0

      Enum.each(results, fn r ->
        assert is_atom(r.name)
        assert r.status in [:ok, :warn, :error]
      end)

      GenServer.stop(pid)
    end

    test "results are persisted in last_results" do
      {:ok, pid} = Drone.start_link(poll_interval: 60_000)
      results = Drone.check_now()
      assert Drone.last_results() == results
      GenServer.stop(pid)
    end
  end

  describe "polling" do
    test "runs patrol on timer" do
      {:ok, pid} = Drone.start_link(poll_interval: 100)
      # Wait for at least one patrol cycle
      Process.sleep(250)
      results = Drone.last_results()
      assert is_list(results)
      assert length(results) > 0
      GenServer.stop(pid)
    end
  end

  describe "fault tolerance" do
    test "handles unexpected messages gracefully" do
      {:ok, pid} = Drone.start_link(poll_interval: 60_000)
      send(pid, :unexpected_message)
      # Should still be alive
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
