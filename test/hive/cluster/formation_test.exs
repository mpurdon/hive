defmodule Hive.Cluster.FormationTest do
  use ExUnit.Case

  alias Hive.Cluster.Formation

  test "members/0 returns self" do
    members = Formation.members()
    assert Node.self() in members
  end
end
