import Config

config :gitf, GiTF.Repo, database: ".gitf/gitf.db"

config :gitf, GiTF.Web.Endpoint,
  code_reloader: true,
  live_reload: [
    patterns: [
      ~r"lib/gitf/web/live/.*(ex)$",
      ~r"lib/gitf/web/layout.*(ex)$"
    ]
  ]

config :logger, level: :debug
