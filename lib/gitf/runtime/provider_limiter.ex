defmodule GiTF.Runtime.ProviderLimiter do
  @moduledoc """
  Per-provider rate limiting using token buckets.

  Lazily starts a `GiTF.RateLimiter` instance per LLM provider to smooth
  burst load and prevent 429s that would open circuit breakers. Each limiter
  is registered via `GiTF.Registry` for lookup and supervised under a
  DynamicSupervisor.
  """

  require Logger

  @registry GiTF.Registry
  @supervisor __MODULE__.Supervisor
  @default_max_tokens 10
  @default_refill_rate 10
  @default_refill_interval 1_000

  @doc """
  Acquire a token for the given provider. Returns `:ok` immediately if
  tokens are available, or `{:ok, delay_ms}` if the caller should wait.

  Lazily starts the provider's limiter if it doesn't exist.
  """
  @spec acquire(String.t()) :: :ok | {:ok, non_neg_integer()}
  def acquire(provider) do
    pid = ensure_limiter(provider)
    GiTF.RateLimiter.acquire(pid)
  rescue
    e ->
      Logger.debug("Provider limiter acquire failed for #{provider}: #{Exception.message(e)}")
      :ok
  end

  @doc """
  Looks up or starts a rate limiter for the given provider.
  Returns the limiter PID.
  """
  @spec ensure_limiter(String.t()) :: pid()
  def ensure_limiter(provider) do
    key = {:provider_limiter, provider}

    case Registry.lookup(@registry, key) do
      [{pid, _}] ->
        pid

      [] ->
        start_limiter(provider, key)
    end
  end

  defp start_limiter(provider, key) do
    name = {:via, Registry, {@registry, key}}

    opts = [
      name: name,
      max_tokens: provider_config(:max_tokens, provider),
      refill_rate: provider_config(:refill_rate, provider),
      refill_interval: provider_config(:refill_interval, provider)
    ]

    case DynamicSupervisor.start_child(@supervisor, {GiTF.RateLimiter, opts}) do
      {:ok, pid} ->
        Logger.debug("Started rate limiter for provider #{provider}")
        pid

      {:error, {:already_started, pid}} ->
        pid

      {:error, reason} ->
        Logger.warning("Failed to start limiter for #{provider}: #{inspect(reason)}")
        raise "limiter start failed"
    end
  end

  defp provider_config(:max_tokens, _provider) do
    GiTF.Config.Provider.get([:llm, :provider_rate_limit], @default_max_tokens)
  end

  defp provider_config(:refill_rate, _provider) do
    GiTF.Config.Provider.get([:llm, :provider_rate_limit], @default_refill_rate)
  end

  defp provider_config(:refill_interval, _provider), do: @default_refill_interval
end
