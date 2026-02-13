defmodule Hive.TUI.Bridge do
  @moduledoc """
  Connects TUI <-> Hive core.

  Subscribes to PubSub topics, converts waggles to TUI messages.
  Forwards user input to Queen's Claude port.
  Queries Store for state snapshots.
  """

  @topics [
    "waggle:queen",
    "hive:progress",
    "hive:system",
    "plugins:loaded",
    "plugins:unloaded"
  ]

  @doc "Subscribe to all relevant PubSub topics."
  @spec subscribe() :: :ok
  def subscribe do
    for topic <- @topics do
      Phoenix.PubSub.subscribe(Hive.PubSub, topic)
    end

    :ok
  end

  @doc "Unsubscribe from all topics."
  @spec unsubscribe() :: :ok
  def unsubscribe do
    for topic <- @topics do
      Phoenix.PubSub.unsubscribe(Hive.PubSub, topic)
    end

    :ok
  end

  @doc "Send user input text to the Queen's Claude session."
  @spec send_to_queen(String.t()) :: :ok
  def send_to_queen(text) do
    Phoenix.PubSub.broadcast(Hive.PubSub, "queen:input", {:user_input, text})
    :ok
  end

  @doc "Get a snapshot of current hive state for display."
  @spec state_snapshot() :: map()
  def state_snapshot do
    %{
      bees: list_bees(),
      quests: list_quests(),
      jobs: list_jobs(),
      progress: list_progress()
    }
  end

  @doc "Lists all bees with their current status."
  @spec list_bees() :: [map()]
  def list_bees do
    Hive.Bees.list()
  rescue
    _ -> []
  end

  @doc "Lists all quests."
  @spec list_quests() :: [map()]
  def list_quests do
    Hive.Quests.list()
  rescue
    _ -> []
  end

  @doc "Lists all jobs."
  @spec list_jobs() :: [map()]
  def list_jobs do
    Hive.Jobs.list()
  rescue
    _ -> []
  end

  @doc "Lists current bee progress entries."
  @spec list_progress() :: [map()]
  def list_progress do
    Hive.Progress.all()
  rescue
    _ -> []
  end
end
