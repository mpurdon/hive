defmodule GiTF.Dashboard.MissionNewLive do
  @moduledoc "Mission creation form."

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
     |> assign(:page_title, "New Mission")
     |> assign(:current_path, "/dashboard/missions")
     |> assign(:sectors, sectors)
     |> assign(:form, %{"goal" => "", "name" => "", "sector" => ""})}
  end

  @impl true
  def handle_event("validate", %{"mission" => params}, socket) do
    {:noreply, assign(socket, :form, params)}
  end

  def handle_event("create", %{"mission" => params}, socket) do
    attrs =
      %{goal: String.trim(params["goal"])}
      |> maybe_put(:name, params["name"])
      |> maybe_put(:sector_id, params["sector"])

    quick = params["quick"] == "true"
    review = params["review_plan"] == "true"
    attrs = if review, do: Map.put(attrs, :review_plan, true), else: attrs

    case GiTF.Missions.create(attrs) do
      {:ok, mission} ->
        if quick do
          case GiTF.Major.Orchestrator.start_quest(mission.id, force_fast_path: true) do
            {:ok, _} ->
              {:noreply,
               socket
               |> put_flash(:info, "Quick task started — ghost is working.")
               |> push_navigate(to: "/dashboard/missions/#{mission.id}")}

            {:error, reason} ->
              {:noreply,
               socket
               |> put_flash(:error, "Created mission but failed to start: #{inspect(reason)}")
               |> push_navigate(to: "/dashboard/missions/#{mission.id}")}
          end
        else
          # Full pipeline: auto-start, will pause at planning if review requested
          case GiTF.Major.Orchestrator.start_quest(mission.id) do
            {:ok, _} ->
              flash = if review,
                do: "Mission started — will pause at planning for your review.",
                else: "Mission started — running full pipeline."

              {:noreply,
               socket
               |> put_flash(:info, flash)
               |> push_navigate(to: "/dashboard/missions/#{mission.id}")}

            {:error, reason} ->
              {:noreply,
               socket
               |> put_flash(:error, "Created but failed to start: #{inspect(reason)}")
               |> push_navigate(to: "/dashboard/missions/#{mission.id}")}
          end
        end

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create mission: #{inspect(reason)}")}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, String.trim(value))

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={GiTF.Dashboard.AppLayout} id="layout" current_path={@current_path} flash={@flash}>
      <div style="max-width:640px">
        <h1 class="page-title">New Mission</h1>

        <div class="panel">
          <form phx-submit="create" phx-change="validate">
            <div class="form-group">
              <label class="form-label">Goal *</label>
              <textarea
                name="mission[goal]"
                class="form-textarea"
                placeholder="Describe what you want to accomplish..."
                style="min-height:120px"
                required
              >{@form["goal"]}</textarea>
            </div>

            <!-- Mode toggle -->
            <div class="form-group" style="display:flex; gap:1.5rem; padding:0.75rem 1rem; background:#1c2128; border-radius:6px; border:1px solid #30363d">
              <label style="display:flex; align-items:center; gap:0.5rem; cursor:pointer; color:#c9d1d9; font-size:0.85rem">
                <input type="radio" name="mission[quick]" value="true" checked={@form["quick"] == "true"} style="accent-color:#3fb950" />
                <span>
                  <strong style="color:#3fb950">Quick Run</strong>
                  <span style="color:#8b949e"> — single ghost, no pipeline (bug fixes, focused tasks)</span>
                </span>
              </label>
              <label style="display:flex; align-items:center; gap:0.5rem; cursor:pointer; color:#c9d1d9; font-size:0.85rem">
                <input type="radio" name="mission[quick]" value="false" checked={@form["quick"] != "true"} style="accent-color:#58a6ff" />
                <span>
                  <strong style="color:#58a6ff">Full Pipeline</strong>
                  <span style="color:#8b949e"> — research, plan, implement, verify (greenfield projects)</span>
                </span>
              </label>
              <%= if @form["quick"] != "true" do %>
                <label style="display:flex; align-items:center; gap:0.5rem; cursor:pointer; color:#c9d1d9; font-size:0.85rem; margin-left:1.75rem">
                  <input type="checkbox" name="mission[review_plan]" value="true" checked={@form["review_plan"] == "true"} style="accent-color:#a855f7" />
                  <span>
                    <strong style="color:#a855f7">Review plan</strong>
                    <span style="color:#8b949e"> — pause at planning for manual review before implementation</span>
                  </span>
                </label>
              <% end %>
            </div>

            <div class="form-group">
              <label class="form-label">Name (optional)</label>
              <input
                type="text"
                name="mission[name]"
                class="form-input"
                placeholder="Short name for this mission"
                value={@form["name"]}
              />
            </div>

            <div class="form-group">
              <label class="form-label">Sector</label>
              <select name="mission[sector]" class="form-select">
                <option value="">— Default sector —</option>
                <%= for sector <- @sectors do %>
                  <option value={sector.id} selected={@form["sector"] == sector.id}>
                    {sector.name} — {Map.get(sector, :path, "")}
                  </option>
                <% end %>
              </select>
            </div>

            <div class="action-bar">
              <a href="/dashboard/missions" class="btn btn-grey">Cancel</a>
              <button type="submit" class="btn btn-green" disabled={String.trim(@form["goal"] || "") == ""}>
                {if @form["quick"] == "true", do: "Run Task", else: "Create Mission"}
              </button>
            </div>
          </form>
        </div>
      </div>
    </.live_component>
    """
  end
end
