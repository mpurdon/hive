defmodule Hive.Web.Live.Dashboard do
  use Phoenix.LiveView

  alias Hive.Store
  alias Hive.PubSubBridge

  @refresh_interval 3_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSubBridge.subscribe()
      Process.send_after(self(), :refresh, @refresh_interval)
    end

    socket =
      socket
      |> assign(:page_title, "Factory Floor")
      |> assign_stats()
      |> assign(:events, [])
      |> assign(:node, Node.self())
      |> assign(:cluster_size, length(Node.list()) + 1)
      |> assign(:emergency_stop_triggered, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("emergency_stop", _params, socket) do
    active_bees = Store.filter(:bees, fn b -> b.status == "working" end)

    Enum.each(active_bees, fn bee ->
      Hive.Bees.stop(bee.id)
    end)

    Hive.Telemetry.emit([:hive, :alert, :raised], %{}, %{
      type: :emergency_stop,
      message: "Emergency Stop triggered by operator"
    })

    {:noreply, assign(socket, :emergency_stop_triggered, true)}
  end

  def handle_event("reset_stop", _params, socket) do
    {:noreply, assign(socket, :emergency_stop_triggered, false)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, assign_stats(socket)}
  end

  def handle_info({:hive_event, payload}, socket) do
    events = [payload | socket.assigns.events] |> Enum.take(50)

    socket =
      socket
      |> assign(:events, events)
      |> assign_stats()
      |> assign(:cluster_size, length(Node.list()) + 1)

    {:noreply, socket}
  end

  defp assign_stats(socket) do
    stats = Hive.Observability.Metrics.collect_metrics()
    quests = Store.all(:quests)
    jobs = Store.all(:jobs)
    bees = Store.all(:bees)

    socket
    |> assign(:stats, stats)
    |> assign(:quests, quests)
    |> assign(:jobs, jobs)
    |> assign(:bees, bees)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen p-6">
      <!-- Header -->
      <header class="mb-8 flex justify-between items-center border-b border-gray-700 pb-4">
        <div>
          <h1 class="text-3xl font-bold text-yellow-500">Hive Control Plane</h1>
          <p class="text-sm text-gray-400">Node: <%= @node %> | Cluster Size: <%= @cluster_size %></p>
        </div>

        <div>
          <%= if @emergency_stop_triggered do %>
            <button phx-click="reset_stop" class="bg-green-600 hover:bg-green-700 text-white font-bold py-2 px-4 rounded animate-pulse">
              SYSTEM HALTED - RESET
            </button>
          <% else %>
            <button phx-click="emergency_stop" data-confirm="Are you sure? This kills all active bees." class="bg-red-600 hover:bg-red-700 text-white font-bold py-2 px-4 rounded shadow-lg border-2 border-red-800">
              EMERGENCY STOP
            </button>
          <% end %>
        </div>
      </header>

      <!-- KPI Grid -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <div class="bg-gray-800 p-4 rounded-lg shadow border border-gray-700">
          <h3 class="text-gray-400 text-sm uppercase">Active Bees</h3>
          <p class="text-4xl font-mono text-blue-400"><%= @stats.bees.active %></p>
        </div>
        <div class="bg-gray-800 p-4 rounded-lg shadow border border-gray-700">
          <h3 class="text-gray-400 text-sm uppercase">Jobs</h3>
          <p class="text-4xl font-mono text-yellow-400"><%= @stats.jobs.pending + @stats.jobs.running %></p>
          <p class="text-xs text-gray-500 mt-1">
            <%= @stats.jobs.pending %> pending · <%= @stats.jobs.running %> running · <%= @stats.jobs.done %> done
          </p>
        </div>
        <div class="bg-gray-800 p-4 rounded-lg shadow border border-gray-700">
          <h3 class="text-gray-400 text-sm uppercase">Quests</h3>
          <p class="text-4xl font-mono text-green-400"><%= @stats.quests.total %></p>
          <p class="text-xs text-gray-500 mt-1">
            <%= @stats.quests.active %> active · <%= @stats.quests.completed %> completed
          </p>
        </div>
        <div class="bg-gray-800 p-4 rounded-lg shadow border border-gray-700">
          <h3 class="text-gray-400 text-sm uppercase">Burn Rate (USD)</h3>
          <p class="text-4xl font-mono text-red-400">$<%= (@stats.costs.total / 1) |> Float.round(2) %></p>
        </div>
      </div>

      <!-- Main Content Area -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">

        <!-- Live Feed -->
        <div class="lg:col-span-2 bg-gray-800 rounded-lg shadow border border-gray-700 overflow-hidden">
          <div class="bg-gray-700 px-4 py-2 border-b border-gray-600">
            <h3 class="font-bold">Real-time Feed</h3>
          </div>
          <div class="p-4 h-96 overflow-y-auto font-mono text-xs">
            <%= for event <- @events do %>
              <div class="mb-2 pb-2 border-b border-gray-700 last:border-0">
                <span class="text-gray-500 mr-2">[<%= Calendar.strftime(event.timestamp, "%H:%M:%S") %>]</span>
                <span class="text-blue-300 font-bold"><%= event.event %></span>
                <span class="text-gray-400 ml-2">Node: <%= Map.get(event.metadata, :node, "local") %></span>
                <div class="pl-4 text-gray-300 mt-1">
                  <%= inspect(Map.drop(event.metadata, [:node])) %>
                </div>
              </div>
            <% end %>
            <%= if Enum.empty?(@events) do %>
              <p class="text-gray-500 italic">Waiting for events...</p>
            <% end %>
          </div>
        </div>

        <!-- Sidebar -->
        <div class="space-y-6">
          <!-- Quests -->
          <div class="bg-gray-800 rounded-lg shadow border border-gray-700">
            <div class="bg-gray-700 px-4 py-2 border-b border-gray-600">
              <h3 class="font-bold">Quests</h3>
            </div>
            <div class="p-4 space-y-2 max-h-48 overflow-y-auto">
              <%= if Enum.empty?(@quests) do %>
                <p class="text-gray-500 text-sm italic">No quests yet</p>
              <% end %>
              <%= for q <- @quests do %>
                <div class="flex items-center justify-between text-sm">
                  <span class="truncate mr-2" title={q.goal}><%= q.name %></span>
                  <span class={"px-2 py-0.5 rounded text-xs font-mono #{quest_badge(q.status)}"}><%= q.status %></span>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Active Jobs -->
          <div class="bg-gray-800 rounded-lg shadow border border-gray-700">
            <div class="bg-gray-700 px-4 py-2 border-b border-gray-600">
              <h3 class="font-bold">Jobs</h3>
            </div>
            <div class="p-4 space-y-2 max-h-64 overflow-y-auto">
              <%= if Enum.empty?(@jobs) do %>
                <p class="text-gray-500 text-sm italic">No jobs yet</p>
              <% end %>
              <%= for j <- Enum.sort_by(@jobs, & &1.status) do %>
                <div class="flex items-center justify-between text-sm">
                  <span class="truncate mr-2" title={j.title}><%= String.slice(j.title, 0, 35) %></span>
                  <span class={"px-2 py-0.5 rounded text-xs font-mono #{job_badge(j.status)}"}><%= j.status %></span>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Workers -->
          <div class="bg-gray-800 rounded-lg shadow border border-gray-700">
            <div class="bg-gray-700 px-4 py-2 border-b border-gray-600">
              <h3 class="font-bold">Workers</h3>
            </div>
            <div class="p-4 text-sm">
              <div class="flex justify-between mb-1">
                <span class="text-gray-400">Active</span>
                <span class="text-blue-400 font-mono"><%= @stats.bees.active %></span>
              </div>
              <div class="flex justify-between mb-1">
                <span class="text-gray-400">Idle</span>
                <span class="text-gray-300 font-mono"><%= @stats.bees.idle %></span>
              </div>
              <div class="flex justify-between mb-1">
                <span class="text-gray-400">Stopped</span>
                <span class="text-gray-500 font-mono"><%= @stats.bees.stopped %></span>
              </div>
              <div class="flex justify-between pt-2 border-t border-gray-700">
                <span class="text-gray-400">Total</span>
                <span class="text-white font-mono"><%= @stats.bees.total %></span>
              </div>
              <div class="mt-3 pt-2 border-t border-gray-700">
                <span class="text-gray-500 text-xs">Memory: <%= Float.round(@stats.system.memory_mb, 1) %> MB</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp quest_badge("pending"), do: "bg-gray-600 text-gray-300"
  defp quest_badge("active"), do: "bg-blue-900 text-blue-300"
  defp quest_badge("completed"), do: "bg-green-900 text-green-300"
  defp quest_badge("failed"), do: "bg-red-900 text-red-300"
  defp quest_badge(_), do: "bg-gray-600 text-gray-300"

  defp job_badge("pending"), do: "bg-gray-600 text-gray-300"
  defp job_badge("assigned"), do: "bg-yellow-900 text-yellow-300"
  defp job_badge("running"), do: "bg-blue-900 text-blue-300"
  defp job_badge("done"), do: "bg-green-900 text-green-300"
  defp job_badge("failed"), do: "bg-red-900 text-red-300"
  defp job_badge(_), do: "bg-gray-600 text-gray-300"
end
