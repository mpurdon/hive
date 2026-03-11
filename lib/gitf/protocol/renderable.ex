defprotocol GiTF.Renderable do
  @moduledoc """
  Protocol for converting GiTF data types to TUI render tree elements.

  TUI components call `GiTF.Renderable.render(data)` instead of
  bespoke formatting functions. Implement for: link_msg messages,
  ghost status, op status, mission summary, telemetry events.
  """

  @doc "Convert to term_ui render tree elements."
  @spec render(t(), keyword()) :: term()
  def render(data, opts \\ [])
end
