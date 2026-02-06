defmodule Hive.GitTest do
  use ExUnit.Case, async: true

  alias Hive.Git

  describe "local_path?/1" do
    test "recognizes absolute paths" do
      assert Git.local_path?("/home/user/repo")
      assert Git.local_path?("/tmp/project")
    end

    test "recognizes relative paths starting with dot" do
      assert Git.local_path?("./my-repo")
      assert Git.local_path?("../parent-repo")
    end

    test "recognizes home-relative paths" do
      assert Git.local_path?("~/projects/repo")
    end

    test "recognizes bare directory names as local" do
      assert Git.local_path?("my-project")
      assert Git.local_path?("some/nested/path")
    end

    test "rejects HTTPS URLs" do
      refute Git.local_path?("https://github.com/user/repo.git")
      refute Git.local_path?("http://example.com/repo")
    end

    test "rejects SSH URLs" do
      refute Git.local_path?("git@github.com:user/repo.git")
    end

    test "rejects git:// protocol" do
      refute Git.local_path?("git://example.com/repo.git")
    end
  end

  describe "git_version/0" do
    test "returns a version string when git is installed" do
      assert {:ok, version} = Git.git_version()
      assert version =~ ~r/\d+\.\d+/
    end
  end

  describe "repo?/1" do
    test "returns false for a non-repo directory" do
      tmp = Path.join(System.tmp_dir!(), "hive_git_test_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      refute Git.repo?(tmp)
    end

    test "returns false for a non-existent path" do
      refute Git.repo?("/nonexistent/path/#{:erlang.unique_integer([:positive])}")
    end
  end
end
