defmodule GiTF.Dashboard.MissionDetailLive do
  @moduledoc "Mission detail page with phase stepper, ops, and contextual actions."

  use Phoenix.LiveView

  import GiTF.Dashboard.Helpers

  @refresh_interval :timer.seconds(5)

  @phases [
    "pending",
    "research",
    "planning",
    "approval",
    "implementation",
    "verification",
    "audit",
    "reporting",
    "sync",
    "completed"
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GiTF.PubSub, "link:major")
      Phoenix.PubSub.subscribe(GiTF.PubSub, "section:monitor")
      Process.send_after(self(), :refresh, @refresh_interval)
    end

    case GiTF.Missions.get(id) do
      {:ok, mission} ->
        ops = GiTF.Ops.list(mission_id: id)

        {:ok,
         socket
         |> assign(:page_title, Map.get(mission, :name, "Mission"))
         |> assign(:current_path, "/dashboard/missions")
         |> assign(:mission, mission)
         |> assign(:ops, ops)
         |> assign(:selected_phase, nil)
         |> assign(:artifact, nil)
         |> assign(:report, nil)
         |> assign(:report_loading, false)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Mission not found.")
         |> push_navigate(to: "/dashboard/missions")}
    end
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, reload(socket)}
  end

  def handle_info({:waggle_received, _}, socket), do: {:noreply, reload(socket)}

  def handle_info({ref, {:report, result}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, report} ->
        formatted = GiTF.Report.format(report)
        {:noreply, assign(socket, report: formatted, report_loading: false)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:report_loading, false)
         |> put_flash(:error, "Report failed: #{inspect(reason)}")}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("start", _params, socket) do
    case GiTF.Major.Orchestrator.start_quest(socket.assigns.mission.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Mission started.")
         |> reload()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start: #{inspect(reason)}")}
    end
  end

  def handle_event("kill", _params, socket) do
    case GiTF.Missions.kill(socket.assigns.mission.id) do
      :ok ->
        {:noreply, socket |> put_flash(:info, "Mission killed.") |> reload()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to kill: #{inspect(reason)}")}
    end
  end

  def handle_event("generate_report", _params, socket) do
    mission_id = socket.assigns.mission.id

    Task.async(fn ->
      {:report, GiTF.Report.generate(mission_id)}
    end)

    {:noreply, assign(socket, :report_loading, true)}
  end

  def handle_event("select_phase", %{"phase" => phase}, socket) do
    artifact = GiTF.Missions.get_artifact(socket.assigns.mission.id, phase)
    {:noreply, assign(socket, selected_phase: phase, artifact: artifact)}
  end

  def handle_event("reset_op", %{"id" => op_id}, socket) do
    case GiTF.Ops.reset(op_id, nil) do
      {:ok, _} -> {:noreply, reload(socket)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, "Reset failed: #{inspect(reason)}")}
    end
  end

  def handle_event("toggle_op", %{"id" => op_id}, socket) do
    expanded = socket.assigns[:expanded_ops] || MapSet.new()

    expanded =
      if MapSet.member?(expanded, op_id),
        do: MapSet.delete(expanded, op_id),
        else: MapSet.put(expanded, op_id)

    {:noreply, assign(socket, :expanded_ops, expanded)}
  end

  defp reload(socket) do
    id = socket.assigns.mission.id

    case GiTF.Missions.get(id) do
      {:ok, mission} ->
        ops = GiTF.Ops.list(mission_id: id)
        assign(socket, mission: mission, ops: ops)

      {:error, _} ->
        socket
    end
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> Map.put_new(:expanded_ops, MapSet.new())
      |> Map.put(:phases, @phases)

    ~H"""
    <.live_component module={GiTF.Dashboard.AppLayout} id="layout" current_path={@current_path} flash={@flash}>
      <%!-- Header --%>
      <div style="display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:1.25rem; flex-wrap:wrap; gap:0.75rem">
        <div>
          <h1 class="page-title" style="margin-bottom:0.25rem">
            {Map.get(@mission, :name, "Mission")}
          </h1>
          <div style="color:#8b949e; font-size:0.85rem; max-width:600px">
            {Map.get(@mission, :goal, "")}
          </div>
          <div style="margin-top:0.5rem; display:flex; gap:0.5rem; align-items:center">
            <span class={"badge #{status_badge(Map.get(@mission, :status, "unknown"))}"}>
              {Map.get(@mission, :status, "unknown")}
            </span>
            <span class={"badge #{phase_badge(Map.get(@mission, :current_phase, "pending"))}"}>
              {Map.get(@mission, :current_phase, "pending")}
            </span>
            <span style="font-family:monospace; font-size:0.75rem; color:#8b949e">
              {short_id(@mission.id)}
            </span>
          </div>
        </div>
        <div style="display:flex; gap:0.5rem; flex-wrap:wrap">
          <%= case Map.get(@mission, :status, "pending") do %>
            <% "pending" -> %>
              <button phx-click="start" class="btn btn-green">Start Mission</button>
            <% "active" -> %>
              <%= if Map.get(@mission, :current_phase) == "planning" do %>
                <a href={"/dashboard/missions/#{@mission.id}/plan"} class="btn btn-purple">View Plans</a>
              <% end %>
              <button phx-click="kill" class="btn btn-red" data-confirm="Kill this mission?">Kill</button>
            <% "completed" -> %>
              <button phx-click="generate_report" class="btn btn-blue" disabled={@report_loading}>
                <%= if @report_loading do %>
                  <span class="loading-spinner" style="width:14px;height:14px;border-width:2px"></span>
                  Generating...
                <% else %>
                  Generate Report
                <% end %>
              </button>
            <% _ -> %>
          <% end %>
          <%= if Map.get(@mission, :status) == "failed" || Enum.any?(@ops, &(Map.get(&1, :status) == "failed")) do %>
            <a href={"/dashboard/missions/#{@mission.id}/diagnostics"} class="btn btn-red">Diagnose</a>
          <% end %>
          <a href="/dashboard/missions" class="btn btn-grey">Back</a>
        </div>
      </div>

      <%!-- Phase Stepper --%>
      <div class="panel">
        <div class="panel-title">Phase Pipeline</div>
        <div class="stepper">
          <%= for {phase, idx} <- Enum.with_index(@phases) do %>
            <%= if idx > 0 do %>
              <div class={"step-line #{if phase_done?(@mission, Enum.at(@phases, idx - 1)), do: "step-line-done"}"}></div>
            <% end %>
            <div
              class={"step #{phase_step_class(@mission, phase)}"}
              phx-click="select_phase"
              phx-value-phase={phase}
            >
              <div class="step-circle">
                <%= if phase_done?(@mission, phase) do %>
                  ✓
                <% else %>
                  {idx + 1}
                <% end %>
              </div>
              <div class="step-label">{phase}</div>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Phase Artifact Viewer --%>
      <%= if @selected_phase do %>
        <div class="panel">
          <div class="panel-title">Phase: {@selected_phase}</div>
          <%= if @artifact do %>
            <div class="pre-block">{inspect(@artifact, pretty: true, limit: :infinity)}</div>
          <% else %>
            <div class="empty">No artifact stored for this phase.</div>
          <% end %>
        </div>
      <% end %>

      <%!-- Report --%>
      <%= if @report do %>
        <div class="panel">
          <div class="panel-title">Report</div>
          <div class="pre-block">{@report}</div>
        </div>
      <% end %>

      <%!-- Ops Table --%>
      <div class="panel">
        <div class="panel-title">Ops ({length(@ops)})</div>
        <%= if @ops == [] do %>
          <div class="empty">No ops created yet.</div>
        <% else %>
          <table>
            <thead>
              <tr>
                <th></th>
                <th>ID</th>
                <th>Title</th>
                <th>Status</th>
                <th>Audit</th>
                <th>Ghost</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for op <- @ops do %>
                <tr class="detail-toggle" phx-click="toggle_op" phx-value-id={op.id}>
                  <td style="width:1.5rem">{if MapSet.member?(@expanded_ops, op.id), do: "v", else: ">"}</td>
                  <td>
                    <a href={"/dashboard/ops/#{op.id}"} style="font-family:monospace; font-size:0.8rem">
                      {short_id(op.id)}
                    </a>
                  </td>
                  <td>{Map.get(op, :title, "-")}</td>
                  <td><span class={"badge #{status_badge(Map.get(op, :status, "unknown"))}"}>{Map.get(op, :status, "unknown")}</span></td>
                  <td>
                    <%= if Map.get(op, :verification_status) do %>
                      <span class={"badge #{verification_badge(op.verification_status)}"}>{op.verification_status}</span>
                    <% else %>
                      <span class="badge badge-grey">-</span>
                    <% end %>
                  </td>
                  <td style="font-family:monospace; font-size:0.8rem">{short_id(Map.get(op, :ghost_id))}</td>
                  <td>
                    <%= if Map.get(op, :status) == "failed" do %>
                      <button phx-click="reset_op" phx-value-id={op.id} class="btn btn-grey" style="padding:0.2rem 0.5rem; font-size:0.75rem">
                        Reset
                      </button>
                    <% end %>
                  </td>
                </tr>
                <%= if MapSet.member?(@expanded_ops, op.id) do %>
                  <tr>
                    <td colspan="7" style="padding:0">
                      <div class="detail-content">
                        <dl class="metadata-grid">
                          <dt>Type</dt><dd>{Map.get(op, :type, "-")}</dd>
                          <dt>Complexity</dt><dd>{Map.get(op, :complexity, "-")}</dd>
                          <dt>Risk</dt><dd>{Map.get(op, :risk_level, "-")}</dd>
                          <dt>Retries</dt><dd>{Map.get(op, :retry_count, 0)}</dd>
                        </dl>
                        <%= if Map.get(op, :description) do %>
                          <div style="margin-top:0.75rem; color:#8b949e; font-size:0.85rem">{op.description}</div>
                        <% end %>
                      </div>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>
    </.live_component>
    """
  end

  defp phase_done?(mission, phase) do
    current = Map.get(mission, :current_phase, "pending")
    current_idx = Enum.find_index(@phases, &(&1 == current)) || 0
    phase_idx = Enum.find_index(@phases, &(&1 == phase)) || 0
    phase_idx < current_idx
  end

  defp phase_step_class(mission, phase) do
    current = Map.get(mission, :current_phase, "pending")

    cond do
      phase == current -> "step-active"
      phase_done?(mission, phase) -> "step-done"
      true -> "step-future"
    end
  end
end
