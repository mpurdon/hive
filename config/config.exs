import Config

config :hive, ecto_repos: [Hive.Repo]

config :hive, Hive.Dashboard.Endpoint,
  http: [port: 4040],
  url: [host: "localhost"],
  secret_key_base: String.duplicate("hive_secret", 8),
  render_errors: [formats: [html: Hive.Dashboard.ErrorHTML]],
  pubsub_server: Hive.PubSub,
  live_view: [signing_salt: "hive_live"],
  server: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
