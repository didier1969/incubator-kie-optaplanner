# Copyright (c) Didier Stadelmann. All rights reserved.

import Config

pg_port = String.to_integer(System.get_env("HEXARAIL_PGPORT", "15432"))
web_port = String.to_integer(System.get_env("HEXARAIL_WEB_PORT", System.get_env("PORT", "14326")))

config :hexarail, HexaRail.Repo,
  username: "postgres",
  password: "postgres_password",
  hostname: "localhost",
  port: pg_port,
  database: "hexarail_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :hexarail, HexaRailWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: web_port],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "PiiZbjmfXB+lImOtLRo/PrbL26vc633oVPbVHgWlBc5Xh6EaOARSmVwcgVz7l2AvfecA7aw3x/qdnlUKbUefXRDtF7WRP1uKWbN6wp6z/uD0rDnI/l6ac52sIGDN1H5V"
