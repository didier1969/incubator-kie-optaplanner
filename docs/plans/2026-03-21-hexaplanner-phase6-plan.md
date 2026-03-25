# HexaRail Phase 6 Implementation Plan: The Phoenix LiveView Dashboard

> **For Claude/Gemini:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a real-time web dashboard using Phoenix LiveView. This dashboard will display the current state of a Digital Twin (Problem) and provide a button to trigger the Rust optimization engine asynchronously, showing the updated (optimized) state immediately without page reloads.

**Architecture:** User Browser <-> WebSockets <-> Phoenix LiveView <-> Elixir Control Plane <-> Rustler NIF.

**Tech Stack:** Elixir, Phoenix, Phoenix LiveView, HTML/Tailwind.

---

### Task 1: Scaffold the Phoenix Web Interface

Since our project was initially generated as a standard supervisor app (`mix new --sup`), we will inject Phoenix into it to avoid a complex umbrella restructuring for this MVP.

**Files:**
- Modify: `hexarail/mix.exs`
- Create: `hexarail/lib/hexarail_web/endpoint.ex`
- Create: `hexarail/lib/hexarail_web/router.ex`
- Modify: `hexarail/lib/hexarail/application.ex`
- Modify: `hexarail/config/config.exs`
- Modify: `hexarail/config/dev.exs`

**Step 1: Write the failing check**

Run: `nix develop -c bash -c "cd hexarail && mix phx.routes"`
Expected: FAIL (Phoenix not installed or router missing)

**Step 2: Write minimal implementation**

1. Add Phoenix dependencies to `hexarail/mix.exs`:
```elixir
{:phoenix, "== 1.7.11"},
{:phoenix_html, "== 4.1.1"},
{:phoenix_live_view, "== 0.20.14"},
{:jason, "== 1.4.1"},
{:bandit, "== 1.4.2"}
```
2. Download deps: `mix deps.get`
3. Configure Phoenix in `config/config.exs`:
```elixir
config :hexarail, HexaRailWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HexaRailWeb.ErrorHTML, json: HexaRailWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: HexaRail.PubSub,
  live_view: [signing_salt: "HEXAPLANNER_SALT_VERY_SECURE"]

config :phoenix, :json_library, Jason
```
4. Configure dev endpoint in `config/dev.exs`:
```elixir
config :hexarail, HexaRailWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "DEV_SECRET_KEY_BASE_HEXAPLANNER"
```
5. Create `lib/hexarail_web/endpoint.ex`:
```elixir
defmodule HexaRailWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :hexarail

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], pass: ["*/*"], json_decoder: Phoenix.json_library()
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, store: :cookie, key: "_hexarail_key", signing_salt: "HEXA_SALT"
  plug HexaRailWeb.Router
end
```
6. Create `lib/hexarail_web/router.ex`:
```elixir
defmodule HexaRailWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HexaRailWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", HexaRailWeb do
    pipe_through :browser
  end
end
```
7. Start it in `lib/hexarail/application.ex` (add these to children):
```elixir
{Phoenix.PubSub, name: HexaRail.PubSub},
HexaRailWeb.Endpoint
```

**Step 3: Run check to verify it passes**

Run: `nix develop -c bash -c "cd hexarail && mix phx.routes"`
Expected: PASS (It will show no routes, but the command succeeds, proving Phoenix is alive).

**Step 4: Commit**

```bash
git add hexarail/
git commit -m "feat(ui): integrate phoenix and bandit into control plane"
```

---

### Task 2: Create the HTML Layouts and Error Handlers

**Files:**
- Create: `hexarail/lib/hexarail_web/components/layouts/root.html.hex`
- Create: `hexarail/lib/hexarail_web/components/layouts.ex`
- Create: `hexarail/lib/hexarail_web/controllers/error_html.ex`
- Create: `hexarail/lib/hexarail_web/controllers/error_json.ex`

**Step 1: Write the failing check**

