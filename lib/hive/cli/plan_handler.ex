defmodule Hive.CLI.PlanHandler do
  @moduledoc """
  CLI handler for interactive planning sessions.
  """

  alias Hive.CLI.Format

  def dispatch([:plan], result, helpers) do
    if Hive.Client.remote?() do
      dispatch_remote(result, helpers)
    else
      dispatch_local(result, helpers)
    end
  end

  def dispatch(_path, _result, _helpers), do: :not_handled

  defp dispatch_remote(result, helpers) do
    quest_id = helpers.result_get.(result, :options, :quest)
    goal = helpers.result_get.(result, :args, :goal)

    quest =
      cond do
        quest_id ->
          case Hive.Client.get_quest(quest_id) do
            {:ok, q} -> q
            {:error, _} ->
              Format.error("Quest not found: #{quest_id}")
              System.halt(1)
          end

        goal ->
          comb_opt = helpers.result_get.(result, :options, :comb)
          attrs = if comb_opt, do: %{goal: goal, comb_id: comb_opt}, else: %{goal: goal}

          case Hive.Client.create_quest(attrs) do
            {:ok, q} ->
              Format.success("Created quest: #{q.name} (#{q.id})")
              q

            {:error, reason} ->
              Format.error("Failed to create quest: #{inspect(reason)}")
              System.halt(1)
          end

        true ->
          Format.error("Usage: hive plan \"<goal>\" OR hive plan --quest <id>")
          System.halt(1)
      end

    # Remote mode: no interactive session, just start the quest on the server
    Format.info("Starting quest execution on remote server...")

    case Hive.Client.start_quest(quest.id) do
      {:ok, data} ->
        phase = if is_map(data), do: data[:phase], else: data
        Format.success("Quest #{quest.id} is now in #{phase} phase.")
        Format.info("Monitor with: HIVE_SERVER=#{Hive.Client.server_url()} hive quest status #{quest.id}")

      {:error, reason} ->
        Format.warn("Could not auto-start: #{inspect(reason)}")
        Format.info("Start manually: hive quest start #{quest.id}")
    end
  end

  defp dispatch_local(result, helpers) do
    quest_id = helpers.result_get.(result, :options, :quest)
    goal = helpers.result_get.(result, :args, :goal)

    quest =
      cond do
        quest_id ->
          case Hive.Quests.get(quest_id) do
            {:ok, q} -> q
            _ ->
              Format.error("Quest not found: #{quest_id}")
              System.halt(1)
          end

        goal ->
          case helpers.resolve_comb_id.(helpers.result_get.(result, :options, :comb)) do
            {:ok, comb_id} ->
              {:ok, q} = Hive.Quests.create(%{goal: goal, comb_id: comb_id})
              Format.success("Created quest: #{q.name} (#{q.id})")
              q

            {:error, :no_comb} ->
              Format.error("No comb specified. Use --comb or set a default with `hive comb use <id>`.")
              System.halt(1)
          end

        true ->
          Format.error("Usage: hive plan \"<goal>\" OR hive plan --quest <id>")
          System.halt(1)
      end

    start_interactive_planning(quest)
  end

  defp start_interactive_planning(quest) do
    Format.info("Planning session for: #{quest.name}")
    {:ok, root} = Hive.hive_dir()
    workspace = Path.join([root, ".hive", "planning", quest.id])
    File.mkdir_p!(workspace)

    system_prompt = build_planning_prompt(quest)
    mode = Hive.Runtime.ModelResolver.execution_mode()

    if mode == :api do
      Format.warn("API mode: skipping interactive session, starting automated pipeline.")
    else
      Format.info("Launching Claude Code for planning...")

      case Hive.Runtime.Models.spawn_interactive(workspace, prompt: system_prompt) do
        {:ok, port} when is_port(port) ->
          receive do
            {^port, {:exit_status, _}} -> :ok
          end

        {:error, reason} ->
          Format.error("Failed to launch: #{inspect(reason)}")
      end
    end

    # Auto-start quest execution
    Format.info("Starting quest execution...")

    case Hive.Queen.Orchestrator.start_quest(quest.id) do
      {:ok, phase} ->
        Format.success("Quest #{quest.id} is now in #{phase} phase.")
        Format.info("Run `hive server` to monitor progress.")

      {:error, reason} ->
        Format.warn("Could not auto-start: #{inspect(reason)}")
        Format.info("Start manually: hive quest start #{quest.id}")
    end
  end

  defp build_planning_prompt(quest) do
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
end
