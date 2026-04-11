defmodule HexaFactoryWeb.TwinLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(HexaRail.PubSub, "simulation:hexafactory")
    end
    {:ok, assign(socket, :page_title, "HexaFactory Digital Twin")}
  end

  def handle_info({:hexafactory_update, %{problem: problem, explanation: explanation}}, socket) do
    # SOTA Domain Translation: Problem -> VizKit ViewModel
    # We offload the heavy data joining (Violations <-> Jobs) to the BEAM (Elixir)
    # to ensure the JS client receives a perfectly structured, O(1) renderable payload.
    
    violations_by_job = group_violations_by_job(explanation)
    
    viz_payload = %{
      # Macro View: Topology
      nodes: translate_resources_to_nodes(problem.resources, explanation),
      edges: translate_topology_edges(problem.edges),
      
      # Micro View: Gantt/Timeline
      lanes: translate_resources_to_lanes(problem.resources),
      events: translate_jobs_to_events(problem.jobs, violations_by_job),
      
      # Global Context
      score: if(explanation, do: explanation.score, else: %{hard: 0, medium: 0, soft: 0}),
      # In a real SOTA system, the temporal anchor is dynamic.
      # For this integration, we mock a current_time of 0.
      current_time: 0 
    }
    
    {:noreply, push_event(socket, "update_viz", viz_payload)}
  end
  
  # --- Decorators & Translators ---

  defp group_violations_by_job(nil), do: %{}
  defp group_violations_by_job(explanation) do
    explanation.violations
    |> Enum.filter(&(&1.job_id != nil))
    |> Enum.group_by(& &1.job_id)
  end

  defp translate_resources_to_nodes(resources, explanation) do
    # For the Macro Knowledge Map (Sigma.js)
    violations_by_res = 
      if explanation do
        explanation.violations
        |> Enum.filter(&(&1.resource_id != nil))
        |> Enum.group_by(& &1.resource_id)
      else
        %{}
      end

    Enum.map(resources, fn res ->
      res_violations = Map.get(violations_by_res, res.id, [])
      health_status = determine_health_status(res_violations)
      
      %{
        id: "res-#{res.id}",
        label: res.name,
        health_status: health_status,
        capacity: res.capacity
      }
    end)
  end

  defp translate_topology_edges(edges) do
    Enum.map(edges, fn edge ->
      %{
        source: "job-#{edge.from_job_id}",
        target: "job-#{edge.to_job_id}",
        type: edge.edge_type,
        lag: edge.lag
      }
    end)
  end

  defp translate_resources_to_lanes(resources) do
    # For the Micro Gantt Timeline Y-Axis
    Enum.map(resources, fn res ->
      %{
        id: "lane-#{res.id}",
        label: res.name
      }
    end)
  end
  
  defp translate_jobs_to_events(jobs, violations_by_job) do
    # For the Micro Gantt Timeline X-Axis Events
    Enum.map(jobs, fn job ->
      job_violations = Map.get(violations_by_job, job.id, [])
      health_status = determine_health_status(job_violations)
      
      %{
        id: "job-#{job.id}",
        start: job.start_time,
        end: if(job.start_time, do: job.start_time + job.duration, else: nil),
        duration: job.duration,
        group: job.group_id,
        # A job can require multiple resources, meaning it spans multiple lanes
        lane_ids: Enum.map(job.required_resources, &"lane-#{&1}"),
        
        # XAI Enrichment
        health_status: health_status,
        tooltip_violations: Enum.map(job_violations, &%{severity: &1.severity, message: &1.message})
      }
    end)
  end

  defp determine_health_status(violations) do
    cond do
      Enum.any?(violations, &(&1.severity == "hard")) -> "critical"
      Enum.any?(violations, &(&1.severity == "medium")) -> "warning"
      Enum.any?(violations, &(&1.severity == "soft")) -> "suboptimal"
      true -> "healthy"
    end
  end
end
