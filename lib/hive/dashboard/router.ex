defmodule Hive.Dashboard.Router do
  @moduledoc "Routes for the Hive web dashboard."

  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Hive.Dashboard.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", Hive.Dashboard do
    pipe_through :browser

    live "/", OverviewLive
    live "/quests", QuestsLive
    live "/bees", BeesLive
    live "/costs", CostsLive
    live "/waggles", WagglesLive
    live "/progress", ProgressLive
  end
end
