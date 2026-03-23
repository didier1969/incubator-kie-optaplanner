import Config

config :hexaplanner, HexaPlanner.Repo,
  username: "postgres",
  password: "postgres_password",
  hostname: "localhost",
  port: 15432,
  database: "hexaplanner_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :hexaplanner, HexaPlannerWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 14326],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "PiiZbjmfXB+lImOtLRo/PrbL26vc633oVPbVHgWlBc5Xh6EaOARSmVwcgVz7l2AvfecA7aw3x/qdnlUKbUefXRDtF7WRP1uKWbN6wp6z/uD0rDnI/l6ac52sIGDN1H5V"
