defmodule Hive.Web.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Hive.Web.Layout, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", Hive.Web do
    pipe_through :browser

    live "/", Live.Dashboard
  end
end
