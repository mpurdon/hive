defprotocol Hive.Renderable do
  @moduledoc """
  Protocol for converting Hive data types to TUI render tree elements.

  TUI components call `Hive.Renderable.render(data)` instead of
  bespoke formatting functions. Implement for: waggle messages,
  bee status, job status, quest summary, telemetry events.
  """

  @doc "Convert to term_ui render tree elements."
  @spec render(t(), keyword()) :: term()
  def render(data, opts \\ [])
end
