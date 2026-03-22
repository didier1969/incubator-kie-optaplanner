defmodule HexaPlannerWeb.TwinLive do
  use Phoenix.LiveView
  alias HexaPlanner.Domain.{Job, Problem}
  alias HexaPlanner.SolverNif

  alias HexaPlanner.GTFS.{Trip, StopTime}
  alias HexaPlanner.Repo
  import Ecto.Query

  def mount(_params, _session, socket) do
    # MANDATE: NO REDUCTION. Loading the entire Swiss railway network.
    # Calculate real durations for each trip from stop_times
    durations_query = from st in StopTime, group_by: st.trip_id, select: {st.trip_id, max(st.departure_time) - min(st.arrival_time)}
    durations_map = Repo.all(durations_query) |> Map.new()

    trips = Repo.all(Trip)

    problem = %Problem{
      id: "SBB_CFF_FFS_NETWORK_FULL",
      resources: [],
      jobs: Enum.map(trips, fn t ->
        duration = Map.get(durations_map, t.id, 60)
        %Job{
          id: t.id, 
          duration: duration,
          required_resources: [], 
          start_time: nil
        }
      end)
    }

    score = SolverNif.evaluate_problem(problem)

    socket = 
      socket
      |> assign(problem: problem, score: score, is_optimizing: false)
      |> stream(:trips, trips)

    {:ok, socket}
  end

  def handle_event("optimize", _, socket) do
    # Trigger the Rust Engine on the FULL 1.19M entities
    optimized_problem = SolverNif.optimize_problem(socket.assigns.problem, 100)
    new_score = SolverNif.evaluate_problem(optimized_problem)

    {:noreply, assign(socket, problem: optimized_problem, score: new_score, is_optimizing: false)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8 max-w-7xl mx-auto">
      <header class="flex justify-between items-center mb-8 border-b border-gray-700 pb-4">
        <div>
          <h1 class="text-3xl font-bold text-emerald-400">HexaPlanner Mission Control</h1>
          <p class="text-gray-400 text-sm mt-1">Full Scale SBB Jumeau Numérique - Zero Simplification</p>
        </div>
        <div class="text-right">
          <div class="text-xl">
            Score: <span class={if @score < 0, do: "text-red-500", else: "text-emerald-500"}><%= @score %></span>
          </div>
          <div class="text-xs text-gray-500 mt-1">
            Processing <%= length(@problem.jobs) %> Trains simultaneously
          </div>
        </div>
      </header>

      <div class="grid grid-cols-3 gap-8">
        <!-- Dashboard Stats -->
        <div class="col-span-3 grid grid-cols-4 gap-4 mb-4">
          <div class="bg-gray-800 p-4 rounded border border-gray-700">
            <div class="text-gray-500 text-xs uppercase font-bold">Total Entities</div>
            <div class="text-2xl text-white font-mono"><%= length(@problem.jobs) %></div>
          </div>
          <div class="bg-gray-800 p-4 rounded border border-gray-700">
            <div class="text-gray-500 text-xs uppercase font-bold">Unassigned</div>
            <div class="text-2xl text-red-400 font-mono"><%= Enum.count(@problem.jobs, &is_nil(&1.start_time)) %></div>
          </div>
          <div class="bg-gray-800 p-4 rounded border border-gray-700">
            <div class="text-gray-500 text-xs uppercase font-bold">Optimized</div>
            <div class="text-2xl text-emerald-400 font-mono"><%= Enum.count(@problem.jobs, &(!is_nil(&1.start_time))) %></div>
          </div>
          <div class="bg-gray-800 p-4 rounded border border-gray-700">
            <div class="text-gray-500 text-xs uppercase font-bold">Engine Status</div>
            <div class="text-2xl text-blue-400 font-mono">READY (RUST)</div>
          </div>
        </div>

        <!-- Live Stream of Network Entities (Sample) -->
        <div class="col-span-3 bg-gray-900 p-6 rounded-lg shadow-lg border border-gray-800 max-h-[500px] overflow-y-auto">
          <h2 class="text-xl font-semibold mb-4 text-gray-300">Real-Time Network State (Streaming)</h2>
          <table class="w-full text-left text-sm">
            <thead class="text-gray-500 border-b border-gray-800">
              <tr>
                <th class="pb-2">Trip Internal ID</th>
                <th class="pb-2">GTFS ID</th>
                <th class="pb-2">Route</th>
                <th class="pb-2">Status</th>
              </tr>
            </thead>
            <tbody id="trips-stream" phx-update="stream" class="divide-y divide-gray-800">
              <%= for {id, trip} <- @streams.trips do %>
                <tr id={id} class="hover:bg-gray-800/50">
                  <td class="py-2 font-mono text-gray-400">#<%= trip.id %></td>
                  <td class="py-2 text-white"><%= trip.original_trip_id %></td>
                  <td class="py-2 text-gray-300"><%= trip.route_id %></td>
                  <td class="py-2">
                    <span class="px-2 py-0.5 rounded-full text-[10px] bg-red-900/30 text-red-400 border border-red-800">
                      IDLE
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="mt-8 text-center">
        <button phx-click="optimize" class="bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-4 px-12 rounded-full shadow-[0_0_20px_rgba(16,185,129,0.4)] transition-all">
          Launch Global Network Optimization (1.19 Million Trains)
        </button>
      </div>
    </div>
    """
  end
end
