defmodule Hive.Runtime.ModelsTest do
  use ExUnit.Case, async: true

  alias Hive.Runtime.Models

  describe "resolve_plugin/1" do
    test "defaults to Claude plugin when no opts" do
      assert {:ok, Hive.Plugin.Builtin.Models.Claude} = Models.resolve_plugin()
    end

    test "accepts explicit module in :model_plugin opt" do
      assert {:ok, Hive.Plugin.Builtin.Models.Claude} =
               Models.resolve_plugin(model_plugin: Hive.Plugin.Builtin.Models.Claude)
    end

    test "accepts string name in :model_plugin opt" do
      # Falls back to default plugin when registry isn't running
      assert {:ok, Hive.Plugin.Builtin.Models.Claude} =
               Models.resolve_plugin(model_plugin: "claude")
    end
  end

  describe "default_name/0" do
    test "returns 'claude' as default" do
      assert Models.default_name() == "claude"
    end
  end

  describe "parse_output/2" do
    test "delegates to the plugin's parse_output" do
      data = ~s({"type":"system","model":"claude-sonnet-4-20250514"}\n)
      events = Models.parse_output(data)
      assert [%{"type" => "system", "model" => "claude-sonnet-4-20250514"}] = events
    end

    test "handles empty data" do
      assert [] = Models.parse_output("")
    end
  end

  describe "extract_costs/2" do
    test "extracts cost data from result events" do
      events = [
        %{"type" => "assistant", "content" => "hello"},
        %{
          "type" => "result",
          "usage" => %{
            "input_tokens" => 100,
            "output_tokens" => 50,
            "cache_read_tokens" => 10,
            "cache_write_tokens" => 5
          },
          "model" => "claude-sonnet-4-20250514",
          "cost_usd" => 0.001
        }
      ]

      costs = Models.extract_costs(events)
      assert length(costs) == 1
      assert [%{input_tokens: 100, output_tokens: 50}] = costs
    end

    test "returns empty list when no result events" do
      events = [%{"type" => "assistant", "content" => "hello"}]
      assert [] = Models.extract_costs(events)
    end
  end

  describe "extract_session_id/2" do
    test "extracts session ID from system events" do
      events = [%{"type" => "system", "session_id" => "sess-abc123"}]
      assert "sess-abc123" = Models.extract_session_id(events)
    end

    test "returns nil when no session ID present" do
      events = [%{"type" => "assistant", "content" => "hello"}]
      assert nil == Models.extract_session_id(events)
    end

    test "returns nil for empty events" do
      assert nil == Models.extract_session_id([])
    end
  end

  describe "progress_from_events/2" do
    test "extracts tool_use progress" do
      events = [%{"type" => "tool_use", "name" => "Read", "input" => %{"file_path" => "/tmp/x"}}]
      progress = Models.progress_from_events(events)
      assert [%{tool: "Read", file: "/tmp/x", message: "Using Read"}] = progress
    end

    test "extracts assistant content progress" do
      events = [%{"type" => "assistant", "content" => "Working on it..."}]
      progress = Models.progress_from_events(events)
      assert [%{tool: nil, file: nil, message: "Working on it..."}] = progress
    end

    test "returns empty list for unrecognized events" do
      events = [%{"type" => "system", "model" => "claude-sonnet-4-20250514"}]
      assert [] = Models.progress_from_events(events)
    end
  end

  describe "find_executable/1" do
    test "delegates to the plugin's find_executable" do
      # Claude is likely installed on dev machines; just verify it returns the right shape
      result = Models.find_executable()
      assert match?({:ok, _}, result) or match?({:error, :not_found}, result)
    end
  end

  describe "pricing/1" do
    test "returns Claude pricing table by default" do
      pricing = Models.pricing()
      assert is_map(pricing)
      assert Map.has_key?(pricing, "claude-sonnet-4-20250514")
      assert Map.has_key?(pricing, "claude-opus-4-20250514")

      sonnet = pricing["claude-sonnet-4-20250514"]
      assert sonnet.input == 3.0
      assert sonnet.output == 15.0
    end
  end

  describe "workspace_setup/3" do
    test "returns settings map for a bee" do
      settings = Models.workspace_setup("bee-test123", "/tmp/test-hive")
      assert is_map(settings)
      assert Map.has_key?(settings, "hooks")
      assert Map.has_key?(settings, "permissions")
    end

    test "returns settings map for the queen" do
      settings = Models.workspace_setup("queen", "/tmp/test-hive")
      assert is_map(settings)
      assert Map.has_key?(settings, "hooks")
    end
  end

  describe "provider_config/1" do
    test "returns empty map for unconfigured provider" do
      assert Models.provider_config("nonexistent") == %{}
    end
  end
end
