import Config

config :hexaplanner, HexaPlanner.Repo,
  username: "postgres",
  password: "postgres_password",
  hostname: "localhost",
  database: "hexaplanner_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :hexaplanner, HexaPlannerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "DEV_SECRET_KEY_BASE_HEXAPLANNER"
