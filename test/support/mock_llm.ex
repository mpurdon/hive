defmodule Hive.Test.MockLLM do
  @moduledoc """
  Test helper for building mock LLM responses without API calls.

  Provides helpers that construct `ReqLLM.Response`-compatible maps for
  use in tests. Pair with `Hive.Runtime.LLMClient.Mock` (via Mox) for
  full control over agent loop behavior.

  ## Usage

      # In test_helper.exs:
      Mox.defmock(Hive.Runtime.LLMClient.Mock, for: Hive.Runtime.LLMClient)
      Application.put_env(:hive, :llm_client, Hive.Runtime.LLMClient.Mock)

      # In tests:
      import Hive.Test.MockLLM

      Mox.expect(Hive.Runtime.LLMClient.Mock, :generate_text, fn _model, _msgs, _opts ->
        {:ok, final_answer("Hello from mock!")}
      end)
  """

  @doc """
  Builds a mock response representing a final text answer (no tool calls).
  """
  def final_answer(text) do
    %{
      __struct__: ReqLLM.Response,
      id: "mock-#{:rand.uniform(100_000)}",
      model: "mock:test-model",
      message: %{
        role: :assistant,
        content: [%{type: :text, text: text}]
      },
      context: ReqLLM.Context.new([]),
      usage: %{input_tokens: 10, output_tokens: 20, total_cost: 0.001},
      finish_reason: :stop,
      stream?: false,
      stream: nil,
      error: nil,
      object: nil,
      provider_meta: %{}
    }
  end

  @doc """
  Builds a mock response containing a single tool call.
  """
  def tool_call(name, args, opts \\ []) do
    id = Keyword.get(opts, :id, "tc_#{:rand.uniform(100_000)}")

    %{
      __struct__: ReqLLM.Response,
      id: "mock-#{:rand.uniform(100_000)}",
      model: "mock:test-model",
      message: %{
        role: :assistant,
        content: [
          %{type: :tool_call, id: id, name: name, arguments: args}
        ]
      },
      context: ReqLLM.Context.new([]),
      usage: %{input_tokens: 15, output_tokens: 30, total_cost: 0.002},
      finish_reason: :tool_calls,
      stream?: false,
      stream: nil,
      error: nil,
      object: nil,
      provider_meta: %{}
    }
  end

  @doc """
  Builds a sequence of mock responses for a multi-turn conversation.

  Takes a list of response builders (atoms or tuples):

      multi_turn([
        {:tool_call, "read_file", %{"path" => "test.txt"}},
        {:final_answer, "The file says hello"}
      ])

  Returns a function suitable for `Mox.expect` that returns responses in order.
  """
  def multi_turn(turns) when is_list(turns) do
    responses =
      Enum.map(turns, fn
        {:final_answer, text} -> final_answer(text)
        {:tool_call, name, args} -> tool_call(name, args)
        {:tool_call, name, args, opts} -> tool_call(name, args, opts)
      end)

    # Return a stateful function via Agent
    {:ok, agent} = Agent.start_link(fn -> responses end)

    fn _model, _messages, _opts ->
      response =
        Agent.get_and_update(agent, fn
          [head | tail] -> {head, tail}
          [] -> {final_answer("(exhausted mock turns)"), []}
        end)

      {:ok, response}
    end
  end
end
