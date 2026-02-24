defmodule Hive.Web.Live.Dashboard do
  use Phoenix.LiveView

  alias Hive.Store
  alias Hive.PubSubBridge

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSubBridge.subscribe()
    end

    socket =
      socket
      |> assign(:page_title, "Factory Floor")
      |> assign(:stats, Hive.Observability.Metrics.collect_metrics())
      |> assign(:events, [])
      |> assign(:node, Node.self())
      |> assign(:cluster_size, length(Node.list()) + 1)
      |> assign(:emergency_stop_triggered, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("emergency_stop", _params, socket) do
    # Trigger emergency stop logic
    # Kill all active bees immediately
    active_bees = Store.filter(:bees, fn b -> b.status == "working" end)
    
    Enum.each(active_bees, fn bee ->
      Hive.Bees.stop(bee.id)
    end)
    
    # Broadcast alert
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
  def handle_info({:hive_event, payload}, socket) do
    # Keep last 50 events
    events = [payload | socket.assigns.events] |> Enum.take(50)
    
    # Refresh stats periodically or on events
    stats = Hive.Observability.Metrics.collect_metrics()
    
    socket = 
      socket
      |> assign(:events, events)
      |> assign(:stats, stats)
      |> assign(:cluster_size, length(Node.list()) + 1)

    {:noreply, socket}
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
          <h3 class="text-gray-400 text-sm uppercase">Jobs Pending</h3>
          <p class="text-4xl font-mono text-yellow-400"><%= @stats.quests.active %></p>
        </div>
        <div class="bg-gray-800 p-4 rounded-lg shadow border border-gray-700">
          <h3 class="text-gray-400 text-sm uppercase">Quality Score</h3>
          <p class="text-4xl font-mono text-green-400"><%= (@stats.quality.average / 1) |> Float.round(1) %>%</p>
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

        <!-- System Status -->
        <div class="bg-gray-800 rounded-lg shadow border border-gray-700">
          <div class="bg-gray-700 px-4 py-2 border-b border-gray-600">
            <h3 class="font-bold">System Status</h3>
          </div>
          <div class="p-4 space-y-4">
            <div>
              <span class="block text-gray-400 text-xs uppercase">Process Count</span>
              <div class="w-full bg-gray-700 rounded-full h-2 mt-1">
                <div class="bg-blue-500 h-2 rounded-full" style={"width: min(#{@stats.system.process_count / 100}%, 100%)"}></div>
              </div>
              <span class="text-xs text-right block mt-1"><%= @stats.system.process_count %> processes</span>
            </div>

            <div>
              <span class="block text-gray-400 text-xs uppercase">Memory Usage</span>
              <div class="w-full bg-gray-700 rounded-full h-2 mt-1">
                <div class="bg-purple-500 h-2 rounded-full" style={"width: min(#{@stats.system.memory_mb / 1024 * 100}%, 100%)"}></div>
              </div>
              <span class="text-xs text-right block mt-1"><%= Float.round(@stats.system.memory_mb, 1) %> MB</span>
            </div>
            
            <div class="mt-8 pt-4 border-t border-gray-700">
               <h4 class="font-bold text-sm mb-2">Cluster Nodes</h4>
               <ul class="text-xs space-y-1">
                 <li class="flex items-center text-green-400">
                   <span class="w-2 h-2 bg-green-500 rounded-full mr-2"></span>
                   <%= @node %> (Leader)
                 </li>
                 <%= for n <- Node.list() do %>
                   <li class="flex items-center text-gray-300">
                     <span class="w-2 h-2 bg-gray-500 rounded-full mr-2"></span>
                     <%= n %> (Worker)
                   </li>
                 <% end %>
               </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
