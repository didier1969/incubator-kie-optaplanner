defmodule HexaPlannerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :hexaplanner

  @session_options [
    store: :cookie,
    key: "_hexaplanner_key",
    signing_salt: "HEXA_SALT"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], pass: ["*/*"], json_decoder: Phoenix.json_library()
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, store: :cookie, key: "_hexaplanner_key", signing_salt: "HEXA_SALT"
  plug HexaPlannerWeb.Router
end
