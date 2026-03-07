defmodule Hive.CLI.PlanHandler do
  @moduledoc """
  Interactive planning sessions for quests.

  Public API used by CLI and QuestHandler to launch Claude-assisted planning
  before auto-starting quest execution.
  """

  alias Hive.CLI.Format

  @doc """
  Launch an interactive planning session for a quest, then auto-start execution.
  """
  def start_interactive_planning(quest, _opts \\ []) do
    Format.info("Planning session for: #{quest.name}")

    mode = Hive.Runtime.ModelResolver.execution_mode()

    plan_result =
      if mode == :api do
        Hive.CLI.Chat.start(quest)
      else
        {:ok, root} = Hive.hive_dir()
        workspace = Path.join([root, ".hive", "planning", quest.id])
        File.mkdir_p!(workspace)

        Format.info("Launching Claude Code for planning...")

        case Hive.Runtime.Models.spawn_interactive(workspace, prompt: build_planning_prompt(quest)) do
          {:ok, port} when is_port(port) ->
            receive do
              {^port, {:exit_status, _}} -> :ok
            end

          {:error, reason} ->
            Format.error("Failed to launch: #{inspect(reason)}")
        end

        :cli_done
      end

    case plan_result do
      {:ok, plan} ->
        create_jobs_from_plan(quest, plan)

      {:error, reason} ->
        Format.warn("Planning ended: #{inspect(reason)}")

      :cli_done ->
        # CLI mode — quest execution managed separately
        start_quest_execution(quest)
    end
  end

  defp create_jobs_from_plan(quest, plan) do
    comb_id = quest.comb_id || first_comb_id()

    unless comb_id do
      Format.error("No comb available. Add a comb first with `hive comb add <repo>`.")
      return_early()
    end

    # Update quest name if the plan provided one
    if plan[:name] && plan[:name] != "" do
      case Hive.Store.get(:quests, quest.id) do
        nil -> :ok
        q -> Hive.Store.put(:quests, %{q | name: plan[:name]})
      end
    end

    # Create jobs from plan
    jobs = plan[:jobs] || []

    created =
      Enum.map(jobs, fn job_spec ->
        attrs = %{
          title: job_spec["title"],
          description: job_spec["description"],
          job_type: job_spec["job_type"] || "implementation",
          quest_id: quest.id,
          comb_id: comb_id
        }

        case Hive.Jobs.create(attrs) do
          {:ok, job} ->
            Format.success("  Job: #{job.title} (#{job.id})")
            job

          {:error, reason} ->
            Format.error("  Failed to create job: #{inspect(reason)}")
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Wire up dependencies
    Enum.each(Enum.with_index(jobs), fn {job_spec, idx} ->
      deps = job_spec["depends_on"] || []

      Enum.each(deps, fn dep_idx ->
        job = Enum.at(created, idx)
        dep = Enum.at(created, dep_idx)

        if job && dep do
          Hive.Jobs.add_dependency(job.id, dep.id)
        end
      end)
    end)

    Format.success("Created #{length(created)} job(s) for quest #{quest.id}.")
    start_quest_execution(quest)
  end

  defp start_quest_execution(quest) do
    answer = IO.gets("Start execution now? [y/n] ") |> String.trim() |> String.downcase()

    if answer in ["y", "yes", ""] do
      Format.info("Starting quest execution...")

      case Hive.Queen.Orchestrator.start_quest(quest.id) do
        {:ok, phase} ->
          Format.success("Quest #{quest.id} is now in #{phase} phase.")
          Format.info("Run `hive server` to monitor progress.")

        {:error, reason} ->
          Format.warn("Could not auto-start: #{inspect(reason)}")
      end
    else
      Format.info("Quest ready. Run `hive quest start #{quest.id}` when ready.")
    end
  end

  defp first_comb_id do
    case Hive.Store.all(:combs) do
      [comb | _] -> comb.id
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp return_early, do: :ok

  @doc false
  def build_planning_prompt(quest) do
    """
    You are an expert software architect and planner.
    Your goal is to help the user plan the implementation of: "#{quest.goal}"

    Collaborate with the user to define:
    1. Research needs
    2. Requirements
    3. Architecture/Design
    4. Implementation Plan (Jobs)

    You have tools to read the codebase.
    Finally, produce a plan artifact using the `submit_plan` tool.
    """
  end

  @doc false
  def build_discovery_prompt(quest) do
    """
    You are an expert software architect helping a user discover and define their project goal.

    The user started a new quest but hasn't specified a concrete goal yet.
    Quest: #{quest.name} (#{quest.id})

    Help the user by:
    1. Asking what they want to build or change
    2. Exploring the codebase to understand the current state
    3. Clarifying scope and constraints
    4. Once the goal is clear, collaboratively plan the implementation

    Then produce a plan artifact using the `submit_plan` tool.
    Be conversational and curious — draw the goal out of the user.
    """
  end
end
