defmodule Hive.Web.DashboardTest do
  use ExUnit.Case
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  # We need to start the endpoint for this test
  @endpoint Hive.Web.Endpoint

  test "dashboard renders successfully" do
    conn = Phoenix.ConnTest.build_conn()
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "Hive Control Plane"
    assert html =~ "Active Bees"
  end
end
