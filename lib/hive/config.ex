defmodule Hive.Config do
  @moduledoc """
  Reads, writes, and provides defaults for the `.hive/config.toml` configuration file.

  The config is a small TOML file that lives inside the `.hive/` directory and
  controls hive-wide settings such as maximum concurrent bees and cost thresholds.
  """

  @default_config %{
    "hive" => %{"version" => Hive.version()},
    "queen" => %{"max_bees" => 5},
    "costs" => %{"warn_threshold_usd" => 5.0, "budget_usd" => 10.0},
    "github" => %{"token" => ""}
  }

  @doc """
  Returns the default configuration map.

  ## Examples

      iex> config = Hive.Config.default_config()
      iex> config["queen"]["max_bees"]
      5
  """
  @spec default_config() :: map()
  def default_config, do: @default_config

  @doc """
  Writes a configuration map to the given file path as TOML.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec write_config(String.t(), map()) :: :ok | {:error, term()}
  def write_config(path, config \\ @default_config) do
    content = encode_toml(config)
    File.write(path, content)
  end

  @doc """
  Reads and parses a TOML configuration file.

  Returns `{:ok, map}` on success or `{:error, reason}` on failure.
  """
  @spec read_config(String.t()) :: {:ok, map()} | {:error, term()}
  def read_config(path) do
    with {:ok, content} <- File.read(path),
         {:ok, parsed} <- Toml.decode(content) do
      {:ok, parsed}
    end
  end

  # -- Private: TOML encoding ------------------------------------------------

  # We encode a simple two-level map to TOML by hand rather than pulling in a
  # TOML encoder dependency. The config structure is intentionally shallow.

  defp encode_toml(config) do
    config
    |> Enum.sort_by(fn {section, _} -> section end)
    |> Enum.map_join("\n", &encode_section/1)
  end

  defp encode_section({section, values}) when is_map(values) do
    header = "[#{section}]"

    body =
      values
      |> Enum.sort_by(fn {key, _} -> key end)
      |> Enum.map_join("\n", fn {key, value} ->
        "#{key} = #{encode_value(value)}"
      end)

    "#{header}\n#{body}\n"
  end

  defp encode_value(value) when is_binary(value), do: ~s("#{value}")
  defp encode_value(value) when is_integer(value), do: Integer.to_string(value)
  defp encode_value(value) when is_float(value), do: Float.to_string(value)
  defp encode_value(value) when is_boolean(value), do: Atom.to_string(value)
end
