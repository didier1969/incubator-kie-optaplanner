defmodule HexaFactoryWeb.TwinLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(HexaRail.PubSub, "simulation:hexafactory")
    end
    {:ok, assign(socket, :page_title, "HexaFactory Digital Twin")}
  end

  def handle_info({:hexafactory_update, %{problem: problem, explanation: explanation}}, socket) do
    # Domain Translation: Problem -> VizKit Primitives
    viz_payload = %{
      nodes: translate_resources_to_nodes(problem.resources),
      events: translate_jobs_to_events(problem.jobs),
      violations: translate_explanation(explanation)
    }
    
    {:noreply, push_event(socket, "update_viz", viz_payload)}
  end
  
  defp translate_resources_to_nodes(resources) do
    # Stub: Maps resources to Sigma.js node format
    Enum.map(resources, &%{id: &1.id, label: &1.name})
  end
  
  defp translate_jobs_to_events(jobs) do
    # Stub: Maps jobs to Timeline events
    Enum.map(jobs, &%{id: &1.id, start: &1.start_time, duration: &1.duration, group: &1.group_id})
  end

  defp translate_explanation(nil), do: []
  defp translate_explanation(exp), do: exp.violations
end
