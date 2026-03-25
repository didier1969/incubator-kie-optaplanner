defmodule HexaRailWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :hexarail

  @session_options [
    store: :cookie,
    key: "_hexarail_key",
    signing_salt: "HEXA_SALT"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  # Serve static files from priv/static with explicit app reference for Nix reliability
  plug Plug.Static,
    at: "/",
    from: :hexarail,
    gzip: false,
    only: ~w(css js data favicon.ico robots.txt)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, store: :cookie, key: "_hexarail_key", signing_salt: "HEXA_SALT")
  plug(HexaRailWeb.Router)
end
