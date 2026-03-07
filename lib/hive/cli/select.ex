defmodule Hive.CLI.Select do
  @moduledoc """
  Arrow-key driven selection prompts for the CLI.

  Supports single-select (enter to pick) and multi-select (space to toggle,
  enter to confirm). Uses raw terminal mode via stty and reads directly
  from /dev/tty for reliable keypress detection.
  """

  @doc """
  Single-select: arrow keys to navigate, enter to confirm.
  Returns the selected option string, or nil if cancelled.
  """
  def select(prompt, options) when is_list(options) and options != [] do
    count = length(options)

    IO.puts("")
    IO.puts("  " <> IO.ANSI.cyan() <> prompt <> IO.ANSI.reset())
    IO.puts("  " <> IO.ANSI.faint() <> "↑/↓ navigate · enter select · esc cancel" <> IO.ANSI.reset())
    IO.puts("")
    for _ <- 1..count, do: IO.write("\n")

    result =
      with_raw_mode(fn tty ->
        IO.write("\e[?25l")
        result = select_loop(tty, options, 0, count)
        IO.write("\e[?25h")
        result
      end)

    clear_menu(count)

    case result do
      {:ok, idx} ->
        selected = Enum.at(options, idx)
        IO.puts("  " <> IO.ANSI.faint() <> "→ " <> selected <> IO.ANSI.reset())
        selected

      :cancelled ->
        nil
    end
  end

  def select(_prompt, _options), do: nil

  @doc """
  Multi-select: arrow keys to navigate, space to toggle, enter to confirm.
  Returns list of selected option strings, or nil if cancelled.
  """
  def multi_select(prompt, options) when is_list(options) and options != [] do
    count = length(options)

    IO.puts("")
    IO.puts("  " <> IO.ANSI.cyan() <> prompt <> IO.ANSI.reset())
    IO.puts(
      "  " <>
        IO.ANSI.faint() <>
        "↑/↓ navigate · space toggle · enter confirm · esc cancel" <> IO.ANSI.reset()
    )

    IO.puts("")
    for _ <- 1..count, do: IO.write("\n")

    result =
      with_raw_mode(fn tty ->
        IO.write("\e[?25l")
        result = multi_loop(tty, options, 0, MapSet.new(), count)
        IO.write("\e[?25h")
        result
      end)

    clear_menu(count)

    case result do
      {:ok, selected_set} ->
        items =
          selected_set
          |> MapSet.to_list()
          |> Enum.sort()
          |> Enum.map(&Enum.at(options, &1))

        Enum.each(items, fn item ->
          IO.puts("  " <> IO.ANSI.faint() <> "→ " <> item <> IO.ANSI.reset())
        end)

        if items == [], do: nil, else: items

      :cancelled ->
        nil
    end
  end

  def multi_select(_prompt, _options), do: nil

  # -- Single select loop ------------------------------------------------------

  defp select_loop(tty, options, cursor, count) do
    render_single(options, cursor, count)

    case read_key(tty) do
      :up -> select_loop(tty, options, max(cursor - 1, 0), count)
      :down -> select_loop(tty, options, min(cursor + 1, count - 1), count)
      :enter -> {:ok, cursor}
      :escape -> :cancelled
      _ -> select_loop(tty, options, cursor, count)
    end
  end

  # -- Multi select loop -------------------------------------------------------

  defp multi_loop(tty, options, cursor, selected, count) do
    render_multi(options, cursor, selected, count)

    case read_key(tty) do
      :up ->
        multi_loop(tty, options, max(cursor - 1, 0), selected, count)

      :down ->
        multi_loop(tty, options, min(cursor + 1, count - 1), selected, count)

      :space ->
        toggled =
          if MapSet.member?(selected, cursor),
            do: MapSet.delete(selected, cursor),
            else: MapSet.put(selected, cursor)

        multi_loop(tty, options, cursor, toggled, count)

      :enter ->
        {:ok, selected}

      :escape ->
        :cancelled

      _ ->
        multi_loop(tty, options, cursor, selected, count)
    end
  end

  # -- Rendering ---------------------------------------------------------------

  defp render_single(options, cursor, count) do
    IO.write("\e[#{count}A")

    Enum.with_index(options, fn opt, idx ->
      if idx == cursor do
        IO.write(
          "\r\e[2K  " <>
            IO.ANSI.cyan() <> "❯ " <> IO.ANSI.bright() <> opt <> IO.ANSI.reset() <> "\r\n"
        )
      else
        IO.write("\r\e[2K    " <> opt <> "\r\n")
      end
    end)
  end

  defp render_multi(options, cursor, selected, count) do
    IO.write("\e[#{count}A")

    Enum.with_index(options, fn opt, idx ->
      active = idx == cursor
      checked = MapSet.member?(selected, idx)

      ptr = if active, do: IO.ANSI.cyan() <> "❯ ", else: "  "

      box =
        if checked,
          do: IO.ANSI.green() <> "◉ " <> IO.ANSI.reset(),
          else: IO.ANSI.faint() <> "◯ " <> IO.ANSI.reset()

      txt = if active, do: IO.ANSI.bright() <> opt <> IO.ANSI.reset(), else: opt

      IO.write("\r\e[2K  " <> ptr <> box <> txt <> IO.ANSI.reset() <> "\r\n")
    end)
  end

  # -- Terminal control --------------------------------------------------------

  defp clear_menu(count) do
    IO.write("\e[#{count}A")
    for _ <- 1..count, do: IO.write("\e[2K\n")
    IO.write("\e[#{count}A")
  end

  defp with_raw_mode(fun) do
    case System.cmd("stty", ["-g"], stderr_to_stdout: true) do
      {settings, 0} ->
        settings = String.trim(settings)
        System.cmd("stty", ["raw", "-echo"], stderr_to_stdout: true)
        {:ok, tty} = :file.open(~c"/dev/tty", [:read, :raw, :binary])

        try do
          fun.(tty)
        after
          :file.close(tty)
          System.cmd("stty", [settings], stderr_to_stdout: true)
        end

      _ ->
        # Cannot use raw mode — fall back with nil tty (reads will return :unknown)
        fun.(nil)
    end
  end

  defp read_key(nil), do: :unknown

  defp read_key(tty) do
    case :file.read(tty, 1) do
      {:ok, <<27>>} ->
        case :file.read(tty, 1) do
          {:ok, "["} ->
            case :file.read(tty, 1) do
              {:ok, "A"} -> :up
              {:ok, "B"} -> :down
              _ -> :unknown
            end

          _ ->
            :escape
        end

      {:ok, <<13>>} -> :enter
      {:ok, <<10>>} -> :enter
      {:ok, <<32>>} -> :space
      {:ok, <<3>>} -> :escape
      {:ok, "j"} -> :down
      {:ok, "k"} -> :up
      _ -> :unknown
    end
  end
end
