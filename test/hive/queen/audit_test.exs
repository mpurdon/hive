defmodule Hive.Queen.AuditTest do
  use ExUnit.Case, async: true

  alias Hive.Queen.Audit

  describe "inside_hive_dir?/2" do
    test "returns true for path inside .hive" do
      assert Audit.inside_hive_dir?("/project/.hive/queen/QUEEN.md", "/project/.hive")
    end

    test "returns true for .hive dir itself" do
      assert Audit.inside_hive_dir?("/project/.hive", "/project/.hive")
    end

    test "returns false for path outside .hive" do
      refute Audit.inside_hive_dir?("/project/src/app.ex", "/project/.hive")
    end

    test "returns false for expanded traversal path" do
      # inside_hive_dir? works on already-expanded paths;
      # traversal prevention happens in check_file_access via Path.expand
      expanded = Path.expand("/project/.hive/../src/app.ex")
      refute Audit.inside_hive_dir?(expanded, "/project/.hive")
    end

    test "returns false for partial prefix match" do
      refute Audit.inside_hive_dir?("/project/.hive_other/foo", "/project/.hive")
    end
  end

  describe "check_file_access/2" do
    test "returns :ok for path inside .hive" do
      # Use a real-ish path structure
      hive_root = System.tmp_dir!()
      hive_dir = Path.join(hive_root, ".hive")
      path = Path.join([hive_dir, "queen", "QUEEN.md"])

      assert :ok = Audit.check_file_access(path, hive_root)
    end

    test "returns error for path outside .hive" do
      hive_root = System.tmp_dir!()
      path = Path.join(hive_root, "src/app.ex")

      assert {:error, :delegation_required} = Audit.check_file_access(path, hive_root)
    end

    test "handles traversal attack via Path.expand" do
      hive_root = System.tmp_dir!()
      path = Path.join([hive_root, ".hive", "..", "src", "app.ex"])

      assert {:error, :delegation_required} = Audit.check_file_access(path, hive_root)
    end
  end
end
