defmodule GiTF.Queen.AuditTest do
  use ExUnit.Case, async: true

  alias GiTF.Queen.Audit

  describe "inside_gitf_dir?/2" do
    test "returns true for path inside .gitf" do
      assert Audit.inside_gitf_dir?("/project/.gitf/queen/QUEEN.md", "/project/.gitf")
    end

    test "returns true for .gitf dir itself" do
      assert Audit.inside_gitf_dir?("/project/.gitf", "/project/.gitf")
    end

    test "returns false for path outside .gitf" do
      refute Audit.inside_gitf_dir?("/project/src/app.ex", "/project/.gitf")
    end

    test "returns false for expanded traversal path" do
      # inside_gitf_dir? works on already-expanded paths;
      # traversal prevention happens in check_file_access via Path.expand
      expanded = Path.expand("/project/.gitf/../src/app.ex")
      refute Audit.inside_gitf_dir?(expanded, "/project/.gitf")
    end

    test "returns false for partial prefix match" do
      refute Audit.inside_gitf_dir?("/project/.gitf_other/foo", "/project/.gitf")
    end
  end

  describe "check_file_access/2" do
    test "returns :ok for path inside .gitf" do
      # Use a real-ish path structure
      gitf_root = System.tmp_dir!()
      gitf_dir = Path.join(gitf_root, ".gitf")
      path = Path.join([gitf_dir, "queen", "QUEEN.md"])

      assert :ok = Audit.check_file_access(path, gitf_root)
    end

    test "returns error for path outside .gitf" do
      gitf_root = System.tmp_dir!()
      path = Path.join(gitf_root, "src/app.ex")

      assert {:error, :delegation_required} = Audit.check_file_access(path, gitf_root)
    end

    test "handles traversal attack via Path.expand" do
      gitf_root = System.tmp_dir!()
      path = Path.join([gitf_root, ".gitf", "..", "src", "app.ex"])

      assert {:error, :delegation_required} = Audit.check_file_access(path, gitf_root)
    end
  end
end
