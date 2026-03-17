defmodule TUITest do
  def run do
    Owl.IO.select(["Option A", "Option B"], label: "Choose")
  end
end
TUITest.run()