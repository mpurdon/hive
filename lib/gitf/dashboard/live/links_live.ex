defmodule GiTF.Dashboard.LinksLive do
  @moduledoc """
  Link message viewer.

  Lists recent inter-agent messages in reverse chronological order.
  Auto-updates when new links arrive via PubSub subscription, so the
  operator sees real-time message flow without refreshing.
  """

  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GiTF.PubSub, "link:major")
    end

    links = GiTF.Link.list(limit: 50)

    {:ok,
     socket
     |> assign(:page_title, "Links")
     |> assign(:current_path, "/links")
     |> assign(:links, links)}
  end

  @impl true
  def handle_info({:waggle_received, _waggle}, socket) do
    links = GiTF.Link.list(limit: 50)
    {:noreply, assign(socket, :links, links)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    links = GiTF.Link.list(limit: 50)
    {:noreply, assign(socket, :links, links)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={GiTF.Dashboard.AppLayout} id="layout" current_path={@current_path} flash={@flash}>
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1.25rem">
        <h1 class="page-title" style="margin-bottom:0">Link Messages</h1>
        <button phx-click="refresh" style="background:#1f6feb33; color:#58a6ff; border:1px solid #1f6feb55; padding:0.4rem 1rem; border-radius:6px; cursor:pointer; font-size:0.85rem">
          Refresh
        </button>
      </div>

      <div class="panel">
        <%= if @links == [] do %>
          <div class="empty">No link_msg messages found. Messages appear here as ghosts and the Major communicate.</div>
        <% else %>
          <table>
            <thead>
              <tr>
                <th></th>
                <th>From</th>
                <th>To</th>
                <th>Subject</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              <%= for link_msg <- @links do %>
                <tr class={unless link_msg.read, do: "link_msg-unread"}>
                  <td style="width:1rem">
                    <span class={"badge #{if link_msg.read, do: "badge-grey", else: "badge-blue"}"} style="font-size:0.65rem">
                      {if link_msg.read, do: "R", else: "N"}
                    </span>
                  </td>
                  <td style="font-family:monospace; font-size:0.8rem">{link_msg.from}</td>
                  <td style="font-family:monospace; font-size:0.8rem">{link_msg.to}</td>
                  <td class={unless link_msg.read, do: "link_msg-subject"}>{link_msg.subject || "(no subject)"}</td>
                  <td style="font-size:0.8rem; color:#8b949e">{format_timestamp(link_msg.inserted_at)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>
    </.live_component>
    """
  end

  defp format_timestamp(nil), do: "-"

  defp format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end

  defp format_timestamp(_), do: "-"
end
