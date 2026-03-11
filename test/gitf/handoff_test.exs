defmodule GiTF.HandoffTest do
  use ExUnit.Case, async: false

  alias GiTF.Handoff
  alias GiTF.Store

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "gitf_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    GiTF.Test.StoreHelper.stop_store()
    {:ok, _} = GiTF.Store.start_link(data_dir: tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    # Set up a full ghost with op, shell, and links
    {:ok, sector} =
      Store.insert(:sectors, %{name: "handoff-sector-#{:erlang.unique_integer([:positive])}"})

    {:ok, mission} =
      Store.insert(:missions, %{
        name: "handoff-mission-#{:erlang.unique_integer([:positive])}",
        status: "pending"
      })

    {:ok, op} =
      GiTF.Ops.create(%{
        title: "Implement feature X",
        description: "Build the X feature with proper tests",
        mission_id: mission.id,
        sector_id: sector.id
      })

    {:ok, ghost} =
      Store.insert(:ghosts, %{name: "handoff-ghost", status: "working", op_id: op.id})

    {:ok, shell} =
      Store.insert(:shells, %{
        ghost_id: ghost.id,
        sector_id: sector.id,
        worktree_path: "/tmp/handoff-worktree",
        branch: "ghost/#{ghost.id}",
        status: "active"
      })

    # Create some links to/from this ghost
    {:ok, _sent} =
      GiTF.Link.send(ghost.id, "major", "progress", "50% done with feature X")

    {:ok, _received} =
      GiTF.Link.send("major", ghost.id, "guidance", "Focus on the API first")

    %{ghost: ghost, op: op, shell: shell, sector: sector, mission: mission}
  end

  describe "create/2" do
    test "creates a handoff link_msg for a ghost", ctx do
      assert {:ok, link_msg} = Handoff.create(ctx.ghost.id)

      assert link_msg.from == ctx.ghost.id
      assert link_msg.to == ctx.ghost.id
      assert link_msg.subject == "handoff"
      assert link_msg.read == false

      # The body should contain handoff context
      assert link_msg.body =~ "Handoff Context"
      assert link_msg.body =~ ctx.ghost.name
      assert link_msg.body =~ ctx.op.title
      assert link_msg.body =~ ctx.shell.worktree_path
      assert link_msg.body =~ ctx.shell.branch
    end

    test "captures op description in handoff", ctx do
      assert {:ok, link_msg} = Handoff.create(ctx.ghost.id)

      assert link_msg.body =~ "Implement feature X"
      assert link_msg.body =~ "Build the X feature"
    end

    test "captures recent links in handoff", ctx do
      assert {:ok, link_msg} = Handoff.create(ctx.ghost.id)

      # Should include mention of sent messages
      assert link_msg.body =~ "progress"
      # Should include mention of received messages
      assert link_msg.body =~ "guidance"
    end

    test "returns error for non-existent ghost" do
      assert {:error, :bee_not_found} = Handoff.create("ghost-nonexistent")
    end
  end

  describe "detect_handoff/1" do
    test "detects an unread handoff link_msg", ctx do
      {:ok, _waggle} = Handoff.create(ctx.ghost.id)

      assert {:ok, detected} = Handoff.detect_handoff(ctx.ghost.id)
      assert detected.subject == "handoff"
      assert detected.read == false
    end

    test "returns error when no handoff exists", ctx do
      assert {:error, :no_handoff} = Handoff.detect_handoff(ctx.ghost.id)
    end

    test "does not detect read handoffs", ctx do
      {:ok, link_msg} = Handoff.create(ctx.ghost.id)
      GiTF.Link.mark_read(link_msg.id)

      assert {:error, :no_handoff} = Handoff.detect_handoff(ctx.ghost.id)
    end
  end

  describe "resume/2" do
    test "reads handoff and returns a briefing", ctx do
      {:ok, link_msg} = Handoff.create(ctx.ghost.id)

      assert {:ok, briefing} = Handoff.resume(ctx.ghost.id, link_msg.id)

      assert briefing =~ "Handoff Briefing"
      assert briefing =~ "continuing work"
      assert briefing =~ "Handoff Context"
    end

    test "marks the handoff link_msg as read", ctx do
      {:ok, link_msg} = Handoff.create(ctx.ghost.id)
      assert link_msg.read == false

      {:ok, _briefing} = Handoff.resume(ctx.ghost.id, link_msg.id)

      updated = Store.get(:links, link_msg.id)
      assert updated.read == true
    end

    test "returns error for non-existent link_msg" do
      assert {:error, :handoff_not_found} = Handoff.resume("ghost-123", "wag-nonexistent")
    end
  end

  describe "create/2 with session_id" do
    test "includes session_id section in handoff body", ctx do
      assert {:ok, link_msg} = Handoff.create(ctx.ghost.id, session_id: "sess-abc123")

      assert link_msg.body =~ "## Session ID"
      assert link_msg.body =~ "sess-abc123"
    end

    test "omits session_id section when not provided", ctx do
      assert {:ok, link_msg} = Handoff.create(ctx.ghost.id)

      refute link_msg.body =~ "## Session ID"
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
      assert {:ok, markdown} = Handoff.build_handoff_context(ctx.ghost.id)

      # Check all sections are present
      assert markdown =~ "# Handoff Context"
      assert markdown =~ "## Bee Status"
      assert markdown =~ "## Job"
      assert markdown =~ "## Workspace"
      assert markdown =~ "## Recent Messages Sent"
      assert markdown =~ "## Recent Messages Received"
      assert markdown =~ "## Instructions for Continuation"
    end

    test "handles ghost with no op" do
      {:ok, ghost} = Store.insert(:ghosts, %{name: "jobless-ghost", status: "idle"})

      assert {:ok, markdown} = Handoff.build_handoff_context(ghost.id)
      assert markdown =~ "No op assigned"
    end

    test "handles ghost with no shell" do
      {:ok, ghost} = Store.insert(:ghosts, %{name: "cellless-ghost", status: "idle"})

      assert {:ok, markdown} = Handoff.build_handoff_context(ghost.id)
      assert markdown =~ "No workspace assigned"
    end

    test "returns error for non-existent ghost" do
      assert {:error, :bee_not_found} = Handoff.build_handoff_context("ghost-000000")
    end
  end
end
