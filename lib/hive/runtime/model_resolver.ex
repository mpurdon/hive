defmodule Hive.Runtime.ModelResolver do
  @moduledoc """
  Centralized model name resolution.

  Maps tier names ("opus", "sonnet", "haiku") to provider-specific model
  specs (e.g. "anthropic:claude-opus-4-6", "google:gemini-2.5-pro").

  The mapping is configured in `:hive, :llm, :default_models` and can
  be overridden at runtime. Provider-qualified names like
  "anthropic:claude-opus-4-6" pass through unchanged.

  ## Execution Mode

  Returns `:api` or `:cli` based on (in priority order):
  1. `HIVE_EXECUTION_MODE` env var
  2. Hive config `execution_mode`
  3. Application config `:hive, :llm, :execution_mode`
  4. Default: `:api`
  """

  @default_models %{
    "opus" => "google:gemini-2.5-pro",
    "sonnet" => "google:gemini-2.5-flash",
    "haiku" => "google:gemini-2.0-flash",
    "fast" => "google:gemini-2.0-flash",
    # Legacy Claude names (backwards compat for explicit requests)
    "claude-opus" => "anthropic:claude-opus-4-6",
    "claude-sonnet" => "anthropic:claude-sonnet-4-6",
    "claude-haiku" => "anthropic:claude-haiku-4-5",
    "claude-opus-4-6" => "anthropic:claude-opus-4-6",
    "claude-sonnet-4-6" => "anthropic:claude-sonnet-4-6",
    "claude-haiku-4-5" => "anthropic:claude-haiku-4-5"
  }

  # -- Public API --------------------------------------------------------------

  @doc """
  Resolves a model tier name or qualified name to a provider:model spec.

  - `"opus"` → configured opus model (e.g. `"anthropic:claude-opus-4-6"`)
  - `"sonnet"` → configured sonnet model
  - `"claude-sonnet"` → maps to provider-qualified name
  - `"anthropic:claude-opus-4-6"` → passthrough
  - `"google:gemini-2.0-flash"` → passthrough
  """
  @spec resolve(String.t()) :: String.t()
  def resolve(name) when is_binary(name) do
    # If already provider-qualified, pass through
    if String.contains?(name, ":") do
      name
    else
      models = configured_models()
      Map.get(models, name, name)
    end
  end

  @doc """
  Returns the current execution mode: `:api` or `:cli`.

  Checked in priority order:
  1. `HIVE_EXECUTION_MODE` env var ("api" or "cli")
  2. Hive config file `execution_mode`
  3. Application config `:hive, :llm, :execution_mode`
  4. Default: `:api`
  """
  @spec execution_mode() :: :api | :cli
  def execution_mode do
    case System.get_env("HIVE_EXECUTION_MODE") do
      "api" ->
        :api

      "cli" ->
        :cli

      _ ->
        hive_config_mode() || app_config_mode() || :api
    end
  end

  @doc """
  Returns true if the current execution mode is `:api`.
  """
  @spec api_mode?() :: boolean()
  def api_mode? do
    execution_mode() == :api
  end

  @doc """
  Returns the configured default models map.
  """
  @spec configured_models() :: map()
  def configured_models do
    case Application.get_env(:hive, :llm) do
      nil ->
        @default_models

      config ->
        custom = config[:default_models] || %{}
        # Merge custom over defaults, converting atom keys to strings
        custom_string_keys = Map.new(custom, fn {k, v} -> {to_string(k), v} end)
        Map.merge(@default_models, custom_string_keys)
    end
  end

  @doc """
  Returns the provider name from a model spec string.

  ## Examples

      iex> ModelResolver.provider("anthropic:claude-opus-4-6")
      "anthropic"

      iex> ModelResolver.provider("claude-sonnet")
      "anthropic"
  """
  @spec provider(String.t()) :: String.t()
  def provider(model_spec) do
    resolved = resolve(model_spec)

    case String.split(resolved, ":", parts: 2) do
      [provider, _model] -> provider
      _ -> "google"
    end
  end

  @doc """
  Returns the model ID (without provider prefix) from a model spec.

  ## Examples

      iex> ModelResolver.model_id("anthropic:claude-opus-4-6")
      "claude-opus-4-6"

      iex> ModelResolver.model_id("claude-sonnet")
      "claude-sonnet-4-6"
  """
  @spec model_id(String.t()) :: String.t()
  def model_id(model_spec) do
    resolved = resolve(model_spec)

    case String.split(resolved, ":", parts: 2) do
      [_provider, model] -> model
      _ -> resolved
    end
  end

  # -- Private -----------------------------------------------------------------

  defp hive_config_mode do
    mode =
      Hive.Config.Provider.get([:llm, :execution_mode]) ||
        Hive.Config.Provider.get([:execution_mode])

    case mode do
      "api" -> :api
      :api -> :api
      "cli" -> :cli
      :cli -> :cli
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp app_config_mode do
    case get_in(Application.get_env(:hive, :llm, []), [:execution_mode]) do
      :api -> :api
      :cli -> :cli
      _ -> nil
    end
  end
end