The application won't compile completely until layouts and error modules defined in `config.exs` exist.
Run: `nix develop -c bash -c "cd hexarail && mix compile"`
Expected: FAIL (Missing ErrorHTML, Layouts)

**Step 2: Write minimal implementation**

1. `lib/hexarail_web/controllers/error_html.ex`:
```elixir
defmodule HexaRailWeb.ErrorHTML do
  use Phoenix.Component
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
```
2. `lib/hexarail_web/controllers/error_json.ex`:
```elixir
defmodule HexaRailWeb.ErrorJSON do
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
```
3. `lib/hexarail_web/components/layouts.ex`:
```elixir
defmodule HexaRailWeb.Layouts do
  use Phoenix.Component
  embed_templates "layouts/*"
end
```
4. `lib/hexarail_web/components/layouts/root.html.hex`:
```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>HexaRail Digital Twin</title>
    <!-- Minimal CDN Tailwind for the MVP -->
    <script src="https://cdn.tailwindcss.com"></script>
    <!-- LiveView Client JS logic (simplified for MVP) -->
    <script defer src="https://cdn.jsdelivr.net/npm/phoenix@1.7.11/priv/static/phoenix.min.js"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/phoenix_live_view@0.20.14/priv/static/phoenix_live_view.min.js"></script>
    <script>
      window.addEventListener("DOMContentLoaded", () => {
        let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket);
        liveSocket.connect();
      });
    </script>
  </head>
  <body class="bg-gray-900 text-white antialiased">
    <%= @inner_content %>
  </body>
</html>
```

**Step 3: Run check to verify it passes**

Run: `nix develop -c bash -c "cd hexarail && mix compile"`
Expected: PASS

**Step 4: Commit**

```bash
git add hexarail/
git commit -m "feat(ui): add core phoenix layouts and error handlers"
```

---

### Task 3: The LiveView Dashboard & Rust Optimization Trigger

**Files:**
- Create: `hexarail/lib/hexarail_web/live/twin_live.ex`
- Modify: `hexarail/lib/hexarail_web/router.ex`

**Step 1: Write the failing check**

Run: `nix develop -c bash -c "cd hexarail && curl -s http://localhost:4000/"` (We need to start the server in background or use a test).
For simplicity, we'll write a Phoenix route test:
Create `hexarail/test/hexarail_web/live/twin_live_test.exs`:
```elixir
defmodule HexaRailWeb.TwinLiveTest do
  use ExUnit.Case
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint HexaRailWeb.Endpoint

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "HexaRail Mission Control"
    assert render(page_live) =~ "HexaRail Mission Control"
  end
end
```
Run test. Expected: FAIL (No route)

**Step 2: Write minimal implementation**

1. Update `lib/hexarail_web/router.ex` to serve the LiveView:
```elixir
  scope "/", HexaRailWeb do
    pipe_through :browser
    live "/", TwinLive
  end
```

2. Create `lib/hexarail_web/live/twin_live.ex`:
```elixir
defmodule HexaRailWeb.TwinLive do
  use Phoenix.LiveView
  alias HexaRail.Domain.{Problem, Job}
  alias HexaRail.SolverNif

  def mount(_params, _session, socket) do
    # Initialize a dummy Digital Twin state
    problem = %Problem{
      id: "Factory_A",
      resources: [],
      jobs: [
        %Job{id: 101, duration: 45, required_resources: [], start_time: nil},
        %Job{id: 102, duration: 30, required_resources: [], start_time: nil}
      ]
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
        <h1 class="text-3xl font-bold text-emerald-400">HexaRail Mission Control</h1>
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
```

**Step 3: Run check to verify it passes**

Run: `nix develop -c bash -c "cd hexarail && mix test test/hexarail_web/live/twin_live_test.exs"`
Expected: PASS

Run Quality Gates: `nix develop -c bash -c "cd hexarail && mix credo --strict"`

**Step 4: Commit**

```bash
git add hexarail/
git commit -m "feat(ui): implement real-time liveview dashboard connected to rust optimizer"
```