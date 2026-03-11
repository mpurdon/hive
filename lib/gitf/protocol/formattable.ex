defprotocol GiTF.Formattable do
  @moduledoc """
  Protocol for formatting GiTF data for external messaging channels.

  Channels call `GiTF.Formattable.format(event, :telegram)` to get
  channel-appropriate output (Telegram markdown, Discord embeds, plain text).
  """

  @doc "Format data for the given channel type."
  @spec format(t(), atom()) :: String.t()
  def format(data, channel_type)
end
