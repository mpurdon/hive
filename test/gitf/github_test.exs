defmodule GiTF.GitHubTest do
  use ExUnit.Case, async: true

  alias GiTF.GitHub

  describe "client/1" do
    test "returns error when sector has no github config" do
      sector = %{
        id: "cmb-test",
        name: "test",
        github_owner: nil,
        github_repo: nil
      }

      assert {:error, :no_github_config} = GitHub.client(sector)
    end

    test "builds a client when github config is present" do
      sector = %{
        id: "cmb-test",
        name: "test",
        github_owner: "testorg",
        github_repo: "testrepo"
      }

      assert {:ok, %Req.Request{}} = GitHub.client(sector)
    end
  end

  describe "create_pr/3" do
    test "returns error when sector has no github config" do
      sector = %{id: "cmb-1", name: "t", github_owner: nil, github_repo: nil}

      shell = %{
        id: "cel-1",
        branch: "b",
        ghost_id: "ghost-1",
        sector_id: "cmb-1",
        worktree_path: "/tmp",
        status: "active"
      }

      op = %{id: "op-1", title: "t", status: "done", mission_id: "q", sector_id: "cmb-1"}

      assert {:error, :no_github_config} = GitHub.create_pr(sector, shell, op)
    end
  end

  describe "list_issues/2" do
    test "returns error when sector has no github config" do
      sector = %{id: "cmb-1", name: "t", github_owner: nil, github_repo: nil}
      assert {:error, :no_github_config} = GitHub.list_issues(sector)
    end
  end
end
