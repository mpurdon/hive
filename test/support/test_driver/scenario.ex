defmodule Hive.TestDriver.Scenario do
  @moduledoc """
  DSL for writing Hive E2E test scenarios.

  `use Hive.TestDriver.Scenario` sets up ExUnit with harness boot/teardown
  and imports assertion helpers. The `scenario` macro wraps a test body
  with recorder lifecycle management.

  ## Example

      defmodule MyE2ETest do
        use Hive.TestDriver.Scenario

        scenario "quest completes with two jobs" do
          {:ok, env, comb} = Harness.add_comb(env)
          {:ok, quest, [job1, job2]} = Harness.create_quest(env,
            jobs: [%{title: "Job 1"}, %{title: "Job 2"}]
          )

          {:ok, _bee1} = Harness.spawn_mock_bee(env, job1.id, comb.id)
          {:ok, _bee2} = Harness.spawn_mock_bee(env, job2.id, comb.id)

          await {:job_done, job1.id}
          await {:job_done, job2.id}
          assert_waggle subject: "job_complete", from: _bee1.id
        end
      end

  """

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case, async: false

      alias Hive.TestDriver.Harness
      alias Hive.TestDriver.Recorder
      alias Hive.TestDriver.MockClaude

      import Hive.TestDriver.Assertions
      import Hive.TestDriver.Scenario, only: [scenario: 2]

      @moduletag :e2e

      setup do
        # Hide real Claude from the Validator's find_executable lookup.
        # Bee Workers use claude_executable directly (mock scripts), so
        # they're unaffected. This prevents the Validator from spawning
        # real Claude for diff assessment (which takes 60s to timeout).
        # We filter PATH entries to remove directories containing the
        # claude binary while keeping git, sh, etc. available.
        original_path = System.get_env("PATH")

        filtered_path =
          original_path
          |> String.split(":")
          |> Enum.reject(fn dir ->
            File.exists?(Path.join(dir, "claude"))
          end)
          |> Enum.join(":")

        System.put_env("PATH", filtered_path)

        env = Harness.boot()
        {:ok, _} = Recorder.start_link()

        on_exit(fn ->
          Recorder.stop()
          Harness.teardown(env)
          System.put_env("PATH", original_path)
        end)

        %{env: env}
      end
    end
  end

  @doc """
  Defines an E2E scenario.

  Wraps the test body with the harness environment from the setup context.
  The `env` variable is automatically available in the scenario body.
  """
  defmacro scenario(name, do: block) do
    quote do
      @tag :e2e
      test unquote(name), %{env: var!(env)} do
        _ = var!(env)
        unquote(block)
      end
    end
  end
end
