defmodule HexaPlannerWeb.TwinLive do
  use Phoenix.LiveView
  alias Phoenix.PubSub
  alias HexaPlanner.Simulation.Engine

  @moduledoc """
  High-fidelity Digital Twin Dashboard.
  Adheres to the official Phoenix LiveView v1.1 best practices:
  - Streams for flicker-free data updates
  - AsyncResult for managed loading states
  - push_event for high-frequency WebGL rendering
  - Real-time Progress UX for data ingestion
  """

  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(HexaPlanner.PubSub, "simulation:switzerland")
    end

    # Get initial state from Engine
    engine_state = Engine.get_status()

    socket = 
      socket
      |> assign(:status, engine_state.status)
      |> assign(:loading_msg, engine_state.message)
      |> assign(:loading_percent, engine_state.progress)
      |> assign(:current_time, format_time(engine_state.current_time))
      |> assign(:active_count, 0)
      |> assign(:sim_speed, 60)
      |> stream(:active_trains, [], limit: 20)

    {:ok, socket}
  end

  def handle_info({:loading_progress, percent, msg}, socket) do
    {:noreply, assign(socket, loading_percent: percent, loading_msg: msg)}
  end

  def handle_info(:data_ready, socket) do
    {:noreply, assign(socket, status: :running)}
  end

  def handle_info({:tick, time_sec, positions}, socket) do
    time_str = format_time(time_sec)
    json_positions = Enum.map(positions, fn {id, lon, lat} -> [id, lon, lat] end)

    sidebar_updates = 
      positions 
      |> Enum.take(20)
      |> Enum.map(fn {id, lon, lat} -> %{id: "#{id}", trip_id: id, lon: lon, lat: lat} end)

    socket = 
      socket
      |> assign(current_time: time_str, active_count: length(positions), status: :running)
      |> stream_insert_many(:active_trains, sidebar_updates)
      |> push_event("update_trains", %{positions: json_positions})

    {:noreply, socket}
  end

  def handle_event("pause", _, socket) do
    Engine.pause()
    {:noreply, socket}
  end

  def handle_event("resume", _, socket) do
    Engine.resume()
    {:noreply, socket}
  end

  defp stream_insert_many(socket, name, items) do
    Enum.reduce(items, socket, fn item, acc ->
      stream_insert(acc, name, item)
    end)
  end

  defp format_time(time_sec) do
    hours = div(time_sec, 3600) |> rem(24)
    minutes = div(rem(time_sec, 3600), 60)
    seconds = rem(time_sec, 60)
    :io_lib.format("~2..0B:~2..0B:~2..0B", [hours, minutes, seconds]) |> to_string()
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen w-screen bg-slate-950 flex flex-col overflow-hidden font-mono text-slate-300">
      <!-- Ignition Overlay (Progress UX) -->
      <%= if @status == :loading do %>
        <div class="absolute inset-0 z-50 bg-slate-950/95 backdrop-blur-3xl flex flex-col items-center justify-center p-12">
          <div class="max-w-2xl w-full space-y-8">
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-amber-500 font-bold tracking-[0.3em] text-sm uppercase mb-1">Nexus Ignition Sequence</h2>
                <p class="text-white text-3xl font-bold tracking-tight"><%= @loading_msg %></p>
              </div>
              <div class="text-5xl font-black text-slate-800 tabular-nums leading-none">
                <%= @loading_percent %>%
              </div>
            </div>
            
            <div class="h-1.5 w-full bg-slate-900 rounded-full overflow-hidden border border-slate-800">
              <div class="h-full bg-gradient-to-r from-amber-600 to-amber-400 transition-all duration-500 shadow-[0_0_15px_#f59e0b]" style={"width: #{@loading_percent}%"}></div>
            </div>

            <div class="grid grid-cols-3 gap-4">
              <div class="bg-slate-900/50 p-4 border border-slate-800 rounded-lg">
                <div class="text-[10px] text-slate-500 uppercase mb-1">Subsystem</div>
                <div class="text-xs text-slate-300 font-bold">STIG Data Plane</div>
              </div>
              <div class="bg-slate-900/50 p-4 border border-slate-800 rounded-lg">
                <div class="text-[10px] text-slate-500 uppercase mb-1">State</div>
                <div class="text-xs text-amber-500 font-bold animate-pulse">Synchronizing</div>
              </div>
              <div class="bg-slate-900/50 p-4 border border-slate-800 rounded-lg">
                <div class="text-[10px] text-slate-500 uppercase mb-1">Mandate</div>
                <div class="text-xs text-slate-300 font-bold">Zero Reduction</div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Top Tactical Header -->
      <nav class="h-16 border-b border-slate-800 bg-slate-900/50 backdrop-blur-xl flex items-center justify-between px-8 z-20">
        <div class="flex items-center space-x-4">
          <div class="w-8 h-8 bg-amber-500 rounded flex items-center justify-center text-slate-950 font-bold shadow-[0_0_15px_rgba(245,158,11,0.3)]">H</div>
          <div>
            <h1 class="text-white font-bold leading-none tracking-tight">HEXAPLANNER NEXUS</h1>
            <span class="text-[10px] text-slate-500 tracking-[0.2em] uppercase">CFF/SBB Digital Twin</span>
          </div>
        </div>

        <div class="flex items-center space-x-12">
          <div class="text-center">
            <div class="text-[10px] text-slate-500 uppercase mb-1">Active Entities</div>
            <div class="text-xl font-bold text-white tabular-nums"><%= @active_count %></div>
          </div>
          <div class="text-center">
            <div class="text-[10px] text-slate-500 uppercase mb-1">Time Dilation</div>
            <div class="text-xl font-bold text-amber-500 tabular-nums"><%= @sim_speed %>x</div>
          </div>
          <div class="bg-slate-950 border border-slate-800 rounded-lg px-6 py-2 shadow-inner border-t-amber-500/30">
            <div class="text-[10px] text-slate-500 uppercase mb-1">Simulation Clock</div>
            <div class="text-2xl font-bold text-cyan-400 tabular-nums leading-none"><%= @current_time %></div>
          </div>
        </div>
      </nav>

      <main class="flex-grow flex relative overflow-hidden min-h-0">
        <!-- Sidebar HUD -->
        <aside class="w-80 border-r border-slate-800 bg-slate-900/30 backdrop-blur-md z-20 flex flex-col pointer-events-auto overflow-hidden">
          <div class="p-4 border-b border-slate-800 bg-slate-900/50 flex justify-between items-center">
            <h3 class="text-xs font-bold text-slate-400 uppercase tracking-widest">Active Registry</h3>
            <div class="flex items-center space-x-1">
              <div class="w-1.5 h-1.5 bg-emerald-500 rounded-full animate-pulse"></div>
              <span class="text-[9px] text-emerald-500 font-bold uppercase">Live</span>
            </div>
          </div>
          
          <div id="active-trains-list" phx-update="stream" class="flex-grow overflow-y-auto p-2 space-y-2 custom-scrollbar">
            <div :for={{id, train} <- @streams.active_trains} id={id} class="bg-slate-800/40 border border-slate-700/50 p-3 rounded-lg hover:bg-slate-800 transition-all duration-300 group">
              <div class="flex justify-between items-start mb-1">
                <span class="text-amber-500 font-bold text-xs">TRIP_<%= train.trip_id %></span>
              </div>
              <div class="text-[9px] text-slate-500 flex justify-between font-mono">
                <span><%= Float.round(train.lat, 4) %>N</span>
                <span><%= Float.round(train.lon, 4) %>E</span>
              </div>
            </div>
          </div>

          <!-- Simulation Controls -->
          <div class="p-4 border-t border-slate-800 bg-slate-900/50 space-y-4">
             <div class="grid grid-cols-2 gap-2">
                <button phx-click="pause" class="bg-slate-800 hover:bg-slate-700 text-white py-2 rounded text-xs border border-slate-700 transition-all active:scale-95">PAUSE</button>
                <button phx-click="resume" class="bg-amber-600 hover:bg-amber-500 text-white py-2 rounded text-xs font-bold shadow-lg shadow-amber-900/20 transition-all active:scale-95">RESUME</button>
             </div>
          </div>
        </aside>
<!-- Visualization Surface (WebGL Hook) -->
<section class="flex-grow relative bg-slate-950 overflow-hidden">
  <div id="deckgl-wrapper" class="absolute inset-0 w-full h-full [&_canvas]:block [&_canvas]:absolute" phx-hook="DeckGLMap" phx-update="ignore"></div>

  <!-- Map Overlay HUD -->
          <div class="absolute bottom-8 right-8 bg-slate-900/80 border border-slate-800 p-4 rounded-xl backdrop-blur-lg shadow-2xl z-20 pointer-events-none">
            <div class="text-[10px] text-slate-500 uppercase mb-2 tracking-widest">Physical Layer Status</div>
            <div class="flex items-center space-x-3">
              <div class="w-2 h-2 bg-blue-500 rounded-full shadow-[0_0_8px_#3b82f6]"></div>
              <span class="text-xs text-slate-300 font-medium italic">STIG (150M Cantons) Active</span>
            </div>
          </div>
        </section>
      </main>
    </div>
    """
  end
end
