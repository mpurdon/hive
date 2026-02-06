defmodule Hive.ConfigTest do
  use ExUnit.Case, async: true

  alias Hive.Config

  @tmp_dir System.tmp_dir!()

  defp tmp_path(name) do
    Path.join(@tmp_dir, "hive_config_test_#{:erlang.unique_integer([:positive])}_#{name}")
  end

  describe "default_config/0" do
    test "returns a map with hive, queen, and costs sections" do
      config = Config.default_config()

      assert config["hive"]["version"] == Hive.version()
      assert config["queen"]["max_bees"] == 5
      assert config["costs"]["warn_threshold_usd"] == 5.0
    end
  end

  describe "write_config/2 and read_config/1" do
    test "round-trips the default config through TOML" do
      path = tmp_path("config.toml")
      on_exit(fn -> File.rm(path) end)

      assert :ok = Config.write_config(path)
      assert {:ok, parsed} = Config.read_config(path)

      assert parsed["hive"]["version"] == Hive.version()
      assert parsed["queen"]["max_bees"] == 5
      assert parsed["costs"]["warn_threshold_usd"] == 5.0
    end

    test "writes custom config values" do
      path = tmp_path("custom.toml")
      on_exit(fn -> File.rm(path) end)

      custom = %{
        "hive" => %{"version" => "99.0.0"},
        "queen" => %{"max_bees" => 10}
      }

      assert :ok = Config.write_config(path, custom)
      assert {:ok, parsed} = Config.read_config(path)

      assert parsed["hive"]["version"] == "99.0.0"
      assert parsed["queen"]["max_bees"] == 10
    end

    test "returns error for non-existent file" do
      assert {:error, _} = Config.read_config("/nonexistent/path/config.toml")
    end
  end
end
