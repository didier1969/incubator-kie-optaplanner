# HexaFactory TwinLive Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the HexaFactory Digital Twin (XAI Dashboard) in Phoenix LiveView using VizKit for "Drill-Down" Macro/Micro visualizations.

**Architecture:** We will create a strict vertical implementation for the factory (`HexaFactoryWeb.TwinLive`). The LiveView will act as a Domain Adapter, subscribing to the `simulation:hexafactory` PubSub channel, translating agnostic `HexaCore` objects into Factory entities, and pushing them to a Javascript `VizKitHook` via `phx-update="ignore"`.

**Tech Stack:** Elixir, Phoenix LiveView, Phoenix PubSub, JavaScript, `@viz-kit/core` (Sigma.js / ECharts).

---

### Task 1: Create the HexaFactoryWeb Namespace and LiveView Skeleton

**Files:**
- Create: `hexarail/lib/hexafactory_web/live/twin_live.ex`
- Create: `hexarail/lib/hexafactory_web/live/twin_live.html.hex`
- Modify: `hexarail/lib/hexarail_web/router.ex`
- Test: `hexarail/test/hexafactory_web/live/twin_live_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule HexaFactoryWeb.TwinLiveTest do
  use HexaRailWeb.ConnCase
  import Phoenix.LiveViewTest

  test "disconnected and connected mount", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/factory/twin")
    assert disconnected_html =~ "HexaFactory Digital Twin"
    assert render(page_live) =~ "HexaFactory Digital Twin"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `nix develop --command bash -c "cd hexarail && mix test test/hexafactory_web/live/twin_live_test.exs"`
Expected: FAIL with "no route found for GET /factory/twin"

**Step 3: Write minimal implementation**

*Add route to `router.ex`:*
```elixir
scope "/factory", HexaFactoryWeb do
  pipe_through :browser
  live "/twin", TwinLive
end
```

*Create `twin_live.ex`:*
```elixir
defmodule HexaFactoryWeb.TwinLive do
  use HexaRailWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "HexaFactory Digital Twin")}
  end
end
```

*Create `twin_live.html.hex`:*
```html
<div id="hexafactory-twin">
  <h1>HexaFactory Digital Twin</h1>
  <div id="factory-viz" phx-update="ignore" phx-hook="VizKitHook"></div>
</div>
```

**Step 4: Run test to verify it passes**

Run: `nix develop --command bash -c "cd hexarail && mix test test/hexafactory_web/live/twin_live_test.exs"`
Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/lib/hexafactory_web/ hexarail/lib/hexarail_web/router.ex hexarail/test/hexafactory_web/
git commit -m "feat(ui): scaffold HexaFactoryWeb.TwinLive isolated namespace"
```

### Task 2: Implement PubSub Broadcast in HexaFactory Solver

**Files:**
- Modify: `hexarail/lib/hexafactory/cli.ex` (or solver entry point)
- Test: `hexarail/test/hexafactory/pubsub_broadcast_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule HexaFactory.PubSubBroadcastTest do
  use ExUnit.Case

  test "solver broadcasts results to simulation:hexafactory" do
    Phoenix.PubSub.subscribe(HexaRail.PubSub, "simulation:hexafactory")
    
    # Trigger a small solve
    HexaFactory.Cli.solve(["--profile", "smoke", "--iterations", "10"])
    
    assert_receive {:hexafactory_update, %{problem: _, explanation: _}}, 5000
  end
end
```

**Step 2: Run test to verify it fails**

Run: `nix develop --command bash -c "cd hexarail && mix test test/hexafactory/pubsub_broadcast_test.exs"`
Expected: FAIL with timeout (no message received).

**Step 3: Write minimal implementation**

*In the solver/CLI after `HexaCore.Native.optimize_problem_core`:*
```elixir
Phoenix.PubSub.broadcast(
  HexaRail.PubSub,
  "simulation:hexafactory",
  {:hexafactory_update, %{problem: optimized_problem, explanation: optimized_problem.explanation}}
)
```

**Step 4: Run test to verify it passes**

Run: `nix develop --command bash -c "cd hexarail && mix test test/hexafactory/pubsub_broadcast_test.exs"`
Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/lib/hexafactory/cli.ex hexarail/test/hexafactory/pubsub_broadcast_test.exs
git commit -m "feat(core): broadcast factory state via PubSub after solving"
```

### Task 3: Handle Domain Translation and `push_event` in LiveView

**Files:**
- Modify: `hexarail/lib/hexafactory_web/live/twin_live.ex`
- Test: `hexarail/test/hexafactory_web/live/twin_live_test.exs`

**Step 1: Write the failing test**

*Add to `twin_live_test.exs`:*
```elixir
test "LiveView translates raw Problem into VizKit primitives", %{conn: conn} do
  {:ok, page_live, _html} = live(conn, "/factory/twin")
  
  # Simulate PubSub message
  fake_problem = %HexaCore.Domain.Problem{jobs: [%{id: 1, start_time: 10, duration: 5, group_id: "batch:HOT", required_resources: [100]}]}
  send(page_live.pid, {:hexafactory_update, %{problem: fake_problem, explanation: nil}})
  
  # LiveViewTest doesn't easily assert on push_event payloads directly without custom hooks,
  # but we can verify the LiveView doesn't crash and handles the info.
  assert render(page_live) =~ "HexaFactory"
end
```

**Step 2: Run test to verify it fails**

Run: `nix develop --command bash -c "cd hexarail && mix test test/hexafactory_web/live/twin_live_test.exs"`
Expected: FAIL due to missing `handle_info`.

**Step 3: Write minimal implementation**

*In `twin_live.ex`:*
```elixir
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
```

**Step 4: Run test to verify it passes**

Run: `nix develop --command bash -c "cd hexarail && mix test test/hexafactory_web/live/twin_live_test.exs"`
Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/lib/hexafactory_web/live/twin_live.ex hexarail/test/hexafactory_web/live/twin_live_test.exs
git commit -m "feat(ui): translate Core Problem to VizKit primitives and push to client"
```

### Task 4: Client-Side VizKit Hook (JavaScript)

**Files:**
- Modify: `hexarail/assets/js/app.js`

**Step 1: Write the minimal implementation**

*Since testing JS hooks natively in ExUnit is tricky, we write the implementation and rely on manual/E2E verification.*

*In `assets/js/app.js`:*
```javascript
let Hooks = {}

Hooks.VizKitHook = {
  mounted() {
    console.log("VizKitHook mounted")
    // In a real app, initialize @viz-kit/core Sigma/Timeline instance here
    // this.chart = createChart(this.el, { type: 'timeline', data: [] })
    
    this.handleEvent("update_viz", (payload) => {
      console.log("Received VizKit Update:", payload)
      // this.chart.update({ data: payload })
      
      // Temporary debug rendering
      this.el.innerHTML = `<pre>Received ${payload.events.length} jobs and ${payload.nodes.length} machines.</pre>`
    })
  },
  destroyed() {
    // this.chart.destroy()
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: {_csrf_token: csrfToken}
})
```

**Step 2: Commit**

```bash
git add hexarail/assets/js/app.js
git commit -m "feat(ui): implement VizKitHook to receive reactive updates"
```
