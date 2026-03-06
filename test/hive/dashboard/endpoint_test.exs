defmodule Hive.Dashboard.EndpointTest do
  use ExUnit.Case, async: false

  @moduletag :dashboard

  setup_all do
    Hive.Test.StoreHelper.ensure_infrastructure()

    # Ensure Store is running (use the app's store)
    unless Process.whereis(Hive.Store) do
      tmp_dir = Path.join(System.tmp_dir!(), "hive_dashboard_test_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(tmp_dir)
      Hive.Store.start_link(data_dir: tmp_dir)
    end

    # Ensure the Dashboard.Endpoint has required config
    current_config = Application.get_env(:hive, Hive.Dashboard.Endpoint, [])
    unless Keyword.has_key?(current_config, :secret_key_base) do
      config = Keyword.merge(current_config, [
        secret_key_base: "test_secret_key_base_at_least_64_bytes_long_for_phoenix_endpoint_testing_abcdefghij",
        pubsub_server: Hive.PubSub,
        live_view: [signing_salt: "hive_dashboard_test_salt"]
      ])
      Application.put_env(:hive, Hive.Dashboard.Endpoint, config)
    end

    # Stop and start Dashboard.Endpoint to pick up the config
    Hive.Test.StoreHelper.safe_stop(Hive.Dashboard.Endpoint)
    {:ok, _} = Hive.Dashboard.Endpoint.start_link([])

    :ok
  end

  describe "endpoint" do
    test "starts successfully" do
      assert Process.whereis(Hive.Dashboard.Endpoint) != nil
    end

    test "serves the overview page at /" do
      conn = request(:get, "/")

      assert conn.status == 200
      assert String.contains?(conn.resp_body, "Hive Dashboard")
      assert String.contains?(conn.resp_body, "Dashboard Overview")
    end

    test "serves the quests page at /quests" do
      conn = request(:get, "/quests")

      assert conn.status == 200
      assert String.contains?(conn.resp_body, "Quests")
    end

    test "serves the bees page at /bees" do
      conn = request(:get, "/bees")

      assert conn.status == 200
      assert String.contains?(conn.resp_body, "Bee Agents")
    end

    test "serves the costs page at /costs" do
      conn = request(:get, "/costs")

      assert conn.status == 200
      assert String.contains?(conn.resp_body, "Cost Tracking")
    end

    test "serves the waggles page at /waggles" do
      conn = request(:get, "/waggles")

      assert conn.status == 200
      assert String.contains?(conn.resp_body, "Waggle Messages")
    end

    test "includes CDN script tags for LiveView JS" do
      conn = request(:get, "/")

      assert String.contains?(conn.resp_body, "phoenix.min.js")
      assert String.contains?(conn.resp_body, "phoenix_live_view.min.js")
      assert String.contains?(conn.resp_body, "LiveSocket")
    end

    test "includes CSRF meta tag" do
      conn = request(:get, "/")

      assert String.contains?(conn.resp_body, "csrf-token")
    end

    test "includes inline CSS (no external stylesheet)" do
      conn = request(:get, "/")

      assert String.contains?(conn.resp_body, "<style>")
      assert String.contains?(conn.resp_body, "#0d1117")
    end
  end

  describe "router" do
    test "defines expected route paths" do
      routes = Phoenix.Router.routes(Hive.Dashboard.Router)
      paths = Enum.map(routes, & &1.path)

      assert "/" in paths
      assert "/quests" in paths
      assert "/bees" in paths
      assert "/costs" in paths
      assert "/waggles" in paths
    end

    test "all routes are LiveView routes" do
      routes = Phoenix.Router.routes(Hive.Dashboard.Router)

      for route <- routes do
        assert route.plug == Phoenix.LiveView.Plug,
               "expected #{route.path} to use LiveView.Plug, got #{inspect(route.plug)}"
      end
    end
  end

  # -- Helpers ----------------------------------------------------------------

  defp request(method, path) do
    method
    |> Plug.Test.conn(path)
    |> Hive.Dashboard.Endpoint.call(Hive.Dashboard.Endpoint.init([]))
  end
end
