defmodule Hive.DistributedTest do
  use ExUnit.Case

  alias Hive.Distributed

  test "detects self as member" do
    members = Distributed.members()
    assert Node.self() in members
  end

  test "spawns task on cluster (local fallback)" do
    # In test environment, single node cluster
    pid = Distributed.spawn_on_cluster(fn -> :ok end)
    assert is_pid(pid)
  end
end
