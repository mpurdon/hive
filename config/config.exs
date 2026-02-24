import Config

config :hive, Hive.Web.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [],
  secret_key_base: "HIVE_SECRET_KEY_BASE_CHANGEME_1234567890",
  pubsub_server: Hive.PubSub,
  live_view: [signing_salt: "hive_live_salt_123"],
  render_errors: [
    formats: [html: Hive.Web.ErrorHTML, json: Hive.Web.ErrorJSON],
    layout: false
  ]

config :hive, :llm,
  execution_mode: :cli,
  default_models: %{
    opus: "anthropic:claude-opus-4-6",
    sonnet: "anthropic:claude-sonnet-4-6",
    haiku: "anthropic:claude-haiku-4-5",
    fast: "google:gemini-2.0-flash"
  }

# Allow ReqLLM to load API keys from .env files when present
config :req_llm, load_dotenv: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
