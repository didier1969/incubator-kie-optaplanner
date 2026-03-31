# Copyright (c) Didier Stadelmann. All rights reserved.

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

  test "chaos director tolerates partial detected events and marks the panel active", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    send(view.pid, {:chaos_detected, %{trip_id: 9224174, severity: "critical"}})

    html = render(view)
    assert html =~ "Chaos Director"
    assert html =~ "Active"
  end

  test "execute scenario marks chaos director active with injection message", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    html =
      view
      |> element("button[phx-click=\"execute_scenario\"]")
      |> render_click()

    assert html =~ "Chaos Director"
    assert html =~ "Active"
    assert html =~ "Scenario injected."
  end

  test "resolve chaos shows the selected strategy message", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    html =
      view
      |> render_hook("resolve_chaos", %{"strategy" => "local_search"})

    assert html =~ "Resolving using Local Search..."
  end
end
