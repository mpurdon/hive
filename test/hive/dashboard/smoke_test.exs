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
    tmp_dir = Path.join(System.tmp_dir!(), "hive_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    if Process.whereis(Hive.Store), do: GenServer.stop(Hive.Store)
    {:ok, _} = Hive.Store.start_link(data_dir: tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

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
