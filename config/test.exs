import Config

config :hive, Hive.Repo,
  database: Path.join(System.tmp_dir!(), "hive_test_#{System.unique_integer([:positive])}.db"),
  pool_size: 1

config :hive, Hive.Dashboard.Endpoint,
  http: [port: 4002],
  server: false,
  secret_key_base: "test_secret_key_base_at_least_64_bytes_long_for_phoenix_endpoint_testing_abcdefghij",
  render_errors: [formats: [html: Hive.Dashboard.ErrorHTML], layout: false],
  pubsub_server: Hive.PubSub,
  live_view: [signing_salt: "hive_dashboard_test_salt"]

config :logger, level: :warning
