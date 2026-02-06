import Config

config :hive, Hive.Repo,
  database: Path.join(System.tmp_dir!(), "hive_test_#{System.unique_integer([:positive])}.db"),
  pool_size: 1

config :hive, Hive.Dashboard.Endpoint,
  http: [port: 4002],
  server: false

config :logger, level: :warning
