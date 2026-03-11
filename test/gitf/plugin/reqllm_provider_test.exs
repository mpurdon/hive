defmodule GiTF.Plugin.Builtin.Models.ReqLLMProviderTest do
  use ExUnit.Case, async: true

  alias GiTF.Plugin.Builtin.Models.ReqLLMProvider

  describe "name/0" do
    test "returns reqllm" do
      assert ReqLLMProvider.name() == "reqllm"
    end
  end

  describe "description/0" do
    test "returns a description string" do
      desc = ReqLLMProvider.description()
      assert is_binary(desc)
      assert desc =~ "ReqLLM"
    end
  end

  describe "execution_mode/0" do
    test "returns :api" do
      assert ReqLLMProvider.execution_mode() == :api
    end
  end

  describe "capabilities/0" do
    test "includes expected capabilities" do
      caps = ReqLLMProvider.capabilities()
      assert :tool_calling in caps
      assert :streaming in caps
      assert :api_mode in caps
      assert :multi_provider in caps
    end
  end

  describe "pricing/0" do
    test "returns pricing for known models" do
      pricing = ReqLLMProvider.pricing()
      assert is_map(pricing)

      # Anthropic models
      assert Map.has_key?(pricing, "anthropic:claude-opus-4-6")
      assert Map.has_key?(pricing, "anthropic:claude-sonnet-4-6")
      assert Map.has_key?(pricing, "anthropic:claude-haiku-4-5")

      # Google models
      assert Map.has_key?(pricing, "google:gemini-2.5-pro")
      assert Map.has_key?(pricing, "google:gemini-2.0-flash")

      # Each entry has required keys
      for {_model, prices} <- pricing do
        assert is_float(prices.input) or is_integer(prices.input)
        assert is_float(prices.output) or is_integer(prices.output)
        assert Map.has_key?(prices, :cache_read)
        assert Map.has_key?(prices, :cache_write)
      end
    end
  end

  describe "list_available_models/0" do
    test "returns a list of model specs" do
      models = ReqLLMProvider.list_available_models()
      assert is_list(models)
      assert length(models) > 0

      # All should be provider-qualified
      Enum.each(models, fn model ->
        assert String.contains?(model, ":")
      end)
    end
  end

  describe "get_model_info/1" do
    test "returns info for a known model" do
      assert {:ok, info} = ReqLLMProvider.get_model_info("anthropic:claude-sonnet-4-6")
      assert info.provider == "anthropic"
      assert info.context_limit > 0
      assert is_list(info.capabilities)
    end

    test "returns info for tier names" do
      assert {:ok, info} = ReqLLMProvider.get_model_info("sonnet")
      assert info.provider == "google"
    end
  end

  describe "get_context_limit/1" do
    test "returns a positive integer" do
      assert {:ok, limit} = ReqLLMProvider.get_context_limit("any-model")
      assert is_integer(limit)
      assert limit > 0
    end
  end

  describe "extract_costs/1" do
    test "extracts cost data from result events" do
      events = [
        %{"type" => "tool_use", "name" => "read_file"},
        %{
          "type" => "result",
          "usage" => %{input_tokens: 100, output_tokens: 50},
          "model" => "anthropic:claude-sonnet-4-6",
          "cost_usd" => 0.001
        }
      ]

      costs = ReqLLMProvider.extract_costs(events)
      assert length(costs) == 1

      [cost] = costs
      assert cost.input_tokens == 100
      assert cost.output_tokens == 50
      assert cost.cost_usd == 0.001
    end

    test "returns empty list for events with no results" do
      events = [%{"type" => "tool_use"}]
      assert ReqLLMProvider.extract_costs(events) == []
    end
  end

  describe "extract_session_id/1" do
    test "extracts session id from system event" do
      events = [%{"type" => "system", "session_id" => "abc123"}]
      assert ReqLLMProvider.extract_session_id(events) == "abc123"
    end

    test "extracts session id from result event" do
      events = [%{"type" => "result", "session_id" => "xyz789"}]
      assert ReqLLMProvider.extract_session_id(events) == "xyz789"
    end

    test "returns nil when no session id" do
      assert ReqLLMProvider.extract_session_id([]) == nil
    end
  end

  describe "progress_from_events/1" do
    test "extracts tool use progress" do
      events = [
        %{"type" => "tool_use", "name" => "read_file", "input" => %{"path" => "lib/app.ex"}},
        %{"type" => "tool_use", "name" => "write_file", "input" => %{"path" => "lib/new.ex"}}
      ]

      progress = ReqLLMProvider.progress_from_events(events)
      assert length(progress) == 2
      assert hd(progress).tool == "read_file"
      assert hd(progress).file == "lib/app.ex"
    end
  end

  describe "spawn_interactive/2" do
    test "returns not_supported_in_api_mode" do
      assert {:error, :not_supported_in_api_mode} = ReqLLMProvider.spawn_interactive("/tmp")
    end
  end

  describe "spawn_headless/3" do
    test "returns not_supported_in_api_mode" do
      assert {:error, :not_supported_in_api_mode} = ReqLLMProvider.spawn_headless("test", "/tmp")
    end
  end

  describe "parse_output/1" do
    test "returns empty list" do
      assert ReqLLMProvider.parse_output("some data") == []
    end
  end
end
