defmodule Hive.Dashboard.SmokeTest do
  @moduledoc """
  Minimal smoke test to verify the dashboard boots and serves HTML.

  This complements the more thorough EndpointTest by verifying the most
  basic contract: the dashboard starts, responds to GET /, and returns
  HTML that identifies itself as the Hive dashboard.
  """
  use ExUnit.Case, async: false

  @moduletag :dashboard

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Hive.Repo)

    start_supervised!(Hive.Dashboard.Endpoint)
    :ok
  end

  test "dashboard returns 200 OK with Hive HTML" do
    conn =
      :get
      |> Plug.Test.conn("/")
      |> Hive.Dashboard.Endpoint.call(Hive.Dashboard.Endpoint.init([]))

    assert conn.status == 200
    assert String.contains?(conn.resp_body, "Hive")
    assert String.contains?(conn.resp_body, "<html")
  end

  test "response includes navigation links" do
    conn =
      :get
      |> Plug.Test.conn("/")
      |> Hive.Dashboard.Endpoint.call(Hive.Dashboard.Endpoint.init([]))

    body = conn.resp_body
    assert String.contains?(body, "Overview")
    assert String.contains?(body, "Quests")
    assert String.contains?(body, "Bees")
    assert String.contains?(body, "Costs")
    assert String.contains?(body, "Waggles")
  end
end
