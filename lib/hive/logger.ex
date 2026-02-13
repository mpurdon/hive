defmodule Hive.Logger do
  @moduledoc """
  Structured logging helpers with correlation across processes.

  Sets metadata on bee/job/quest processes so all log lines include
  identifying fields. Filterable by bee_id, job_id, quest_id.
  """

  require Logger

  @doc "Sets process metadata for a bee."
  @spec set_bee_context(String.t(), String.t(), String.t() | nil) :: :ok
  def set_bee_context(bee_id, job_id, quest_id \\ nil) do
    meta = [bee_id: bee_id, job_id: job_id]
    meta = if quest_id, do: Keyword.put(meta, :quest_id, quest_id), else: meta
    Logger.metadata(meta)
    :ok
  end

  @doc "Sets process metadata for the Queen."
  @spec set_queen_context() :: :ok
  def set_queen_context do
    Logger.metadata(role: :queen)
    :ok
  end

  @doc "Logs a structured event at info level."
  @spec info(String.t(), keyword()) :: :ok
  def info(message, extra \\ []) do
    Logger.info(message, extra)
  end

  @doc "Logs a structured event at warning level."
  @spec warn(String.t(), keyword()) :: :ok
  def warn(message, extra \\ []) do
    Logger.warning(message, extra)
  end

  @doc "Logs a structured event at error level."
  @spec error(String.t(), keyword()) :: :ok
  def error(message, extra \\ []) do
    Logger.error(message, extra)
  end
end
