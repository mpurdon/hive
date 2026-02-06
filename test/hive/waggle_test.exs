defmodule Hive.WaggleTest do
  use ExUnit.Case, async: false

  alias Hive.Waggle
  alias Hive.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  describe "send/5" do
    test "persists a waggle message to the database" do
      assert {:ok, waggle} = Waggle.send("queen", "bee-abc123", "Do work", "Build the feature")

      assert waggle.from == "queen"
      assert waggle.to == "bee-abc123"
      assert waggle.subject == "Do work"
      assert waggle.body == "Build the feature"
      assert waggle.read == false
      assert String.starts_with?(waggle.id, "wag-")
    end

    test "accepts optional metadata" do
      assert {:ok, waggle} =
               Waggle.send("bee-a", "queen", "Done", "Finished", ~s({"pr": 42}))

      assert waggle.metadata == ~s({"pr": 42})
    end
  end

  describe "list/1" do
    test "returns all messages with no filters" do
      {:ok, _} = Waggle.send("queen", "bee-a", "Task 1", "Body 1")
      {:ok, _} = Waggle.send("queen", "bee-b", "Task 2", "Body 2")

      waggles = Waggle.list()
      assert length(waggles) == 2
    end

    test "filters by recipient" do
      {:ok, _} = Waggle.send("queen", "bee-a", "For A", "Body")
      {:ok, _} = Waggle.send("queen", "bee-b", "For B", "Body")

      waggles = Waggle.list(to: "bee-a")
      assert length(waggles) == 1
      assert hd(waggles).to == "bee-a"
    end

    test "filters by sender" do
      {:ok, _} = Waggle.send("queen", "bee-a", "From queen", "Body")
      {:ok, _} = Waggle.send("bee-a", "queen", "From bee", "Body")

      waggles = Waggle.list(from: "queen")
      assert length(waggles) == 1
      assert hd(waggles).from == "queen"
    end

    test "filters by read status" do
      {:ok, w} = Waggle.send("queen", "bee-a", "Read me", "Body")
      {:ok, _} = Waggle.send("queen", "bee-b", "Unread", "Body")

      Waggle.mark_read(w.id)

      unread = Waggle.list(read: false)
      assert length(unread) == 1
      assert hd(unread).subject == "Unread"
    end
  end

  describe "list_unread/1" do
    test "returns only unread messages for a given recipient" do
      {:ok, w1} = Waggle.send("queen", "bee-a", "First", "Body")
      {:ok, _} = Waggle.send("queen", "bee-a", "Second", "Body")
      {:ok, _} = Waggle.send("queen", "bee-b", "Other", "Body")

      Waggle.mark_read(w1.id)

      unread = Waggle.list_unread("bee-a")
      assert length(unread) == 1
      assert hd(unread).subject == "Second"
    end
  end

  describe "mark_read/1" do
    test "marks a message as read" do
      {:ok, waggle} = Waggle.send("queen", "bee-a", "Read me", "Body")
      assert waggle.read == false

      assert {:ok, updated} = Waggle.mark_read(waggle.id)
      assert updated.read == true
    end

    test "returns error for unknown ID" do
      assert {:error, :not_found} = Waggle.mark_read("wag-000000")
    end
  end
end

defmodule Hive.Waggle.TopicTest do
  use ExUnit.Case, async: true

  # Topic building is a pure function -- no DB needed.

  alias Hive.Waggle

  describe "topic/2" do
    test "builds queen topic" do
      assert Waggle.topic(:queen, nil) == "waggle:queen"
    end

    test "builds bee topic with ID" do
      assert Waggle.topic(:bee, "bee-abc123") == "waggle:bee:bee-abc123"
    end

    test "builds comb topic with name" do
      assert Waggle.topic(:comb, "myproject") == "waggle:comb:myproject"
    end
  end
end
