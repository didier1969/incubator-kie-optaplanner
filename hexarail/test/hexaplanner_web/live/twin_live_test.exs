# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRailWeb.TwinLiveTest do
  use ExUnit.Case
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint HexaRailWeb.Endpoint

  defmodule FakeEngine do
    def get_status do
      %{
        status: :loading,
        message: "Synthetic boot",
        progress: 42,
        current_time: 9 * 3600,
        resource: :fake
      }
    end

    def pause, do: :ok
    def resume, do: :ok
    def load_scenario(_scenario_data), do: :ok

    def resolve_chaos(strategy) do
      if pid = Application.get_env(:hexarail, :twin_live_test_pid) do
        send(pid, {:resolve_chaos_called, strategy})
      end

      {:ok, strategy}
    end
  end

  setup do
    previous = Application.get_env(:hexarail, :twin_live_engine_module)
    previous_test_pid = Application.get_env(:hexarail, :twin_live_test_pid)

    on_exit(fn ->
      Application.put_env(:hexarail, :twin_live_engine_module, previous)
      Application.put_env(:hexarail, :twin_live_test_pid, previous_test_pid)
    end)

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

  test "mount reflects engine status instead of hardcoded live defaults", %{conn: conn} do
    Application.put_env(:hexarail, :twin_live_engine_module, FakeEngine)

    {:ok, _view, html} = live(conn, "/")

    assert html =~ "Synthetic boot"
    assert html =~ "42%"
  end

  test "resolve chaos delegates to the configured engine module", %{conn: conn} do
    Application.put_env(:hexarail, :twin_live_engine_module, FakeEngine)
    Application.put_env(:hexarail, :twin_live_test_pid, self())

    {:ok, view, _html} = live(conn, "/")

    _html =
      view
      |> render_hook("resolve_chaos", %{"strategy" => "local_search"})

    assert_receive {:resolve_chaos_called, "local_search"}
  end
end
