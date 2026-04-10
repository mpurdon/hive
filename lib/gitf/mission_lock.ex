defmodule GiTF.MissionLock do
  @moduledoc """
  Per-key lock primitive built on `GiTF.Registry`.

  Used to serialize concurrent operations on the same mission or op,
  preventing duplicate phase advances, duplicate dependent unblocks,
  and other idempotency races.

  ## Contention Modes

    * `:error` — return `{:error, :locked}` if already held. Use when the
      caller can retry later or bail out cleanly.
    * `:skip`  — return `:ok` without running the function. Use when
      another caller is already doing the work and duplicate execution
      would be harmful (e.g., unblocking dependents twice).
    * `{:wait, timeout}` — poll the lock with 50ms retries until it's
      free or `timeout` ms elapse. Use when the operation must run
      exactly once, not "first one wins".

  ## Example

      GiTF.MissionLock.with_lock({:advance, mission_id}, on_contention: :error, fn ->
        do_advance(mission_id)
      end)
  """

  @registry GiTF.Registry
  @poll_interval 50

  @type key :: term()
  @type contention :: :error | :skip | {:wait, pos_integer()}

  @doc """
  Acquires the lock for `key`, runs `fun`, and releases the lock.
  """
  @spec with_lock(key(), keyword(), (-> result)) ::
          result | :ok | {:error, :locked | :timeout}
        when result: term()
  def with_lock(key, opts \\ [], fun) when is_function(fun, 0) do
    on_contention = Keyword.get(opts, :on_contention, :error)

    case Registry.register(@registry, {:lock, key}, :held) do
      {:ok, _} ->
        try do
          fun.()
        after
          Registry.unregister(@registry, {:lock, key})
        end

      {:error, {:already_registered, _}} ->
        handle_contention(key, on_contention, fun)
    end
  end

  # -- Private -----------------------------------------------------------------

  defp handle_contention(_key, :error, _fun), do: {:error, :locked}
  defp handle_contention(_key, :skip, _fun), do: :ok

  defp handle_contention(key, {:wait, timeout}, fun) do
    wait_and_retry(key, timeout, fun)
  end

  defp wait_and_retry(_key, remaining, _fun) when remaining <= 0 do
    {:error, :timeout}
  end

  defp wait_and_retry(key, remaining, fun) do
    Process.sleep(@poll_interval)

    case Registry.register(@registry, {:lock, key}, :held) do
      {:ok, _} ->
        try do
          fun.()
        after
          Registry.unregister(@registry, {:lock, key})
        end

      {:error, {:already_registered, _}} ->
        wait_and_retry(key, remaining - @poll_interval, fun)
    end
  end
end
