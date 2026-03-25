defmodule HexaRailWeb.TwinLiveTest do
  use ExUnit.Case
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint HexaRailWeb.Endpoint

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "NEXUS"
    assert render(page_live) =~ "NEXUS"
  end

  test "chaos control panel renders strategy selector and resolves conflict", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    # The Chaos Panel should initially be hidden or inactive
    # We trigger a mock "chaos" event from the system
    send(view.pid, {:chaos_detected, %{trip_id: 9224174, severity: "critical"}})

    # The UI should now show the Chaos Control Panel
    assert render(view) =~ "Chaos Event Detected"
    assert render(view) =~ "TR-9224174"

    # We should be able to select a strategy
    assert render(view) =~ "Salsa (Greedy Incremental)"
    assert render(view) =~ "Local Search (Tabu)"

    # Submitting the resolution form
    html = view 
           |> form("#chaos-resolve-form", strategy: "local_search") 
           |> render_submit()

    assert html =~ "Resolving using Local Search..."
  end
end