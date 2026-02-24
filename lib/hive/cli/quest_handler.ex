defmodule Hive.CLI.QuestHandler do
  @moduledoc """
  CLI handler for quest subcommands.

  Extracted from `Hive.CLI` to reduce the monolithic dispatch file.
  The main CLI module delegates quest-related dispatch calls here.
  """

  alias Hive.CLI.Format

  def dispatch([:quest, :new], result, helpers) do
    goal = helpers.result_get.(result, :args, :goal)

    case helpers.resolve_comb_id.(helpers.result_get.(result, :options, :comb)) do
      {:ok, comb_id} ->
        case Hive.Quests.create(%{goal: goal, comb_id: comb_id}) do
          {:ok, quest} ->
            Format.success("Quest created: #{quest.name} (#{quest.id})")

          {:error, reason} ->
            Format.error("Failed to create quest: #{inspect(reason)}")
        end

      {:error, :no_comb} ->
        Format.error("No comb specified. Use --comb or set one with `hive comb use`.")
    end
  end

  def dispatch([:quest, :list], _result, _helpers) do
    case Hive.Quests.list() do
      [] ->
        Format.info("No quests yet. Create one with `hive quest new \"<goal>\"`")

      quests ->
        headers = ["ID", "Name", "Status", "Jobs", "Created"]

        rows =
          Enum.map(quests, fn q ->
            job_summary =
              case q[:jobs] do
                nil -> "-"
                jobs -> "#{length(jobs)}"
              end

            [q.id, q.name, q.status, job_summary, Calendar.strftime(q.inserted_at, "%Y-%m-%d")]
          end)

        Format.table(headers, rows)
    end
  end

  def dispatch([:quest, :show], result, helpers) do
    id = helpers.result_get.(result, :args, :id)

    case Hive.Quests.get(id) do
      {:ok, quest} ->
        IO.puts("Quest: #{quest.name}")
        IO.puts("ID:     #{quest.id}")
        IO.puts("Status: #{quest.status}")
        IO.puts("Phase:  #{Map.get(quest, :current_phase, "pending")}")
        IO.puts("")

        # Phase timeline
        display_phase_timeline(quest)

        # Artifact summaries
        display_artifact_summaries(quest)

        # Jobs table
        case quest[:jobs] do
          nil ->
            Format.info("No jobs yet.")

          [] ->
            Format.info("No jobs yet.")

          jobs ->
            # Separate phase jobs from implementation jobs
            phase_jobs = Enum.filter(jobs, & &1[:phase_job])
            impl_jobs = Enum.reject(jobs, & &1[:phase_job])

            if impl_jobs != [] do
              IO.puts("Implementation Jobs:")
              headers = ["Job ID", "Title", "Status", "Bee", "Model"]

              rows =
                Enum.map(impl_jobs, fn j ->
                  [
                    j.id,
                    String.slice(j.title, 0, 50),
                    j.status,
                    j.bee_id || "-",
                    j[:assigned_model] || "-"
                  ]
                end)

              Format.table(headers, rows)
            end

            if phase_jobs != [] do
              IO.puts("\nPhase Jobs:")
              headers = ["Phase", "Status", "Job ID"]

              rows =
                Enum.map(phase_jobs, fn j ->
                  [j[:phase] || "-", j.status, j.id]
                end)

              Format.table(headers, rows)
            end
        end

      {:error, :not_found} ->
        Format.error("Quest not found: #{id}")
    end
  end

  def dispatch([:quest, :delete], result, helpers) do
    id = helpers.result_get.(result, :args, :id)

    case Hive.Quests.delete(id) do
      :ok -> Format.success("Quest #{id} deleted.")
      {:error, reason} -> Format.error("Failed to delete quest: #{inspect(reason)}")
    end
  end

  def dispatch(_path, _result, _helpers), do: :not_handled

  # -- Private helpers ---------------------------------------------------------

  defp display_phase_timeline(quest) do
    phases = Hive.Queen.Orchestrator.phases()
    current = Map.get(quest, :current_phase, "pending")
    artifacts = Map.get(quest, :artifacts, %{})

    timeline =
      Enum.map_join(phases, " -> ", fn phase ->
        cond do
          Map.has_key?(artifacts, phase) -> "[#{phase}]"
          phase == current -> "*#{phase}*"
          true -> phase
        end
      end)

    IO.puts("Pipeline: #{timeline}")
    IO.puts("")
  end

  defp display_artifact_summaries(quest) do
    artifacts = Map.get(quest, :artifacts, %{})

    if map_size(artifacts) > 0 do
      IO.puts("Phase Artifacts:")

      Enum.each(artifacts, fn {phase, artifact} ->
        summary =
          case phase do
            "research" ->
              key_files = Map.get(artifact, "key_files", [])
              "#{length(key_files)} key files, stack: #{inspect(Map.get(artifact, "tech_stack", []))}"

            "requirements" ->
              reqs = Map.get(artifact, "functional_requirements", [])
              "#{length(reqs)} functional requirements"

            "design" ->
              comps = Map.get(artifact, "components", [])
              "#{length(comps)} components"

            "review" ->
              if Map.get(artifact, "approved"), do: "Approved", else: "Rejected"

            "planning" when is_list(artifact) ->
              "#{length(artifact)} jobs planned"

            "validation" ->
              "Verdict: #{Map.get(artifact, "overall_verdict", "unknown")}"

            _ ->
              "completed"
          end

        IO.puts("  #{phase}: #{summary}")
      end)

      IO.puts("")
    end
  end
end
