defmodule Hive.HandoffTest do
  use ExUnit.Case, async: false

  alias Hive.Handoff
  alias Hive.Store

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "hive_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    if Process.whereis(Hive.Store), do: GenServer.stop(Hive.Store)
    {:ok, _} = Hive.Store.start_link(data_dir: tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    # Set up a full bee with job, cell, and waggles
    {:ok, comb} =
      Store.insert(:combs, %{name: "handoff-comb-#{:erlang.unique_integer([:positive])}"})

    {:ok, quest} =
      Store.insert(:quests, %{
        name: "handoff-quest-#{:erlang.unique_integer([:positive])}",
        status: "pending"
      })

    {:ok, job} =
      Hive.Jobs.create(%{
        title: "Implement feature X",
        description: "Build the X feature with proper tests",
        quest_id: quest.id,
        comb_id: comb.id
      })

    {:ok, bee} =
      Store.insert(:bees, %{name: "handoff-bee", status: "working", job_id: job.id})

    {:ok, cell} =
      Store.insert(:cells, %{
        bee_id: bee.id,
        comb_id: comb.id,
        worktree_path: "/tmp/handoff-worktree",
        branch: "bee/#{bee.id}",
        status: "active"
      })

    # Create some waggles to/from this bee
    {:ok, _sent} =
      Hive.Waggle.send(bee.id, "queen", "progress", "50% done with feature X")

    {:ok, _received} =
      Hive.Waggle.send("queen", bee.id, "guidance", "Focus on the API first")

    %{bee: bee, job: job, cell: cell, comb: comb, quest: quest}
  end

  describe "create/2" do
    test "creates a handoff waggle for a bee", ctx do
      assert {:ok, waggle} = Handoff.create(ctx.bee.id)

      assert waggle.from == ctx.bee.id
      assert waggle.to == ctx.bee.id
      assert waggle.subject == "handoff"
      assert waggle.read == false

      # The body should contain handoff context
      assert waggle.body =~ "Handoff Context"
      assert waggle.body =~ ctx.bee.name
      assert waggle.body =~ ctx.job.title
      assert waggle.body =~ ctx.cell.worktree_path
      assert waggle.body =~ ctx.cell.branch
    end

    test "captures job description in handoff", ctx do
      assert {:ok, waggle} = Handoff.create(ctx.bee.id)

      assert waggle.body =~ "Implement feature X"
      assert waggle.body =~ "Build the X feature"
    end

    test "captures recent waggles in handoff", ctx do
      assert {:ok, waggle} = Handoff.create(ctx.bee.id)

      # Should include mention of sent messages
      assert waggle.body =~ "progress"
      # Should include mention of received messages
      assert waggle.body =~ "guidance"
    end

    test "returns error for non-existent bee" do
      assert {:error, :bee_not_found} = Handoff.create("bee-nonexistent")
    end
  end

  describe "detect_handoff/1" do
    test "detects an unread handoff waggle", ctx do
      {:ok, _waggle} = Handoff.create(ctx.bee.id)

      assert {:ok, detected} = Handoff.detect_handoff(ctx.bee.id)
      assert detected.subject == "handoff"
      assert detected.read == false
    end

    test "returns error when no handoff exists", ctx do
      assert {:error, :no_handoff} = Handoff.detect_handoff(ctx.bee.id)
    end

    test "does not detect read handoffs", ctx do
      {:ok, waggle} = Handoff.create(ctx.bee.id)
      Hive.Waggle.mark_read(waggle.id)

      assert {:error, :no_handoff} = Handoff.detect_handoff(ctx.bee.id)
    end
  end

  describe "resume/2" do
    test "reads handoff and returns a briefing", ctx do
      {:ok, waggle} = Handoff.create(ctx.bee.id)

      assert {:ok, briefing} = Handoff.resume(ctx.bee.id, waggle.id)

      assert briefing =~ "Handoff Briefing"
      assert briefing =~ "continuing work"
      assert briefing =~ "Handoff Context"
    end

    test "marks the handoff waggle as read", ctx do
      {:ok, waggle} = Handoff.create(ctx.bee.id)
      assert waggle.read == false

      {:ok, _briefing} = Handoff.resume(ctx.bee.id, waggle.id)

      updated = Store.get(:waggles, waggle.id)
      assert updated.read == true
    end

    test "returns error for non-existent waggle" do
      assert {:error, :handoff_not_found} = Handoff.resume("bee-123", "wag-nonexistent")
    end
  end

  describe "create/2 with session_id" do
    test "includes session_id section in handoff body", ctx do
      assert {:ok, waggle} = Handoff.create(ctx.bee.id, session_id: "sess-abc123")

      assert waggle.body =~ "## Session ID"
      assert waggle.body =~ "sess-abc123"
    end

    test "omits session_id section when not provided", ctx do
      assert {:ok, waggle} = Handoff.create(ctx.bee.id)

      refute waggle.body =~ "## Session ID"
    end
  end

  describe "extract_session_id/1" do
    test "extracts session_id from handoff body" do
      body = """
      # Handoff Context
      Some content here.

      ## Session ID
      sess-abc123
      """

      assert "sess-abc123" = Handoff.extract_session_id(body)
    end

    test "returns nil for body without session_id" do
      body = """
      # Handoff Context
      Some content here.
      No session ID section.
      """

      assert nil == Handoff.extract_session_id(body)
    end

    test "returns nil for nil body" do
      assert nil == Handoff.extract_session_id(nil)
    end

    test "trims whitespace from extracted session_id" do
      body = "## Session ID\n  sess-with-spaces  \n"

      assert "sess-with-spaces" = Handoff.extract_session_id(body)
    end
  end

  describe "build_handoff_context/1" do
    test "builds markdown with all sections", ctx do
      assert {:ok, markdown} = Handoff.build_handoff_context(ctx.bee.id)

      # Check all sections are present
      assert markdown =~ "# Handoff Context"
      assert markdown =~ "## Bee Status"
      assert markdown =~ "## Job"
      assert markdown =~ "## Workspace"
      assert markdown =~ "## Recent Messages Sent"
      assert markdown =~ "## Recent Messages Received"
      assert markdown =~ "## Instructions for Continuation"
    end

    test "handles bee with no job" do
      {:ok, bee} = Store.insert(:bees, %{name: "jobless-bee", status: "idle"})

      assert {:ok, markdown} = Handoff.build_handoff_context(bee.id)
      assert markdown =~ "No job assigned"
    end

    test "handles bee with no cell" do
      {:ok, bee} = Store.insert(:bees, %{name: "cellless-bee", status: "idle"})

      assert {:ok, markdown} = Handoff.build_handoff_context(bee.id)
      assert markdown =~ "No workspace assigned"
    end

    test "returns error for non-existent bee" do
      assert {:error, :bee_not_found} = Handoff.build_handoff_context("bee-000000")
    end
  end
end
