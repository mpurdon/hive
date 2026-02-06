defmodule HiveTest do
  use ExUnit.Case, async: true

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

      on_exit(fn ->
        if original, do: System.put_env("HIVE_PATH", original)
      end)

      # From the project root there should be no .hive/ directory
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
