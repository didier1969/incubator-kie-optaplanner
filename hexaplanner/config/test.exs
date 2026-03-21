import Config
config :hexaplanner, HexaPlanner.Repo,
  username: "postgres",
  password: "postgres_password",
  hostname: "localhost",
  database: "hexaplanner_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10