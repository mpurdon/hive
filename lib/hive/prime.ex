defmodule Hive.Prime do
  @moduledoc """
  Generates context prompts for Claude Code sessions.

  Priming is the act of feeding Claude its initial context at session start.
  The Queen gets the QUEEN.md instructions plus a snapshot of the current
  hive state. A Bee gets its specific job description, relevant waggles,
  and information about the comb it is working on.

  Output is Markdown text, ready for Claude to parse.
  """

  import Ecto.Query

  alias Hive.Repo
  alias Hive.Schema.{Bee, Cell, Job}

  # -- Public API ------------------------------------------------------------

  @doc """
  Primes a Queen or Bee with context for a Claude Code session.

  - `prime(:queen, hive_root)` reads QUEEN.md and appends current hive state
  - `prime(:bee, bee_id)` builds a briefing from the bee's job, cell, and waggles

  Returns `{:ok, markdown}` or `{:error, reason}`.
  """
  @spec prime(:queen | :bee, String.t()) :: {:ok, String.t()} | {:error, term()}
  def prime(role, identifier)

  def prime(:queen, hive_root) do
    queen_md_path = Path.join([hive_root, ".hive", "queen", "QUEEN.md"])

    with {:ok, instructions} <- File.read(queen_md_path) do
      state_summary = build_queen_state_summary()
      {:ok, instructions <> "\n\n" <> state_summary}
    end
  end

  def prime(:bee, bee_id) do
    with {:ok, bee} <- fetch_bee(bee_id) do
      markdown = build_bee_briefing(bee)
      handoff_section = build_handoff_section(bee_id)
      {:ok, markdown <> handoff_section}
    end
  end

  # -- Private: Queen --------------------------------------------------------

  defp build_queen_state_summary do
    bees = Repo.all(Bee)
    active_bees = Enum.filter(bees, &(&1.status in ["working", "idle", "starting"]))
    pending_jobs = Repo.all(from(j in Job, where: j.status == "pending"))
    recent_waggles = Hive.Waggle.list(to: "queen", limit: 10)

    sections = [
      "---",
      "## Current Hive State",
      "",
      "### Active Bees (#{length(active_bees)})",
      format_bees(active_bees),
      "",
      "### Pending Jobs (#{length(pending_jobs)})",
      format_jobs(pending_jobs),
      "",
      "### Recent Messages to Queen (#{length(recent_waggles)})",
      format_waggles(recent_waggles)
    ]

    Enum.join(sections, "\n")
  end

  defp format_bees([]), do: "None."

  defp format_bees(bees) do
    bees
    |> Enum.map(fn b -> "- **#{b.name}** (#{b.id}): #{b.status}" end)
    |> Enum.join("\n")
  end

  defp format_jobs([]), do: "None."

  defp format_jobs(jobs) do
    jobs
    |> Enum.map(fn j -> "- **#{j.title}** (#{j.id})" end)
    |> Enum.join("\n")
  end

  defp format_waggles([]), do: "None."

  defp format_waggles(waggles) do
    waggles
    |> Enum.map(fn w ->
      read_marker = if w.read, do: "[read]", else: "[unread]"
      "- #{read_marker} From #{w.from}: #{w.subject || "(no subject)"}"
    end)
    |> Enum.join("\n")
  end

  # -- Private: Bee ----------------------------------------------------------

  defp fetch_bee(bee_id) do
    query = from(b in Bee, where: b.id == ^bee_id, limit: 1)

    case Repo.one(query) do
      nil -> {:error, :bee_not_found}
      bee -> {:ok, bee}
    end
  end

  defp build_bee_briefing(bee) do
    job = fetch_job_for_bee(bee)
    cell = fetch_cell_for_bee(bee)
    waggles = Hive.Waggle.list_unread(bee.id)

    sections = [
      "# Bee Briefing: #{bee.name} (#{bee.id})",
      "",
      "## Your Job",
      format_job_detail(job),
      "",
      "## Your Workspace",
      format_cell_detail(cell),
      "",
      "## Agent Profile",
      format_agent_section(cell),
      "",
      "## Unread Messages (#{length(waggles)})",
      format_waggles(waggles),
      "",
      "## Rules",
      "- Complete your assigned job and nothing else.",
      "- When done, send a waggle to the queen: `hive waggle send --to queen --subject \"job_complete\" --body \"<summary>\"`",
      "- If you are blocked, send: `hive waggle send --to queen --subject \"job_blocked\" --body \"<reason>\"`",
      "- Do NOT modify files outside your worktree."
    ]

    Enum.join(sections, "\n")
  end

  defp fetch_job_for_bee(%{job_id: nil}), do: nil

  defp fetch_job_for_bee(%{job_id: job_id}) do
    Repo.get(Job, job_id)
  end

  defp fetch_cell_for_bee(bee) do
    from(c in Cell,
      where: c.bee_id == ^bee.id and c.status == "active",
      limit: 1
    )
    |> Repo.one()
  end

  defp format_job_detail(nil), do: "No job assigned."

  defp format_job_detail(job) do
    lines = [
      "**#{job.title}** (#{job.id})",
      "Status: #{job.status}"
    ]

    lines =
      if job.description,
        do: lines ++ ["", job.description],
        else: lines

    Enum.join(lines, "\n")
  end

  defp format_cell_detail(nil), do: "No cell assigned."

  defp format_cell_detail(cell) do
    [
      "Path: `#{cell.worktree_path}`",
      "Branch: `#{cell.branch}`"
    ]
    |> Enum.join("\n")
  end

  # -- Private: Agent Profile ------------------------------------------------

  defp format_agent_section(nil), do: "No workspace -- cannot check agents."

  defp format_agent_section(cell) do
    comb_path = get_comb_path(cell.comb_id)

    case comb_path do
      nil ->
        "No comb path available."

      path ->
        agents = Hive.AgentProfile.list_agents(path)

        case agents do
          [] -> "No agent profiles configured for this comb."
          list -> Enum.map(list, fn a -> "- #{a}" end) |> Enum.join("\n")
        end
    end
  end

  defp get_comb_path(nil), do: nil

  defp get_comb_path(comb_id) do
    case Repo.get(Hive.Schema.Comb, comb_id) do
      nil -> nil
      comb -> comb.path
    end
  end

  # -- Private: Handoff ------------------------------------------------------

  defp build_handoff_section(bee_id) do
    case Hive.Handoff.detect_handoff(bee_id) do
      {:ok, waggle} ->
        case Hive.Handoff.resume(bee_id, waggle.id) do
          {:ok, briefing} ->
            "\n\n---\n\n" <> briefing

          {:error, _} ->
            ""
        end

      {:error, :no_handoff} ->
        ""
    end
  end
end
