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
      |> maybe_put(:sector, params["sector"])

    case GiTF.Missions.create(attrs) do
      {:ok, mission} ->
        {:noreply,
         socket
         |> put_flash(:info, "Mission created successfully.")
         |> push_navigate(to: "/dashboard/missions/#{mission.id}")}

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
          <p style="color:#8b949e; margin-bottom:1.25rem; font-size:0.9rem">
            A mission defines a high-level goal. The Major will research, plan, and
            orchestrate ghost agents to accomplish it across multiple phases.
          </p>

          <form phx-submit="create" phx-change="validate">
            <div class="form-group">
              <label class="form-label">Goal *</label>
              <textarea
                name="mission[goal]"
                class="form-textarea"
                placeholder="Describe what you want to accomplish..."
                style="min-height:140px"
                required
              >{@form["goal"]}</textarea>
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
              <label class="form-label">Sector (optional)</label>
              <select name="mission[sector]" class="form-select">
                <option value="">— Default sector —</option>
                <%= for sector <- @sectors do %>
                  <option value={sector.name} selected={@form["sector"] == sector.name}>
                    {sector.name} — {Map.get(sector, :path, "")}
                  </option>
                <% end %>
              </select>
            </div>

            <div class="action-bar">
              <a href="/dashboard/missions" class="btn btn-grey">Cancel</a>
              <button type="submit" class="btn btn-green" disabled={String.trim(@form["goal"] || "") == ""}>
                Create Mission
              </button>
            </div>
          </form>
        </div>
      </div>
    </.live_component>
    """
  end
end
