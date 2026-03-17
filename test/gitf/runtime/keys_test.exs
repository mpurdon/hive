defmodule GiTF.Runtime.KeysTest do
  use ExUnit.Case, async: false

  alias GiTF.Runtime.Keys

  describe "load/0" do
    test "returns a non-negative integer" do
      loaded = Keys.load()
      assert is_integer(loaded)
      assert loaded >= 0
    end
  end

  describe "status/0" do
    test "returns a list of provider availability tuples" do
      status = Keys.status()
      assert is_list(status)

      # Should include known providers (string keys)
      providers = Enum.map(status, fn {name, _} -> name end)
      assert "anthropic" in providers
      assert "google" in providers
      assert "openai" in providers

      # Values are booleans
      Enum.each(status, fn {_provider, available} ->
        assert is_boolean(available)
      end)
    end
  end
end
