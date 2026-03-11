defmodule GiTF.Cluster.FormationTest do
  use ExUnit.Case

  alias GiTF.Cluster.Formation

  test "members/0 returns self" do
    members = Formation.members()
    assert Node.self() in members
  end
end
