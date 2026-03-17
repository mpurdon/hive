defmodule GiTF.Plugin.Channel do
  @moduledoc """
  Behaviour for messaging channel plugins (Telegram, Discord, Slack, etc.).

  Channels are long-running GenServers under `GiTF.Plugin.ChannelSupervisor`.
  They bridge PubSub <-> external services bidirectionally.

  **Outbound** (factory -> you): Channel attaches telemetry handlers for
  configured events and forwards them as external messages. Uses
  `GiTF.Formattable` protocol for channel-appropriate formatting.

  **Inbound** (you -> factory): Channel receives messages from external API,
  parses them as commands, and publishes to PubSub or calls Manager.
  """

  @callback name() :: String.t()
  @callback start_link(config :: map()) :: GenServer.on_start()
  @callback send_message(pid(), text :: String.t(), opts :: keyword()) :: :ok | {:error, term()}
  @callback send_notification(pid(), event :: atom(), payload :: map()) :: :ok | {:error, term()}
  @callback subscriptions() :: [String.t()]

  @doc "Confirm delivery of a message. Override for reliable delivery."
  @callback acknowledge(ref :: term()) :: :ok

  @doc "Retry policy for failed sends."
  @callback retry_policy() :: %{max_retries: integer(), backoff: :exponential | :linear}

  @optional_callbacks acknowledge: 1, retry_policy: 0
end
