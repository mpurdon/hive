defmodule GiTF.DroneVerificationTest do
  use ExUnit.Case, async: false

  alias GiTF.{Store, Drone}

  setup do
    GiTF.Test.StoreHelper.ensure_infrastructure()

    # Restart store for testing
    GiTF.Test.StoreHelper.stop_store()
    {:ok, _} = Store.start_link(data_dir: System.tmp_dir!())

    # Stop any existing drone (e.g. started by Major during test setup)
    case Registry.lookup(GiTF.Registry, :drone) do
      [{pid, _}] ->
        try do
          GenServer.stop(pid, :normal, 1000)
        catch
          :exit, _ -> :ok
        end
      [] -> :ok
    end

    on_exit(fn ->
      case Process.whereis(GiTF.Registry) do
        nil -> :ok
        _ ->
          case Registry.lookup(GiTF.Registry, :drone) do
            [{pid, _}] ->
              try do
                GenServer.stop(pid, :normal, 1000)
              catch
                :exit, _ -> :ok
              end
            [] -> :ok
          end
      end
    end)

    :ok
  end

  describe "verification patrol" do
    test "patrol includes verification checking" do
      Process.flag(:trap_exit, true)
      # Start drone
      {:ok, pid} = Drone.start_link(poll_interval: 1000)

      # Trigger immediate patrol
      results = Drone.check_now()

      # Should return a list of results (may be empty)
      assert is_list(results)

      # Verification checking should not cause errors
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "drone starts with verify option" do
      Process.flag(:trap_exit, true)
      # Start drone with verify enabled
      {:ok, pid} = Drone.start_link(poll_interval: 1000, verify: true)

      # Should start successfully
      assert Process.alive?(pid)

      # Should be able to run patrol
      results = Drone.check_now()
      assert is_list(results)
      GenServer.stop(pid)
    end

    test "drone patrol handles verification gracefully" do
      Process.flag(:trap_exit, true)
      # Create a job that needs verification
      {:ok, _job} = Store.insert(:jobs, %{
        title: "Test job",
        status: "done",
        verification_status: "pending"
      })

      # Start drone
      {:ok, pid} = Drone.start_link(poll_interval: 1000)

      # Should start successfully even with jobs needing verification
      assert Process.alive?(pid)

      # Patrol should complete without errors
      results = Drone.check_now()
      assert is_list(results)
      GenServer.stop(pid)
    end
  end
end