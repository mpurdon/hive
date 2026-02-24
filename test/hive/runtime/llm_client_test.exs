defmodule Hive.Runtime.LLMClientTest do
  use ExUnit.Case, async: true

  alias Hive.Runtime.LLMClient

  describe "impl/0" do
    test "returns the default implementation module" do
      impl = LLMClient.impl()
      assert is_atom(impl)
      assert impl == Hive.Runtime.LLMClient.Default
    end
  end

  describe "Default module" do
    test "implements the LLMClient behaviour" do
      behaviours =
        Hive.Runtime.LLMClient.Default.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Hive.Runtime.LLMClient in behaviours
    end
  end
end
