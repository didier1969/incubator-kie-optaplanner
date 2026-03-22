defmodule HexaPlannerWeb.TwinLive do
  use Phoenix.LiveView
  alias HexaPlanner.Domain.{Job, Problem}
  alias HexaPlanner.SolverNif

  alias HexaPlanner.GTFS.Trip
  alias HexaPlanner.Repo
  import Ecto.Query

  def mount(_params, _session, socket) do
    # Load real trips from the GTFS database (first 5 for the dashboard)
    trips = Repo.all(from t in Trip, limit: 5)
    
    problem = %Problem{
      id: "SBB_CFF_FFS_NETWORK",
      resources: [],
      jobs: Enum.map(trips, fn t ->
        %Job{
          id: t.id, 
          duration: 60, # Standard slot
          required_resources: [], 
          start_time: nil
        }
      end)
    }

    score = SolverNif.evaluate_problem(problem)
    {:ok, assign(socket, problem: problem, score: score, is_optimizing: false)}
  end

  def handle_event("optimize", _, socket) do
    # Trigger the Rust Engine
    optimized_problem = SolverNif.optimize_problem(socket.assigns.problem, 10)
    new_score = SolverNif.evaluate_problem(optimized_problem)

    {:noreply, assign(socket, problem: optimized_problem, score: new_score, is_optimizing: false)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8 max-w-5xl mx-auto">
      <header class="flex justify-between items-center mb-8 border-b border-gray-700 pb-4">
        <h1 class="text-3xl font-bold text-emerald-400">HexaPlanner Mission Control</h1>
        <div class="text-xl">
          Score: <span class={if @score < 0, do: "text-red-500", else: "text-emerald-500"}><%= @score %></span>
        </div>
      </header>

      <div class="grid grid-cols-2 gap-8">
        <!-- Job List -->
        <div class="bg-gray-800 p-6 rounded-lg shadow-lg">
          <h2 class="text-xl font-semibold mb-4 text-gray-300">Unassigned Jobs</h2>
          <ul class="space-y-3">
            <%= for job <- Enum.filter(@problem.jobs, &is_nil(&1.start_time)) do %>
              <li class="bg-red-900/20 border border-red-800 p-3 rounded flex justify-between">
                <span>Job #<%= job.id %></span>
                <span class="text-red-400 text-sm">Unscheduled</span>
              </li>
            <% end %>
          </ul>
        </div>

        <!-- Schedule (Optimized) -->
        <div class="bg-gray-800 p-6 rounded-lg shadow-lg">
          <h2 class="text-xl font-semibold mb-4 text-gray-300">Production Schedule</h2>
          <ul class="space-y-3">
            <%= for job <- Enum.filter(@problem.jobs, &(not is_nil(&1.start_time))) do %>
              <li class="bg-emerald-900/20 border border-emerald-800 p-3 rounded flex justify-between">
                <span>Job #<%= job.id %></span>
                <span class="text-emerald-400 text-sm">Starts @ t=<%= job.start_time %></span>
              </li>
            <% end %>
          </ul>
        </div>
      </div>

      <div class="mt-8 text-center">
        <button phx-click="optimize" class="bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-3 px-8 rounded-full shadow-[0_0_15px_rgba(16,185,129,0.5)] transition-all">
          Launch Rust Optimization (Local Search)
        </button>
      </div>
    </div>
    """
  end
end
