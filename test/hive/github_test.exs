defmodule Hive.GitHubTest do
  use ExUnit.Case, async: true

  alias Hive.GitHub

  describe "client/1" do
    test "returns error when comb has no github config" do
      comb = %Hive.Schema.Comb{
        id: "cmb-test",
        name: "test",
        github_owner: nil,
        github_repo: nil
      }

      assert {:error, :no_github_config} = GitHub.client(comb)
    end

    test "builds a client when github config is present" do
      comb = %Hive.Schema.Comb{
        id: "cmb-test",
        name: "test",
        github_owner: "testorg",
        github_repo: "testrepo"
      }

      assert {:ok, %Req.Request{}} = GitHub.client(comb)
    end
  end

  describe "create_pr/3" do
    test "returns error when comb has no github config" do
      comb = %Hive.Schema.Comb{id: "cmb-1", name: "t", github_owner: nil, github_repo: nil}
      cell = %Hive.Schema.Cell{id: "cel-1", branch: "b", bee_id: "bee-1", comb_id: "cmb-1", worktree_path: "/tmp", status: "active"}
      job = %Hive.Schema.Job{id: "job-1", title: "t", status: "done", quest_id: "q", comb_id: "cmb-1"}

      assert {:error, :no_github_config} = GitHub.create_pr(comb, cell, job)
    end
  end

  describe "list_issues/2" do
    test "returns error when comb has no github config" do
      comb = %Hive.Schema.Comb{id: "cmb-1", name: "t", github_owner: nil, github_repo: nil}
      assert {:error, :no_github_config} = GitHub.list_issues(comb)
    end
  end
end
