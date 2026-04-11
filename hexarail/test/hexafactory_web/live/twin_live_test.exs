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
end
