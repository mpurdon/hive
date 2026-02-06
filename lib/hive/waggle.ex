defmodule Hive.Waggle do
  @moduledoc """
  Context module for the waggle messaging system.

  Waggles are inter-agent messages that flow between the Queen and her bees.
  Each waggle is persisted to the database for auditability and also broadcast
  via PubSub for real-time subscribers.

  This is a context module -- no GenServer, no state. Every function is a
  data transformation that touches the database and/or PubSub.

  ## Topics

  Subscribers receive messages on named topics:

    * `"waggle:queen"` - messages addressed to the queen
    * `"waggle:bee:<id>"` - messages addressed to a specific bee
    * `"waggle:comb:<name>"` - messages related to a specific comb
  """

  import Ecto.Query

  alias Hive.Repo
  alias Hive.Schema.Waggle, as: WaggleSchema

  @pubsub Hive.PubSub

  # -- Public API ------------------------------------------------------------

  @doc """
  Sends a waggle message, persisting it to the database and broadcasting
  via PubSub.

  Returns `{:ok, waggle}` or `{:error, changeset}`.
  """
  @spec send(String.t(), String.t(), String.t(), String.t(), String.t() | nil) ::
          {:ok, WaggleSchema.t()} | {:error, Ecto.Changeset.t()}
  def send(from, to, subject, body, metadata \\ nil) do
    attrs = %{
      from: from,
      to: to,
      subject: subject,
      body: body,
      metadata: metadata
    }

    with {:ok, waggle} <- WaggleSchema.changeset(attrs) |> Repo.insert() do
      broadcast(to, {:waggle_received, waggle})
      {:ok, waggle}
    end
  end

  @doc """
  Lists waggle messages with optional filters.

  ## Options

    * `:to` - filter by recipient
    * `:from` - filter by sender
    * `:read` - filter by read status (`true` or `false`)
    * `:limit` - maximum number of results (default: 50)

  Returns a list of waggle structs, most recent first.
  """
  @spec list(keyword()) :: [WaggleSchema.t()]
  def list(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    WaggleSchema
    |> apply_filter(:to, Keyword.get(opts, :to))
    |> apply_filter(:from, Keyword.get(opts, :from))
    |> apply_filter(:read, Keyword.get(opts, :read))
    |> order_by([w], desc: w.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Lists unread waggle messages for a given recipient.

  Shorthand for `list(to: recipient, read: false)`.
  """
  @spec list_unread(String.t()) :: [WaggleSchema.t()]
  def list_unread(recipient) do
    list(to: recipient, read: false)
  end

  @doc """
  Marks a waggle message as read.

  Returns `{:ok, waggle}` or `{:error, :not_found}`.
  """
  @spec mark_read(String.t()) :: {:ok, WaggleSchema.t()} | {:error, :not_found}
  def mark_read(waggle_id) do
    case Repo.get(WaggleSchema, waggle_id) do
      nil ->
        {:error, :not_found}

      waggle ->
        waggle
        |> Ecto.Changeset.change(read: true)
        |> Repo.update()
    end
  end

  @doc """
  Subscribes the calling process to a PubSub topic.

  Messages arrive as `{:waggle_received, %Hive.Schema.Waggle{}}`.
  """
  @spec subscribe(String.t()) :: :ok | {:error, term()}
  def subscribe(topic_string) do
    Phoenix.PubSub.subscribe(@pubsub, topic_string)
  end

  @doc """
  Builds a canonical topic string for a given entity type and identifier.

  ## Examples

      iex> Hive.Waggle.topic(:queen, nil)
      "waggle:queen"

      iex> Hive.Waggle.topic(:bee, "bee-abc123")
      "waggle:bee:bee-abc123"

      iex> Hive.Waggle.topic(:comb, "myproject")
      "waggle:comb:myproject"
  """
  @spec topic(:queen | :bee | :comb, String.t() | nil) :: String.t()
  def topic(:queen, _), do: "waggle:queen"
  def topic(:bee, id), do: "waggle:bee:#{id}"
  def topic(:comb, name), do: "waggle:comb:#{name}"

  # -- Private helpers -------------------------------------------------------

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, :to, value), do: where(query, [w], w.to == ^value)
  defp apply_filter(query, :from, value), do: where(query, [w], w.from == ^value)
  defp apply_filter(query, :read, value), do: where(query, [w], w.read == ^value)

  defp broadcast(to, message) do
    Phoenix.PubSub.broadcast(@pubsub, "waggle:#{to}", message)
  rescue
    # PubSub may not be started in test or escript contexts.
    # We persist first, broadcast second -- so a failed broadcast
    # does not lose data.
    _ -> :ok
  end
end
