defmodule GiTF.Web.DashboardTest do
  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  @endpoint GiTF.Web.Endpoint

  setup do
    GiTF.Test.StoreHelper.ensure_infrastructure()

    # The Web.Endpoint is started by the application supervisor.
    # Ensure it is alive and has its ETS table intact.
    endpoint_alive? =
      case Process.whereis(GiTF.Web.Endpoint) do
        nil -> false
        pid -> Process.alive?(pid)
      end

    ets_ok? =
      try do
        GiTF.Web.Endpoint.config(:pubsub_server)
        true
      rescue
        ArgumentError -> false
      end

    unless endpoint_alive? and ets_ok? do
      GiTF.Test.StoreHelper.safe_stop(GiTF.Web.Endpoint)
      Process.sleep(50)
      current = Application.get_env(:gitf, GiTF.Web.Endpoint, [])
      Application.put_env(:gitf, GiTF.Web.Endpoint, Keyword.put(current, :server, false))
      {:ok, _} = GiTF.Web.Endpoint.start_link([])
    end

    :ok
  end

  test "dashboard renders successfully" do
    conn = Phoenix.ConnTest.build_conn()
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "GiTF Control Plane"
    assert html =~ "Active Ghosts"
  end
end
