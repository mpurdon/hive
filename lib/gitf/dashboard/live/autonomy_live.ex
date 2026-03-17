defmodule GiTF.Dashboard.AutonomyLive do
  @moduledoc "Autonomy tools: self-heal, optimize, predict issues."

  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    sectors =
      try do
        GiTF.Sector.list()
      rescue
        _ -> []
      end

    {:ok,
     socket
     |> assign(:page_title, "Autonomy")
     |> assign(:current_path, "/autonomy")
     |> assign(:sectors, sectors)
     |> assign(:selected_sector, "")
     |> assign(:heal_result, nil)
     |> assign(:optimize_result, nil)
     |> assign(:predict_result, nil)
     |> assign(:loading, nil)}
  end

  @impl true
  def handle_event("self_heal", _params, socket) do
    Task.async(fn -> {:heal, GiTF.Autonomy.self_heal()} end)
    {:noreply, assign(socket, loading: :heal)}
  end

  def handle_event("optimize", _params, socket) do
    Task.async(fn -> {:optimize, GiTF.Autonomy.optimize_resources()} end)
    {:noreply, assign(socket, loading: :optimize)}
  end

  def handle_event("select_sector", params, socket) do
    sector = params["sector"] || params["_target_value"] || ""
    {:noreply, assign(socket, :selected_sector, sector)}
  end

  def handle_event("predict", _params, socket) do
    sector = socket.assigns.selected_sector

    if sector == "" do
      {:noreply, put_flash(socket, :error, "Select a sector first.")}
    else
      Task.async(fn -> {:predict, GiTF.Autonomy.predict_issues(sector)} end)
      {:noreply, assign(socket, loading: :predict)}
    end
  end

  @impl true
  def handle_info({ref, {type, result}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    socket =
      case type do
        :heal -> assign(socket, heal_result: result, loading: nil)
        :optimize -> assign(socket, optimize_result: result, loading: nil)
        :predict -> assign(socket, predict_result: result, loading: nil)
      end

    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={GiTF.Dashboard.AppLayout} id="layout" current_path={@current_path} flash={@flash}>
      <h1 class="page-title">Autonomy</h1>

      <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(320px, 1fr)); gap:1rem">
        <%!-- Self-Heal --%>
        <div class="panel">
          <div class="panel-title">Self-Heal</div>
          <p style="color:#8b949e; font-size:0.85rem; margin-bottom:1rem">
            Detect and repair stuck processes, failed ops, and inconsistent state.
          </p>
          <button phx-click="self_heal" class="btn btn-green" disabled={@loading == :heal}>
            <%= if @loading == :heal do %>
              <span class="loading-spinner" style="width:14px;height:14px;border-width:2px"></span>
              Running...
            <% else %>
              Run Self-Heal
            <% end %>
          </button>
          <%= if @heal_result do %>
            <div style="margin-top:1rem">
              <%= if @heal_result == [] do %>
                <div style="color:#3fb950; font-size:0.85rem">All clear — no issues found.</div>
              <% else %>
                <%= for action <- List.wrap(@heal_result) do %>
                  <div style="padding:0.35rem 0; font-size:0.85rem; border-bottom:1px solid #21262d">
                    {inspect(action)}
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- Optimize --%>
        <div class="panel">
          <div class="panel-title">Optimize Resources</div>
          <p style="color:#8b949e; font-size:0.85rem; margin-bottom:1rem">
            Analyze resource usage and suggest optimizations for ghost allocation and model selection.
          </p>
          <button phx-click="optimize" class="btn btn-blue" disabled={@loading == :optimize}>
            <%= if @loading == :optimize do %>
              <span class="loading-spinner" style="width:14px;height:14px;border-width:2px"></span>
              Analyzing...
            <% else %>
              Optimize
            <% end %>
          </button>
          <%= if @optimize_result do %>
            <div style="margin-top:1rem">
              <%= if @optimize_result == [] do %>
                <div style="color:#3fb950; font-size:0.85rem">No optimizations suggested.</div>
              <% else %>
                <%= for rec <- List.wrap(@optimize_result) do %>
                  <div style="padding:0.5rem; margin-bottom:0.5rem; background:#0d1117; border-radius:6px; font-size:0.85rem; border:1px solid #30363d">
                    {inspect(rec)}
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- Predict Issues --%>
        <div class="panel">
          <div class="panel-title">Predict Issues</div>
          <p style="color:#8b949e; font-size:0.85rem; margin-bottom:1rem">
            Analyze a sector for potential problems before they happen.
          </p>
          <form phx-change="select_sector" phx-submit="predict" style="display:flex; gap:0.5rem; align-items:flex-end">
            <div class="form-group" style="flex:1; margin-bottom:0">
              <select class="form-select" name="sector">
                <option value="">Select sector...</option>
                <%= for sector <- @sectors do %>
                  <option value={sector.name} selected={@selected_sector == sector.name}>{sector.name}</option>
                <% end %>
              </select>
            </div>
            <button type="submit" class="btn btn-purple" disabled={@loading == :predict || @selected_sector == ""}>
              <%= if @loading == :predict do %>
                <span class="loading-spinner" style="width:14px;height:14px;border-width:2px"></span>
              <% else %>
                Predict
              <% end %>
            </button>
          </form>
          <%= if @predict_result do %>
            <div style="margin-top:1rem">
              <%= if @predict_result == [] do %>
                <div style="color:#3fb950; font-size:0.85rem">No issues predicted.</div>
              <% else %>
                <%= for pred <- List.wrap(@predict_result) do %>
                  <div style="padding:0.5rem; margin-bottom:0.5rem; background:#0d1117; border-radius:6px; font-size:0.85rem; border:1px solid #30363d">
                    {inspect(pred)}
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </.live_component>
    """
  end
end
