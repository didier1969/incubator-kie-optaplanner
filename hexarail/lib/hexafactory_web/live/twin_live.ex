defmodule HexaFactoryWeb.TwinLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "HexaFactory Digital Twin")}
  end
end
