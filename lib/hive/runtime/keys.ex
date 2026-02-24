defmodule Hive.Runtime.Keys do
  @moduledoc """
  Loads API keys from `.hive/config.toml` `[llm.keys]` section into
  environment variables as a fallback. Called from `Hive.Application.start/2`.

  Keys are only set if not already present in the environment, so explicit
  env vars always win.

  ## Example config.toml

      [llm.keys]
      anthropic = "sk-ant-..."
      openai = "sk-..."
      google = "AIza..."
  """

  require Logger

  @key_env_map %{
    anthropic: "ANTHROPIC_API_KEY",
    openai: "OPENAI_API_KEY",
    google: "GOOGLE_API_KEY",
    groq: "GROQ_API_KEY",
    mistral: "MISTRAL_API_KEY",
    cohere: "COHERE_API_KEY",
    together: "TOGETHER_API_KEY",
    fireworks: "FIREWORKS_API_KEY"
  }

  @doc """
  Loads API keys from the hive config into environment variables.

  Only sets keys that are not already present in the environment.
  Returns the number of keys loaded.
  """
  @spec load() :: non_neg_integer()
  def load do
    keys = read_keys_from_config()

    loaded =
      Enum.count(keys, fn {provider, value} ->
        env_var = Map.get(@key_env_map, provider, env_var_for(provider))

        if System.get_env(env_var) == nil and is_binary(value) and value != "" do
          System.put_env(env_var, value)
          true
        else
          false
        end
      end)

    if loaded > 0 do
      Logger.info("Loaded #{loaded} API key(s) from hive config")
    end

    loaded
  rescue
    e ->
      Logger.debug("Failed to load API keys from config: #{inspect(e)}")
      0
  end

  @doc """
  Returns a diagnostic status of which API keys are available.
  """
  @spec status() :: [{atom(), boolean()}]
  def status do
    Enum.map(@key_env_map, fn {provider, env_var} ->
      {provider, System.get_env(env_var) != nil}
    end)
  end

  # -- Private -----------------------------------------------------------------

  defp read_keys_from_config do
    case Hive.Config.Provider.get([:llm, :keys]) do
      nil -> %{}
      keys when is_map(keys) -> keys
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  defp env_var_for(provider) do
    provider
    |> to_string()
    |> String.upcase()
    |> Kernel.<>("_API_KEY")
  end
end
