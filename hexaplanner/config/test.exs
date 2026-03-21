import Config

config :hexaplanner, HexaPlanner.Repo,
  username: "postgres",
  password: "postgres_password",
  hostname: "localhost",
  port: 15432,
  database: "hexaplanner_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :hexaplanner, Oban, testing: :manual

config :hexaplanner, HexaPlannerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 15002],
  secret_key_base: "TEST_SECRET_KEY_BASE_HEXAPLANNER_VERY_LONG",
  server: false
