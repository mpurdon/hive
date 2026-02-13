defmodule Hive.Changeset do
  @moduledoc """
  Lightweight changeset module for validating data at system boundaries.

  Inspired by Ecto.Changeset but with no Ecto dependency. Used for plugin
  configs, TOML config, user input, and Store entity creation/updates.
  """

  defstruct [:data, :changes, :errors, :valid?]

  @type t :: %__MODULE__{
          data: map(),
          changes: map(),
          errors: [{atom(), String.t()}],
          valid?: boolean()
        }

  @doc "Creates a changeset by casting params through permitted keys."
  @spec cast(map(), map(), [atom()]) :: t()
  def cast(data, params, permitted_keys) do
    changes =
      params
      |> Enum.filter(fn {k, _v} -> k in permitted_keys end)
      |> Map.new()

    %__MODULE__{data: data, changes: changes, errors: [], valid?: true}
  end

  @doc "Validates that the given keys are present in changes."
  @spec validate_required(t(), [atom()]) :: t()
  def validate_required(%__MODULE__{} = changeset, keys) do
    Enum.reduce(keys, changeset, fn key, cs ->
      value = Map.get(cs.changes, key) || Map.get(cs.data, key)

      if is_nil(value) or value == "" do
        add_error(cs, key, "is required")
      else
        cs
      end
    end)
  end

  @doc "Validates a field matches the given regex."
  @spec validate_format(t(), atom(), Regex.t()) :: t()
  def validate_format(%__MODULE__{} = changeset, key, regex) do
    value = Map.get(changeset.changes, key) || Map.get(changeset.data, key)

    cond do
      is_nil(value) ->
        changeset

      not is_binary(value) ->
        add_error(changeset, key, "must be a string")

      not Regex.match?(regex, value) ->
        add_error(changeset, key, "has invalid format")

      true ->
        changeset
    end
  end

  @doc "Validates a field's value is in the given list."
  @spec validate_inclusion(t(), atom(), [term()]) :: t()
  def validate_inclusion(%__MODULE__{} = changeset, key, values) do
    value = Map.get(changeset.changes, key) || Map.get(changeset.data, key)

    if is_nil(value) or value in values do
      changeset
    else
      add_error(changeset, key, "must be one of: #{Enum.join(values, ", ")}")
    end
  end

  @doc "Applies changes to data if valid, otherwise returns error."
  @spec apply_changes(t()) :: {:ok, map()} | {:error, [{atom(), String.t()}]}
  def apply_changes(%__MODULE__{valid?: true} = changeset) do
    {:ok, Map.merge(changeset.data, changeset.changes)}
  end

  def apply_changes(%__MODULE__{valid?: false} = changeset) do
    {:error, changeset.errors}
  end

  @doc "Adds an error for the given key."
  @spec add_error(t(), atom(), String.t()) :: t()
  def add_error(%__MODULE__{} = changeset, key, message) do
    %{changeset | errors: [{key, message} | changeset.errors], valid?: false}
  end
end
