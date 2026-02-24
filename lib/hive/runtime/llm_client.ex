defmodule Hive.Runtime.LLMClient do
  @moduledoc """
  Mockable wrapper around ReqLLM for testability.

  All LLM API calls go through this module so tests can swap in
  `Hive.Runtime.LLMClient.Mock` via config:

      config :hive, :llm_client, Hive.Runtime.LLMClient.Mock

  The default implementation delegates to `ReqLLM.generate_text/3`
  and `ReqLLM.stream_text/3`.
  """

  @type model :: String.t()
  @type messages :: String.t() | ReqLLM.Context.t() | [map()]
  @type opts :: keyword()

  @callback generate_text(model(), messages(), opts()) ::
              {:ok, struct()} | {:error, term()}
  @callback stream_text(model(), messages(), opts()) ::
              {:ok, struct()} | {:error, term()}

  @doc "Returns the configured LLM client module."
  @spec impl() :: module()
  def impl do
    Application.get_env(:hive, :llm_client, __MODULE__.Default)
  end

  @doc "Generates text via the configured LLM client."
  @spec generate_text(model(), messages(), opts()) :: {:ok, struct()} | {:error, term()}
  def generate_text(model, messages, opts \\ []) do
    impl().generate_text(model, messages, opts)
  end

  @doc "Streams text via the configured LLM client."
  @spec stream_text(model(), messages(), opts()) :: {:ok, struct()} | {:error, term()}
  def stream_text(model, messages, opts \\ []) do
    impl().stream_text(model, messages, opts)
  end
end

defmodule Hive.Runtime.LLMClient.Default do
  @moduledoc false
  @behaviour Hive.Runtime.LLMClient

  @impl true
  def generate_text(model, messages, opts) do
    case Keyword.pop(opts, :gemini_cache) do
      {nil, _} ->
        ReqLLM.generate_text(model, messages, opts)
        
      {cache_name, clean_opts} ->
        run_gemini_cached(model, messages, cache_name, clean_opts)
    end
  end

  defp run_gemini_cached(model, messages, cache_name, opts) do
    # Minimal implementation for Gemini Context Caching
    # Assumes messages contains only the user prompt (system prompt is cached)
    
    # Map model name
    api_model = map_model_name(model)
    key = get_api_key()
    url = "https://generativelanguage.googleapis.com/v1beta/#{api_model}:generateContent?key=#{key}"
    
    # Extract user content
    # messages is a ReqLLM.Context struct or list
    user_content = extract_user_content(messages)
    
    body = %{
      "cachedContent" => cache_name,
      "contents" => [
        %{"role" => "user", "parts" => [%{"text" => user_content}]}
      ],
      "generationConfig" => %{
        "temperature" => opts[:temperature],
        "maxOutputTokens" => opts[:max_tokens]
      }
    }
    
    # TODO: Add tool support (requires formatting tools to Gemini JSON schema)
    # For now, this enables caching for research/planning phases which are text-heavy.
    
    case Req.post(url, json: body) do
      {:ok, %{status: 200, body: resp}} ->
        # Convert Gemini response to ReqLLM.Response struct
        {:ok, parse_gemini_response(resp, model)}
        
      {:ok, %{status: status, body: body}} ->
        {:error, "Gemini API #{status}: #{inspect(body)}"}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def stream_text(model, messages, opts) do
    ReqLLM.stream_text(model, messages, opts)
  end
  
  defp map_model_name(model) do
     clean = String.replace(model, "google:", "")
     if String.starts_with?(clean, "models/"), do: clean, else: "models/#{clean}"
  end
  
  defp get_api_key do
    System.get_env("GOOGLE_API_KEY") || Application.get_env(:req_llm, :google_api_key)
  end
  
  defp extract_user_content(ctx) do
    # Naive extraction from ReqLLM.Context
    # Assumes the last message is user
    if is_struct(ctx) do
      List.last(ctx.messages).content
    else
      # List of maps
      List.last(ctx).content
    end
  rescue
    _ -> ""
  end
  
  defp parse_gemini_response(resp, model) do
    # Minimal parsing
    candidate = List.first(resp["candidates"] || [])
    content = candidate["content"]["parts"] |> List.first() |> Map.get("text", "")
    usage = resp["usageMetadata"] || %{}
    
    %ReqLLM.Response{
       model: model,
       role: :assistant,
       content: content,
       usage: %{
         input_tokens: usage["promptTokenCount"],
         output_tokens: usage["candidatesTokenCount"],
         total_tokens: usage["totalTokenCount"]
       }
    }
  end
end
