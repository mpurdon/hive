defmodule Hive.ProgressTest do
  use ExUnit.Case, async: true

  alias Hive.Progress

  setup do
    # Ensure table exists (may already from Application.start)
    Progress.init()
    :ok
  end

  describe "update/2 and get/1" do
    test "stores and retrieves progress" do
      bee_id = "bee-progress-test-#{:erlang.unique_integer([:positive])}"
      Progress.update(bee_id, %{tool: "Edit", file: "lib/foo.ex", message: "Editing file"})

      entry = Progress.get(bee_id)
      assert entry.bee_id == bee_id
      assert entry.tool == "Edit"
      assert entry.file == "lib/foo.ex"
      assert entry.message == "Editing file"
      assert is_integer(entry.updated_at)

      # Cleanup
      Progress.clear(bee_id)
    end
  end

  describe "all/0" do
    test "returns all entries" do
      id1 = "bee-prog-all-#{:erlang.unique_integer([:positive])}"
      id2 = "bee-prog-all-#{:erlang.unique_integer([:positive])}"

      Progress.update(id1, %{tool: "Read", message: "Reading"})
      Progress.update(id2, %{tool: "Write", message: "Writing"})

      all = Progress.all()
      bee_ids = Enum.map(all, & &1.bee_id)
      assert id1 in bee_ids
      assert id2 in bee_ids

      Progress.clear(id1)
      Progress.clear(id2)
    end
  end

  describe "clear/1" do
    test "removes an entry" do
      bee_id = "bee-clear-#{:erlang.unique_integer([:positive])}"
      Progress.update(bee_id, %{tool: "Bash", message: "Running"})
      assert Progress.get(bee_id) != nil

      Progress.clear(bee_id)
      assert Progress.get(bee_id) == nil
    end
  end

  describe "get/1 for missing" do
    test "returns nil for unknown bee" do
      assert Progress.get("bee-nonexistent-999") == nil
    end
  end
end
