defmodule HiveTest do
  use ExUnit.Case, async: false

  describe "version/0" do
    test "returns the project version as a string" do
      version = Hive.version()

      assert is_binary(version)
      assert version =~ ~r/^\d+\.\d+\.\d+/
    end
  end

  describe "hive_dir/0" do
    test "returns {:error, :not_in_hive} when no .hive directory exists" do
      # Clear any HIVE_PATH env var for this test
      original = System.get_env("HIVE_PATH")
      System.delete_env("HIVE_PATH")

      # Use a temp dir that has no .hive/ marker
      tmp = Path.join(System.tmp_dir!(), "hive_no_marker_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(tmp)
      original_cwd = File.cwd!()
      File.cd!(tmp)

      on_exit(fn ->
        File.cd!(original_cwd)
        File.rm_rf!(tmp)
        if original, do: System.put_env("HIVE_PATH", original)
      end)

      assert {:error, :not_in_hive} = Hive.hive_dir()
    end

    test "finds a .hive directory via HIVE_PATH env var" do
      tmp = System.tmp_dir!()
      hive_root = Path.join(tmp, "hive_test_#{:erlang.unique_integer([:positive])}")
      hive_marker = Path.join(hive_root, ".hive")
      File.mkdir_p!(hive_marker)

      on_exit(fn -> File.rm_rf!(hive_root) end)

      System.put_env("HIVE_PATH", hive_root)

      on_exit(fn -> System.delete_env("HIVE_PATH") end)

      assert {:ok, ^hive_root} = Hive.hive_dir()
    end
  end
end
