# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRailWeb.TwinLive do
  use Phoenix.LiveView
  alias Phoenix.PubSub
  alias HexaRail.Simulation.Engine

  @moduledoc """
  High-fidelity Digital Twin Dashboard.
  Adheres to the official Phoenix LiveView v1.1 best practices:
  - Streams for flicker-free data updates
  - AsyncResult for managed loading states
  - push_event for high-frequency WebGL rendering
  - Real-time Progress UX for data ingestion
  """

  @default_status %{
    status: :running,
    loading_msg: "System Live",
    loading_percent: 100,
    current_time: "00:00:00"
  }

  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(HexaRail.PubSub, "simulation:switzerland")
    end

    initial_status = initial_status()

    socket =
      socket
      |> assign(:status, initial_status.status)
      |> assign(:loading_msg, initial_status.loading_msg)
      |> assign(:loading_percent, initial_status.loading_percent)
      |> assign(:current_time, initial_status.current_time)
      |> assign(:active_count, 0)
      |> assign(:sim_speed, 60)
      |> assign(:chaos_event, nil)
      |> stream(:active_trains, [], limit: 20)

    {:ok, socket}
  end

  def handle_info({:chaos_detected, event}, socket) do
    {:noreply, assign(socket, chaos_event: normalize_chaos_event(event))}
  end

  def handle_info({:loading_progress, percent, msg}, socket) do
    {:noreply, assign(socket, loading_percent: percent, loading_msg: msg)}
  end

  def handle_info(:data_ready, socket) do
    {:noreply, assign(socket, status: :running)}
  end

  def handle_info({:tick_binary, time_sec, binary_payload, health}, socket) do
    time_str = format_time(time_sec)
    # 32 bytes per train (Phase 19-B)
    active_count = div(byte_size(Base.decode64!(binary_payload)), 32)

    socket = 
      socket
      |> assign(
        current_time: time_str, 
        active_count: active_count, 
        status: :running,
        system_delay: div(health.total_delay_seconds, 60),
        active_conflicts: health.active_conflicts,
        broken_connections: health.broken_connections
      )
      |> push_event("update_trains_binary", %{data: binary_payload})

    {:noreply, socket}
  end

  def handle_event("execute_scenario", _, socket) do
    # Load the Gotthard scenario JSON
    path = Path.join([:code.priv_dir(:hexarail), "scenarios", "gotthard_blackout.json"])
    scenario_data = path |> File.read!() |> Jason.decode!()

    apply_engine(:load_scenario, [scenario_data])

    {:noreply, assign(socket, chaos_event: normalize_chaos_event(%{resolved: false, message: "Scenario injected."}))}
  end

  def handle_event("resolve_chaos", %{"strategy" => strategy}, socket) do
    apply_engine(:resolve_chaos, [strategy])

    msg = case strategy do
      "greedy" -> "Resolving using Salsa Greedy..."
      "local_search" -> "Resolving using Local Search..."
      "genetic" -> "Resolving using Global Genetic..."
      "otp" -> "Resolving using OTP Actors..."
      _ -> "Resolving..."
    end
    
    # We clear the chaos event and show a temporary resolution message
    {:noreply, assign(socket, chaos_event: normalize_chaos_event(%{resolved: true, message: msg}))}
  end

  def handle_event("inject_chaos", _, socket) do
    # For phase 1, we simulate a mock critical breakdown to test the UI flow
    send(self(), {:chaos_detected, %{trip_id: 9224174, severity: "critical", type: "Breakdown"}})
    {:noreply, socket}
  end

  def handle_event("pause", _, socket) do
    apply_engine(:pause, [])
    {:noreply, socket}
  end

  def handle_event("resume", _, socket) do
    apply_engine(:resume, [])
    {:noreply, socket}
  end

  defp initial_status do
    engine_module = engine_module()

    with true <- function_exported?(engine_module, :get_status, 0),
         engine_state <- safe_get_status(engine_module),
         true <- is_map(engine_state) do
      %{
        status: Map.get(engine_state, :status, @default_status.status),
        loading_msg: Map.get(engine_state, :message, @default_status.loading_msg),
        loading_percent: Map.get(engine_state, :progress, @default_status.loading_percent),
        current_time: normalize_current_time(Map.get(engine_state, :current_time, @default_status.current_time))
      }
    else
      _ -> @default_status
    end
  end

  defp safe_get_status(engine_module) do
    engine_module.get_status()
  catch
    :exit, _reason -> nil
  end

  defp engine_module do
    Application.get_env(:hexarail, :twin_live_engine_module, Engine)
  end

  defp apply_engine(function_name, args) do
    module = engine_module()

    if function_exported?(module, function_name, length(args)) do
      apply(module, function_name, args)
    else
      :ok
    end
  end

  defp normalize_current_time(time_sec) when is_integer(time_sec), do: format_time(time_sec)
  defp normalize_current_time(time_string) when is_binary(time_string), do: time_string
  defp normalize_current_time(_time), do: @default_status.current_time

  defp normalize_chaos_event(event) do
    %{
      resolved: Map.get(event, :resolved, false),
      message: Map.get(event, :message, "Chaos event detected."),
      severity: Map.get(event, :severity),
      trip_id: Map.get(event, :trip_id),
      type: Map.get(event, :type)
    }
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

      <!-- Visualization Surface (WebGL Hook) -->
      <main class="flex-grow relative bg-slate-950 overflow-hidden w-full h-full">
        <div id="deckgl-wrapper" class="absolute inset-0 w-full h-full [&_canvas]:block [&_canvas]:absolute" phx-hook="DeckGLMap" phx-update="ignore"></div>

        <!-- Top Tactical HUD (Metrics) -->
        <nav class="absolute top-0 left-0 right-0 p-6 pointer-events-none flex justify-between items-start z-20">
          <div class="flex flex-col space-y-2">
            <div class="flex items-center space-x-4 bg-slate-900/80 backdrop-blur-md border border-slate-800 rounded-lg p-3 shadow-2xl pointer-events-auto">
              <div class="w-8 h-8 bg-amber-500 rounded flex items-center justify-center text-slate-950 font-black">H</div>
              <div>
                <h1 class="text-white font-bold leading-none tracking-tight text-lg">NEXUS CONTROL</h1>
                <span class="text-[9px] text-slate-400 tracking-[0.2em] uppercase">System Health Monitor</span>
              </div>
            </div>

            <!-- Health Gauges -->
            <div class="flex space-x-2">
              <div class="bg-slate-900/80 backdrop-blur-md border border-slate-800 rounded-lg p-3 w-32 shadow-lg">
                <div class="text-[9px] text-slate-500 uppercase tracking-widest mb-1">System Delay</div>
                <div class={"text-xl font-bold tabular-nums #{if assigns[:system_delay] && @system_delay > 0, do: "text-red-500", else: "text-white"}"}>
                  <%= assigns[:system_delay] || 0 %> <span class="text-xs text-slate-500 font-normal">min</span>
                </div>
              </div>
              <div class="bg-slate-900/80 backdrop-blur-md border border-slate-800 rounded-lg p-3 w-32 shadow-lg">
                <div class="text-[9px] text-slate-500 uppercase tracking-widest mb-1">Broken Conn.</div>
                <div class={"text-xl font-bold tabular-nums #{if assigns[:broken_connections] && @broken_connections > 0, do: "text-red-500", else: "text-emerald-400"}"}>
                  <%= assigns[:broken_connections] || 0 %>
                </div>
              </div>
              <div class="bg-slate-900/80 backdrop-blur-md border border-slate-800 rounded-lg p-3 w-32 shadow-lg">
                <div class="text-[9px] text-slate-500 uppercase tracking-widest mb-1">Active Conflicts</div>
                <div class={"text-xl font-bold tabular-nums #{if assigns[:active_conflicts] && @active_conflicts > 0, do: "text-amber-500", else: "text-emerald-400"}"}>
                  <%= assigns[:active_conflicts] || 0 %>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-slate-950/90 border border-slate-800 rounded-lg px-6 py-3 shadow-2xl pointer-events-auto border-t-amber-500/50 flex flex-col items-end">
            <div class="text-[9px] text-slate-500 uppercase tracking-widest mb-1">Simulation Clock</div>
            <div class="text-3xl font-bold text-cyan-400 tabular-nums leading-none"><%= @current_time %></div>
            <div class="flex space-x-2 mt-2">
              <button phx-click="pause" class="text-[9px] uppercase tracking-widest hover:text-white transition-colors">Pause</button>
              <button phx-click="resume" class="text-[9px] uppercase tracking-widest text-amber-500 hover:text-amber-400 font-bold transition-colors">Resume</button>
            </div>
          </div>
        </nav>

        <!-- Bottom Left: Scenario Director -->
        <div class="absolute bottom-6 left-6 w-96 bg-slate-900/80 backdrop-blur-xl border border-slate-800 rounded-xl shadow-2xl pointer-events-auto overflow-hidden flex flex-col max-h-[50vh]">
          <div class="p-4 border-b border-slate-800 flex justify-between items-center bg-slate-900">
            <h3 class="text-xs font-bold text-white uppercase tracking-widest">Chaos Director</h3>
            <span class={"px-2 py-0.5 rounded text-[9px] uppercase tracking-widest font-bold border #{if assigns[:chaos_event] && !@chaos_event.resolved, do: "bg-red-500/20 text-red-500 border-red-500/30 animate-pulse", else: "bg-emerald-500/20 text-emerald-400 border-emerald-500/30"}"}>
              <%= if assigns[:chaos_event] && !@chaos_event.resolved, do: "Active", else: "Ready" %>
            </span>
          </div>
          
          <div class="p-4 flex-grow overflow-y-auto custom-scrollbar space-y-4">
            <%= if assigns[:chaos_event] do %>
              <div class={"rounded-lg border p-3 text-xs #{if @chaos_event.resolved, do: "border-emerald-500/30 bg-emerald-500/10 text-emerald-200", else: "border-red-500/30 bg-red-500/10 text-red-100"}"}>
                <div class="font-bold uppercase tracking-widest text-[10px] mb-1">Status</div>
                <div><%= @chaos_event.message %></div>
              </div>
            <% end %>

            <div>
              <label class="block text-[10px] uppercase tracking-widest text-slate-500 mb-2">Active Scenario</label>
              <select class="w-full bg-slate-950 border border-slate-800 text-white text-xs rounded p-2 focus:border-amber-500 outline-none transition-colors">
                <option value="gotthard_blackout">Gotthard Base Tunnel Blackout</option>
              </select>
            </div>

            <!-- Timeline visualization -->
            <div class="border-l-2 border-slate-800 ml-2 pl-4 py-2 space-y-4">
              <div class="relative">
                <div class="absolute w-2 h-2 rounded-full bg-slate-700 -left-[21px] top-1"></div>
                <div class="text-[10px] font-bold text-amber-500 mb-0.5">08:00 (T+0)</div>
                <div class="text-xs text-slate-300">Gotthard Node Offline</div>
                <div class="text-[10px] text-slate-500">Duration: 4h</div>
              </div>
              <div class="relative">
                <div class="absolute w-2 h-2 rounded-full bg-slate-700 -left-[21px] top-1"></div>
                <div class="text-[10px] font-bold text-emerald-500 mb-0.5">12:00 (T+4h)</div>
                <div class="text-xs text-slate-300">Infrastructure Restored</div>
                <div class="text-[10px] text-slate-500">Auto-Recovery Phase</div>
              </div>
            </div>
          </div>
          
          <div class="p-4 border-t border-slate-800 bg-slate-950">
             <button phx-click="execute_scenario" class="w-full bg-red-900/50 hover:bg-red-600 text-red-500 hover:text-white font-bold py-3 rounded text-xs tracking-widest uppercase transition-all shadow-[0_0_15px_rgba(220,38,38,0.2)]">
               Execute Scenario
             </button>
          </div>
        </div>

      </main>
    </div>
    """
  end
end
