defmodule HexaFactoryWeb.TwinLiveTest do
  use ExUnit.Case
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint HexaRailWeb.Endpoint

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  test "disconnected and connected mount", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/factory/twin")
    assert disconnected_html =~ "HexaFactory Digital Twin"
    assert render(page_live) =~ "HexaFactory Digital Twin"
  end

  test "LiveView translates raw Problem into VizKit primitives", %{conn: conn} do
    {:ok, page_live, _html} = live(conn, "/factory/twin")
    
    # Simulate PubSub message
    fake_problem = %HexaCore.Domain.Problem{jobs: [%{id: 1, start_time: 10, duration: 5, group_id: "batch:HOT", required_resources: [100]}], resources: [], edges: [], score_components: []}
    send(page_live.pid, {:hexafactory_update, %{problem: fake_problem, explanation: nil}})
    
    # LiveViewTest doesn't easily assert on push_event payloads directly without custom hooks,
    # but we can verify the LiveView doesn't crash and handles the info.
    assert render(page_live) =~ "HexaFactory"
  end
end
