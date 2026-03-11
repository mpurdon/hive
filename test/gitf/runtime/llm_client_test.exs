defmodule GiTF.Runtime.LLMClientTest do
  use ExUnit.Case, async: true

  alias GiTF.Runtime.LLMClient

  describe "impl/0" do
    test "returns the default implementation module" do
      impl = LLMClient.impl()
      assert is_atom(impl)
      assert impl == GiTF.Runtime.LLMClient.Default
    end
  end

  describe "Default module" do
    test "implements the LLMClient behaviour" do
      behaviours =
        GiTF.Runtime.LLMClient.Default.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert GiTF.Runtime.LLMClient in behaviours
    end
  end
end
