defmodule Hive.Dashboard.Endpoint do
  @moduledoc """
  Phoenix endpoint for the Hive web dashboard.

  This endpoint is NOT started automatically in Application.ex. It is
  started on demand when the user runs `hive dashboard` from the CLI.
  This keeps the footprint small for normal orchestration work.
  """

  use Phoenix.Endpoint, otp_app: :hive

  @session_options [
    store: :cookie,
    key: "_hive_dashboard",
    signing_salt: "hive_salt",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:peer_data, session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :hive,
    only: ~w(assets)

  plug Plug.RequestId

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session, @session_options

  plug Hive.Dashboard.Router
end
