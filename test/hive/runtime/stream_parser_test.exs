defmodule Hive.Runtime.StreamParserTest do
  use ExUnit.Case, async: true

  alias Hive.Runtime.StreamParser

  describe "parse_chunk/1" do
    test "parses a single JSON line" do
      data = ~s({"type":"system","model":"claude-sonnet-4-20250514"}\n)
      assert [%{"type" => "system", "model" => "claude-sonnet-4-20250514"}] = StreamParser.parse_chunk(data)
    end

    test "parses multiple JSON lines" do
      data = """
      {"type":"system","model":"claude-sonnet-4-20250514"}
      {"type":"assistant","message":{"content":"hello"}}
      {"type":"result","result":"done","usage":{"input_tokens":100,"output_tokens":50}}
      """

      events = StreamParser.parse_chunk(data)
      assert length(events) == 3
      assert Enum.at(events, 0)["type"] == "system"
      assert Enum.at(events, 1)["type"] == "assistant"
      assert Enum.at(events, 2)["type"] == "result"
    end

    test "silently drops malformed lines" do
      data = """
      {"type":"system"}
      not valid json
      {"type":"result","usage":{"input_tokens":10,"output_tokens":5}}
      """

      events = StreamParser.parse_chunk(data)
      assert length(events) == 2
    end

    test "returns empty list for empty input" do
      assert [] = StreamParser.parse_chunk("")
    end

    test "handles data without trailing newline" do
      data = ~s({"type":"system"})
      assert [%{"type" => "system"}] = StreamParser.parse_chunk(data)
    end
  end

  describe "extract_cost/1" do
    test "extracts cost data from a result event" do
      event = %{
        "type" => "result",
        "usage" => %{
          "input_tokens" => 1000,
          "output_tokens" => 500,
          "cache_read_tokens" => 200,
          "cache_write_tokens" => 100
        },
        "model" => "claude-sonnet-4-20250514",
        "cost_usd" => 0.0123
      }

      cost = StreamParser.extract_cost(event)

      assert cost.input_tokens == 1000
      assert cost.output_tokens == 500
      assert cost.cache_read_tokens == 200
      assert cost.cache_write_tokens == 100
      assert cost.model == "claude-sonnet-4-20250514"
      assert cost.cost_usd == 0.0123
    end

    test "defaults missing token counts to zero" do
      event = %{
        "type" => "result",
        "usage" => %{
          "input_tokens" => 50,
          "output_tokens" => 25
        },
        "model" => "claude-sonnet-4-20250514"
      }

      cost = StreamParser.extract_cost(event)

      assert cost.input_tokens == 50
      assert cost.output_tokens == 25
      assert cost.cache_read_tokens == 0
      assert cost.cache_write_tokens == 0
      assert cost.cost_usd == nil
    end

    test "returns nil for non-result events" do
      assert nil == StreamParser.extract_cost(%{"type" => "system"})
      assert nil == StreamParser.extract_cost(%{"type" => "assistant"})
      assert nil == StreamParser.extract_cost(%{})
    end
  end

  describe "extract_costs/1" do
    test "extracts costs from a list of events" do
      events = [
        %{"type" => "system", "model" => "claude-sonnet-4-20250514"},
        %{"type" => "assistant", "message" => %{"content" => "hello"}},
        %{
          "type" => "result",
          "usage" => %{"input_tokens" => 100, "output_tokens" => 50},
          "model" => "claude-sonnet-4-20250514",
          "cost_usd" => 0.001
        }
      ]

      costs = StreamParser.extract_costs(events)
      assert length(costs) == 1
      assert hd(costs).input_tokens == 100
    end

    test "returns empty list when no result events" do
      events = [
        %{"type" => "system"},
        %{"type" => "assistant"}
      ]

      assert [] = StreamParser.extract_costs(events)
    end
  end

  describe "session_complete?/1" do
    test "returns true for result events" do
      assert StreamParser.session_complete?(%{"type" => "result"})
    end

    test "returns false for other event types" do
      refute StreamParser.session_complete?(%{"type" => "system"})
      refute StreamParser.session_complete?(%{"type" => "assistant"})
      refute StreamParser.session_complete?(%{})
    end
  end

  describe "extract_session_id/1" do
    test "extracts session_id from a system event" do
      events = [
        %{"type" => "system", "session_id" => "sess-abc123", "model" => "claude-sonnet-4-20250514"},
        %{"type" => "assistant", "message" => %{"content" => "hello"}},
        %{"type" => "result", "usage" => %{"input_tokens" => 10, "output_tokens" => 5}}
      ]

      assert "sess-abc123" = StreamParser.extract_session_id(events)
    end

    test "returns nil when no system event is present" do
      events = [
        %{"type" => "assistant", "message" => %{"content" => "hello"}},
        %{"type" => "result", "usage" => %{"input_tokens" => 10, "output_tokens" => 5}}
      ]

      assert nil == StreamParser.extract_session_id(events)
    end

    test "returns nil when system event has no session_id" do
      events = [
        %{"type" => "system", "model" => "claude-sonnet-4-20250514"}
      ]

      assert nil == StreamParser.extract_session_id(events)
    end

    test "returns nil for empty event list" do
      assert nil == StreamParser.extract_session_id([])
    end
  end
end
