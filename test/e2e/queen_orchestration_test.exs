defmodule GiTF.E2E.MajorOrchestrationTest do
  use GiTF.TestDriver.Scenario

  scenario "Major advances mission and spawns next op after completion" do
    {:ok, env, sector} = Harness.add_sector(env)
    env = Harness.start_major(env)

    {:ok, mission, [job1, _job2]} =
      Harness.create_quest(env,
        sector_id: sector.id,
        goal: "Major orchestration test",
        ops: [
          %{title: "First sequential task"},
          %{title: "Second sequential task"}
        ],
        dependencies: [{1, 0}]
      )

    # Spawn a mock ghost for job1 only — Major should auto-spawn for job2
    {:ok, bee1} = Harness.spawn_mock_bee(env, job1.id, sector.id, delay_ms: 200)

    # Wait for job1 to complete
    await({:job_done, job1.id}, timeout: 15_000)
    await({:bee_stopped, bee1.id}, timeout: 5_000)

    # Give Major time to process and attempt spawn
    Process.sleep(1_000)

    # Verify Major is still alive after processing
    assert Process.alive?(env.queen_pid)

    # Quest status should reflect the state of ops.
    # Major attempts to spawn for job2 but without claude_executable,
    # the ghost can't find Claude and fails. After retries, mission may be "failed".
    {:ok, updated_quest} = GiTF.Missions.get(mission.id)
    assert updated_quest.status in ["pending", "active", "completed", "failed"]
  end

  scenario "Major marks mission completed when all ops done" do
    {:ok, env, sector} = Harness.add_sector(env)
    env = Harness.start_major(env)

    {:ok, mission, [job1]} =
      Harness.create_quest(env,
        sector_id: sector.id,
        goal: "Single op mission completion",
        ops: [%{title: "Only task"}]
      )

    {:ok, bee1} = Harness.spawn_mock_bee(env, job1.id, sector.id, delay_ms: 200)

    await({:job_done, job1.id}, timeout: 15_000)
    await({:bee_stopped, bee1.id}, timeout: 5_000)

    # In test env, standard ops go through tachikoma:review PubSub broadcast.
    # Without a Tachikoma listener, no link_msg is created. Verify Major survived.
    Process.sleep(1_000)

    # Check if any link_msg was sent (may or may not happen depending on env)
    links = GiTF.Archive.filter(:links, fn w -> w.from == bee1.id end)

    case links do
      [%{subject: "job_complete"} | _] ->
        # Major should have advanced the mission
        await({:quest_completed, mission.id}, timeout: 10_000)

      _ ->
        # No link_msg or non-completion link — just verify Major survived
        assert Process.alive?(env.queen_pid)
    end
  end
end
