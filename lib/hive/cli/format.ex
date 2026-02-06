defmodule Hive.CLI.Format do
  @moduledoc "Terminal output formatting with ANSI color support."

  @doc "Prints an error message in red."
  @spec error(String.t()) :: :ok
  def error(message), do: put_styled(message, :red, "ERROR")

  @doc "Prints a success message in green."
  @spec success(String.t()) :: :ok
  def success(message), do: put_styled(message, :green, "OK")

  @doc "Prints an informational message in cyan."
  @spec info(String.t()) :: :ok
  def info(message), do: put_styled(message, :cyan, "INFO")

  @doc "Prints a warning message in yellow."
  @spec warn(String.t()) :: :ok
  def warn(message), do: put_styled(message, :yellow, "WARN")

  @doc """
  Renders a table with headers and rows to stdout.

  Headers is a list of column name strings. Rows is a list of lists,
  each inner list matching the header count.
  """
  @spec table([String.t()], [[String.t()]]) :: :ok
  def table(headers, rows) do
    all_rows = [headers | rows]

    widths =
      all_rows
      |> Enum.zip_with(fn column ->
        column |> Enum.map(&String.length/1) |> Enum.max()
      end)

    separator = widths |> Enum.map(&String.duplicate("-", &1)) |> Enum.join("-+-")
    format_row = fn row ->
      row
      |> Enum.zip(widths)
      |> Enum.map(fn {cell, width} -> String.pad_trailing(cell, width) end)
      |> Enum.join(" | ")
    end

    IO.puts(format_row.(headers))
    IO.puts(separator)
    Enum.each(rows, fn row -> IO.puts(format_row.(row)) end)
  end

  # -- Private helpers --------------------------------------------------------

  defp put_styled(message, color, label) do
    if color_enabled?() do
      IO.puts(apply(IO.ANSI, color, []) <> "[#{label}] " <> IO.ANSI.reset() <> message)
    else
      IO.puts("[#{label}] " <> message)
    end
  end

  defp color_enabled? do
    System.get_env("NO_COLOR") == nil
  end
end
