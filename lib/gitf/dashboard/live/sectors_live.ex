defmodule GiTF.Dashboard.SectorsLive do
  @moduledoc "Sector management page."

  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Sectors")
     |> assign(:current_path, "/sectors")
     |> assign(:sectors, load_sectors())
     |> assign(:current_sector, load_current())
     |> assign(:new_path, "")
     |> assign(:new_name, "")}
  end

  @impl true
  def handle_event("update_form", %{"path" => path, "name" => name}, socket) do
    {:noreply, assign(socket, new_path: path, new_name: name)}
  end

  def handle_event("add", %{"path" => path, "name" => name}, socket) do
    path = String.trim(path)
    name = String.trim(name)

    if path == "" do
      {:noreply, put_flash(socket, :error, "Path is required.")}
    else
      opts = if name != "", do: [name: name], else: []

      case GiTF.Sector.add(path, opts) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(sectors: load_sectors(), new_path: "", new_name: "")
           |> put_flash(:info, "Sector added.")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
      end
    end
  end

  def handle_event("set_current", %{"id" => id}, socket) do
    case GiTF.Sector.set_current(id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(sectors: load_sectors(), current_sector: load_current())
         |> put_flash(:info, "Current sector updated.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    case GiTF.Sector.remove(id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(sectors: load_sectors(), current_sector: load_current())
         |> put_flash(:info, "Sector removed.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
    end
  end

  defp load_sectors do
    try do
      GiTF.Sector.list()
    rescue
      _ -> []
    end
  end

  defp load_current do
    case GiTF.Sector.current() do
      {:ok, sector} -> sector
      _ -> nil
    end
  rescue
    _ -> nil
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={GiTF.Dashboard.AppLayout} id="layout" current_path={@current_path} flash={@flash}>
      <h1 class="page-title">Sectors</h1>

      <%!-- Add form --%>
      <div class="panel" style="margin-bottom:1.5rem">
        <div class="panel-title">Add Sector</div>
        <form phx-submit="add" phx-change="update_form" style="display:flex; gap:0.75rem; align-items:flex-end; flex-wrap:wrap">
          <div class="form-group" style="flex:2; margin-bottom:0; min-width:200px">
            <label class="form-label">Path / URL</label>
            <input type="text" name="path" class="form-input" placeholder="/path/to/repo or git URL" value={@new_path} required />
          </div>
          <div class="form-group" style="flex:1; margin-bottom:0; min-width:120px">
            <label class="form-label">Name (optional)</label>
            <input type="text" name="name" class="form-input" placeholder="sector name" value={@new_name} />
          </div>
          <button type="submit" class="btn btn-green" style="margin-bottom:0">Add</button>
        </form>
      </div>

      <%!-- Sectors table --%>
      <div class="panel">
        <%= if @sectors == [] do %>
          <div class="empty">No sectors configured. Add one above to get started.</div>
        <% else %>
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Path</th>
                <th>Strategy</th>
                <th></th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for sector <- @sectors do %>
                <tr>
                  <td style="font-weight:500; color:#f0f6fc">
                    {Map.get(sector, :name, "-")}
                    <%= if @current_sector && Map.get(@current_sector, :name) == Map.get(sector, :name) do %>
                      <span class="badge badge-green" style="margin-left:0.5rem">current</span>
                    <% end %>
                  </td>
                  <td style="font-family:monospace; font-size:0.85rem">{Map.get(sector, :path, "-")}</td>
                  <td>{Map.get(sector, :sync_strategy, "-")}</td>
                  <td>
                    <%= unless @current_sector && Map.get(@current_sector, :name) == Map.get(sector, :name) do %>
                      <button phx-click="set_current" phx-value-id={sector.name} class="btn btn-blue" style="padding:0.2rem 0.6rem; font-size:0.75rem">
                        Set Current
                      </button>
                    <% end %>
                  </td>
                  <td>
                    <button phx-click="remove" phx-value-id={sector.name} class="btn btn-red" style="padding:0.2rem 0.6rem; font-size:0.75rem" data-confirm={"Remove sector #{sector.name}?"}>
                      Remove
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>
    </.live_component>
    """
  end
end
