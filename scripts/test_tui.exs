defmodule TUITest do
  def run do
    options = ["Option A", "Option B", "Option C"]
    IO.puts("Prompt:")
    Enum.each(options, &IO.puts/1)
    
    stty_save = System.cmd("stty", ["-g"], stderr_to_stdout: true) |> elem(0) |> String.trim()
    System.cmd("stty", ["raw", "-echo"], stderr_to_stdout: true)
    
    try do
      loop(0, length(options))
    after
      System.cmd("stty", [stty_save], stderr_to_stdout: true)
    end
  end

  defp loop(idx, count) do
    case IO.getn(:stdio, "", 1) do
      "\r" -> idx
      "\n" -> idx
      "\e" ->
        # arrow keys are \e[A, \e[B, etc.
        case IO.getn(:stdio, "", 2) do
          "[A" -> loop(max(0, idx - 1), count)
          "[B" -> loop(min(count - 1, idx + 1), count)
          _ -> loop(idx, count)
        end
      _ -> loop(idx, count)
    end
  end
end

TUITest.run()
