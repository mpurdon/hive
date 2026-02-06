defmodule Hive.Dashboard.ProgressLive do
  @moduledoc "LiveView showing real-time bee progress from ETS."

  use Phoenix.LiveView

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Hive.PubSub, Hive.Progress.topic())
      Process.send_after(self(), :refresh, @refresh_interval)
    end

    {:ok, assign(socket, page_title: "Progress", current_path: "/progress", entries: Hive.Progress.all())}
  end

  @impl true
  def handle_info({:bee_progress, _bee_id, _data}, socket) do
    {:noreply, assign(socket, :entries, Hive.Progress.all())}
  end

  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, assign(socket, :entries, Hive.Progress.all())}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={Hive.Dashboard.AppLayout} id="layout" current_path={@current_path} flash={@flash}>
      <h1 class="page-title">Bee Progress</h1>

      <%= if @entries == [] do %>
        <div class="empty">No active bees.</div>
      <% else %>
        <table class="data-table">
          <thead>
            <tr>
              <th>Bee ID</th>
              <th>Tool</th>
              <th>File</th>
              <th>Message</th>
            </tr>
          </thead>
          <tbody>
            <%= for entry <- @entries do %>
              <tr>
                <td>{entry[:bee_id] || "-"}</td>
                <td>{entry[:tool] || "-"}</td>
                <td>{entry[:file] || "-"}</td>
                <td>{entry[:message] || "-"}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </.live_component>
    """
  end
end
