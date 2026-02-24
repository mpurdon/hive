defmodule AgentLoopCacheTest do
  use ExUnit.Case
  import Mox

  alias Hive.Runtime.AgentLoop
  alias Hive.Runtime.LLMClient

  # Mock the LLM Client
  setup :verify_on_exit!

  test "passes cache control for anthropic model" do
    large_prompt = String.duplicate("a", 5000)
    
    # We expect generate_text to receive messages with cache_control
    Hive.Runtime.LLMClient.Mock
    |> expect(:generate_text, fn _model, messages, _opts ->
      # Verify system message has cache_control
      system_msg = Enum.find(messages, fn m -> m.role == :system end)
      assert Map.has_key?(system_msg, :cache_control)
      assert system_msg.cache_control == %{"type" => "ephemeral"}
      
      {:ok, %{text: "ok", usage: %{}}}
    end)

    # Configure Hive to use the mock client
    Application.put_env(:hive, :llm_client, Hive.Runtime.LLMClient.Mock)

    AgentLoop.run("test", ".", 
      model: "anthropic:claude-sonnet-4-6", 
      system_prompt: large_prompt,
      max_iterations: 1
    )
  end

  test "skips cache control for google model" do
    large_prompt = String.duplicate("a", 5000)
    
    Hive.Runtime.LLMClient.Mock
    |> expect(:generate_text, fn _model, messages, _opts ->
      system_msg = Enum.find(messages, fn m -> m.role == :system end)
      refute Map.has_key?(system_msg, :cache_control)
      
      {:ok, %{text: "ok", usage: %{}}}
    end)

    AgentLoop.run("test", ".", 
      model: "google:gemini-2.0-flash", 
      system_prompt: large_prompt,
      max_iterations: 1
    )
  end
end
