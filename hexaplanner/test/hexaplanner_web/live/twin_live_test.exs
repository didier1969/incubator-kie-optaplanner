defmodule HexaPlannerWeb.TwinLiveTest do
  use ExUnit.Case
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint HexaPlannerWeb.Endpoint

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "HexaPlanner Mission Control"
    assert render(page_live) =~ "HexaPlanner Mission Control"
  end
end
