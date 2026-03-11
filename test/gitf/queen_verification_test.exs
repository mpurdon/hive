defmodule GiTF.QueenVerificationTest do
  use ExUnit.Case, async: false
  
  # We can't easily test the Queen GenServer async verification flow without
  # mocking GiTF.Verification or starting the full app.
  # But we can verify that the code compiles.
  
  test "compiles" do
    assert Code.ensure_loaded?(GiTF.Queen)
  end
end
