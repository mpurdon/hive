defmodule Hive.TestDriver.Reporter do
  @moduledoc """
  Formats E2E test results for terminal output and JSON reports.

  Collects scenario results and produces:
  - Colored terminal output with pass/fail and timing
  - Full timeline for failed scenarios
  - JSON report at `_build/test/e2e_report.json`
  """

  @report_path "_build/test/e2e_report.json"

  @type scenario_result :: %{
          name: String.t(),
          status: :pass | :fail | :skip,
          duration_ms: non_neg_integer(),
          timeline: [map()],
          error: String.t() | nil
        }

  @type report :: %{
          run_at: String.t(),
          duration_ms: non_neg_integer(),
          scenarios: [scenario_result()],
          summary: %{total: integer(), passed: integer(), failed: integer(), skipped: integer()}
        }

  @doc """
  Formats scenario results for terminal output.

  Returns an IO list of colored strings.
  """
  @spec format_terminal([scenario_result()]) :: iodata()
  def format_terminal(results) do
    header = ["\n", IO.ANSI.bright(), "== Hive E2E Test Results ==", IO.ANSI.reset(), "\n\n"]

    lines =
      Enum.map(results, fn result ->
        {icon, color} =
          case result.status do
            :pass -> {"PASS", IO.ANSI.green()}
            :fail -> {"FAIL", IO.ANSI.red()}
            :skip -> {"SKIP", IO.ANSI.yellow()}
          end

        line = [
          "  ",
          color,
          icon,
          IO.ANSI.reset(),
          " ",
          result.name,
          IO.ANSI.faint(),
          " (#{result.duration_ms}ms)",
          IO.ANSI.reset(),
          "\n"
        ]

        if result.status == :fail do
          error_lines = [
            IO.ANSI.red(),
            "       ",
            result.error || "Unknown error",
            IO.ANSI.reset(),
            "\n",
            format_timeline_excerpt(result.timeline),
            "\n"
          ]

          [line, error_lines]
        else
          line
        end
      end)

    summary = build_summary(results)

    summary_line = [
      "\n",
      IO.ANSI.bright(),
      "  #{summary.total} scenarios: ",
      IO.ANSI.green(),
      "#{summary.passed} passed",
      IO.ANSI.reset(),
      if(summary.failed > 0,
        do: [", ", IO.ANSI.red(), "#{summary.failed} failed", IO.ANSI.reset()],
        else: []
      ),
      if(summary.skipped > 0,
        do: [", ", IO.ANSI.yellow(), "#{summary.skipped} skipped", IO.ANSI.reset()],
        else: []
      ),
      "\n\n"
    ]

    [header, lines, summary_line]
  end

  @doc """
  Writes a JSON report to `_build/test/e2e_report.json`.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec write_json([scenario_result()]) :: :ok | {:error, term()}
  def write_json(results) do
    summary = build_summary(results)
    total_duration = results |> Enum.map(& &1.duration_ms) |> Enum.sum()

    report = %{
      run_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      duration_ms: total_duration,
      scenarios:
        Enum.map(results, fn r ->
          %{
            name: r.name,
            status: to_string(r.status),
            duration_ms: r.duration_ms,
            timeline: sanitize_timeline(r.timeline),
            error: r.error
          }
        end),
      summary: summary
    }

    dir = Path.dirname(@report_path)
    File.mkdir_p!(dir)

    case Jason.encode(report, pretty: true) do
      {:ok, json} ->
        File.write!(@report_path, json)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Returns the default report path."
  @spec report_path() :: String.t()
  def report_path, do: @report_path

  # -- Private -----------------------------------------------------------------

  defp build_summary(results) do
    %{
      total: length(results),
      passed: Enum.count(results, &(&1.status == :pass)),
      failed: Enum.count(results, &(&1.status == :fail)),
      skipped: Enum.count(results, &(&1.status == :skip))
    }
  end

  defp format_timeline_excerpt(timeline) do
    entries = Enum.take(timeline, -10)

    if entries == [] do
      ["       ", IO.ANSI.faint(), "(no timeline entries)", IO.ANSI.reset()]
    else
      Enum.map(entries, fn entry ->
        [
          "       ",
          IO.ANSI.faint(),
          "[#{entry.type}] #{inspect(entry.event)}",
          IO.ANSI.reset(),
          "\n"
        ]
      end)
    end
  end

  defp sanitize_timeline(timeline) do
    Enum.map(timeline, fn entry ->
      %{
        type: to_string(entry.type),
        event: inspect(entry.event),
        at_us: entry.at_us,
        data: safe_inspect(entry.data)
      }
    end)
  end

  defp safe_inspect(data) when is_map(data) do
    inspect(data, limit: 10, printable_limit: 500)
  end

  defp safe_inspect(data), do: inspect(data, limit: 10, printable_limit: 500)
end
