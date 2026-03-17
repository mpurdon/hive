defmodule GiTF.Dashboard.OverviewLive do
  @moduledoc """
  Main dashboard overview showing key metrics at a glance.

  Displays active ghost count, mission count, total cost, and recent
  link_msg messages. Subscribes to PubSub for live updates when new
  links arrive.
  """

  use Phoenix.LiveView

  import GiTF.Dashboard.Helpers

  @refresh_interval :timer.seconds(5)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to all link_msg traffic for live updates
      Phoenix.PubSub.subscribe(GiTF.PubSub, "link:major")
      Process.send_after(self(), :refresh, @refresh_interval)
    end

    {:ok, assign_data(socket)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, assign_data(socket)}
  end

  def handle_info({:waggle_received, _waggle}, socket) do
    {:noreply, assign_data(socket)}
  end

  @impl true
  def handle_event("quick_run", %{"task" => %{"goal" => goal}}, socket) do
    goal = String.trim(goal)

    if goal == "" do
      {:noreply, put_flash(socket, :error, "Goal cannot be empty")}
    else
      sectors = GiTF.Sector.list()
      sector_id = case sectors do
        [s] -> s.id
        _ -> nil
      end

      attrs = %{goal: goal}
      attrs = if sector_id, do: Map.put(attrs, :sector_id, sector_id), else: attrs

      case GiTF.Missions.create(attrs) do
        {:ok, mission} ->
          case GiTF.Major.Orchestrator.start_quest(mission.id, force_fast_path: true) do
            {:ok, _phase} ->
              {:noreply,
               socket
               |> put_flash(:info, "Task started — ghost is working on it.")
               |> push_navigate(to: "/dashboard/missions/#{mission.id}")}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Failed to start: #{inspect(reason)}")}
          end

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
      end
    end
  end

  defp assign_data(socket) do
    ghosts = GiTF.Ghosts.list()
    missions = GiTF.Missions.list()
    cost_summary = GiTF.Costs.summary()
    recent_waggles = GiTF.Link.list(limit: 5)

    active_ghosts = Enum.count(ghosts, &(Map.get(&1, :status) in ["working", "starting"]))
    active_quests = Enum.count(missions, &(Map.get(&1, :status) == "active"))
    
    # Context monitoring
    bees_with_context = Enum.filter(ghosts, &Map.has_key?(&1, :context_percentage))
    avg_context = if bees_with_context != [] do
      Enum.sum(Enum.map(bees_with_context, &(&1.context_percentage || 0.0))) / length(bees_with_context)
    else
      0.0
    end
    high_context_bees = Enum.count(bees_with_context, &((&1.context_percentage || 0) > 40))
    
    # Audit stats
    ops = GiTF.Ops.list()
    verified_jobs = Enum.count(ops, &(Map.get(&1, :verification_status) == "passed"))
    failed_verification = Enum.count(ops, &(Map.get(&1, :verification_status) == "failed"))
    pending_verification = Enum.count(ops, &(Map.get(&1, :verification_status) == "pending" and Map.get(&1, :status) == "done"))

    # Quest phases
    research_quests = Enum.count(missions, &(Map.get(&1, :current_phase) == "research"))
    planning_quests = Enum.count(missions, &(Map.get(&1, :current_phase) == "planning"))
    implementation_quests = Enum.count(missions, &(Map.get(&1, :current_phase) == "implementation"))

    # Approvals & sectors
    pending_approvals = try do
      length(GiTF.Override.pending_approvals())
    rescue
      _ -> 0
    end

    sector_count = try do
      length(GiTF.Sector.list())
    rescue
      _ -> 0
    end

    socket
    |> assign(:page_title, "Overview")
    |> assign(:current_path, "/")
    |> assign(:ghost_count, length(ghosts))
    |> assign(:active_ghosts, active_ghosts)
    |> assign(:quest_count, length(missions))
    |> assign(:active_quests, active_quests)
    |> assign(:total_cost, cost_summary.total_cost)
    |> assign(:total_input_tokens, cost_summary.total_input_tokens)
    |> assign(:total_output_tokens, cost_summary.total_output_tokens)
    |> assign(:recent_waggles, recent_waggles)
    |> assign(:active_processes, safe_active_count())
    |> assign(:avg_context, avg_context)
    |> assign(:high_context_bees, high_context_bees)
    |> assign(:verified_jobs, verified_jobs)
    |> assign(:failed_verification, failed_verification)
    |> assign(:pending_verification, pending_verification)
    |> assign(:research_quests, research_quests)
    |> assign(:planning_quests, planning_quests)
    |> assign(:implementation_quests, implementation_quests)
    |> assign(:pending_approvals, pending_approvals)
    |> assign(:sector_count, sector_count)
  end

  defp safe_active_count do
    GiTF.SectorSupervisor.active_count()
  rescue
    _ -> 0
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={GiTF.Dashboard.AppLayout} id="layout" current_path={@current_path} flash={@flash}>
      <h1 class="page-title">Dashboard Overview</h1>

      <div class="cards">
        <div class="card">
          <div class="card-label">Total Ghosts</div>
          <div class="card-value blue">{@ghost_count}</div>
          <div class="card-label" style="margin-top:0.25rem">{@active_ghosts} active</div>
        </div>
        <div class="card">
          <div class="card-label">Missions</div>
          <div class="card-value yellow">{@quest_count}</div>
          <div class="card-label" style="margin-top:0.25rem">{@active_quests} active</div>
        </div>
        <div class="card">
          <div class="card-label">Total Cost</div>
          <div class="card-value green">{format_cost(@total_cost)}</div>
          <div class="card-label" style="margin-top:0.25rem">{format_tokens(@total_input_tokens + @total_output_tokens)} tokens</div>
        </div>
        <div class="card">
          <div class="card-label">Live Processes</div>
          <div class="card-value">{@active_processes}</div>
          <div class="card-label" style="margin-top:0.25rem">under SectorSupervisor</div>
        </div>
      </div>

      <div class="cards">
        <div class="card">
          <div class="card-label">Context Usage</div>
          <div class={"card-value #{if @avg_context > 40, do: "orange", else: "blue"}"}>
            {Float.round(@avg_context, 1)}%
          </div>
          <div class="card-label" style="margin-top:0.25rem">
            {if @high_context_bees > 0, do: "#{@high_context_bees} ghosts >40%", else: "all ghosts healthy"}
          </div>
        </div>
        <div class="card">
          <div class="card-label">Audit</div>
          <div class={"card-value #{if @failed_verification > 0, do: "red", else: "green"}"}>
            {@verified_jobs}
          </div>
          <div class="card-label" style="margin-top:0.25rem">
            {if @failed_verification > 0, do: "#{@failed_verification} failed", else: "#{@pending_verification} pending"}
          </div>
        </div>
        <div class="card">
          <div class="card-label">Quest Phases</div>
          <div class="card-value purple">{@implementation_quests}</div>
          <div class="card-label" style="margin-top:0.25rem">
            R:{@research_quests} P:{@planning_quests} I:{@implementation_quests}
          </div>
        </div>
      </div>

      <div class="cards">
        <div class="card">
          <div class="card-label">Pending Approvals</div>
          <div class={"card-value #{if @pending_approvals > 0, do: "yellow"}"}>
            {@pending_approvals}
          </div>
          <div class="card-label" style="margin-top:0.25rem">
            <a href="/dashboard/approvals" style="color:#58a6ff; font-size:0.8rem">View queue</a>
          </div>
        </div>
        <div class="card">
          <div class="card-label">Sectors</div>
          <div class="card-value">{@sector_count}</div>
          <div class="card-label" style="margin-top:0.25rem">
            <a href="/dashboard/sectors" style="color:#58a6ff; font-size:0.8rem">Manage</a>
          </div>
        </div>
      </div>

      <!-- Quick Run -->
      <div class="panel" style="margin-bottom:1.5rem">
        <div class="panel-title">Quick Run</div>
        <p style="color:#8b949e; font-size:0.8rem; margin-bottom:0.75rem">
          Run a focused task (bug fix, single feature) — skips the full pipeline, spawns one ghost immediately.
        </p>
        <form phx-submit="quick_run" style="display:flex; gap:0.5rem; align-items:flex-end">
          <input
            type="text"
            name="task[goal]"
            class="form-input"
            placeholder="e.g. fix the login timeout bug"
            style="flex:1"
          />
          <button type="submit" class="btn btn-green" style="white-space:nowrap">Run</button>
        </form>
      </div>

      <div style="display:flex; gap:0.5rem; margin-bottom:1.5rem">
        <a href="/dashboard/missions/new" class="btn btn-blue">New Mission (Full Pipeline)</a>
        <a href="/dashboard/autonomy" class="btn btn-grey">Self-Heal</a>
      </div>

      <div class="panel">
        <div class="panel-title">Recent Messages</div>
        <%= if @recent_waggles == [] do %>
          <div class="empty">No messages yet.</div>
        <% else %>
          <%= for link_msg <- @recent_waggles do %>
            <div class={"link_msg-item #{unless link_msg.read, do: "link_msg-unread"}"}>
              <div class="link_msg-subject">{link_msg.subject || "(no subject)"}</div>
              <div class="link_msg-meta">
                {link_msg.from} &rarr; {link_msg.to}
                &middot;
                {format_timestamp(link_msg.inserted_at)}
                &middot;
                <span class={"badge #{if link_msg.read, do: "badge-grey", else: "badge-blue"}"}>
                  {if link_msg.read, do: "read", else: "unread"}
                </span>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </.live_component>
    """
  end

end
