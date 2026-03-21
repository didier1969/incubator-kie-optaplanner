import Config
config :hexaplanner, HexaPlanner.Repo,
  username: "postgres",
  password: "postgres_password",
  hostname: "localhost",
  database: "hexaplanner_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10