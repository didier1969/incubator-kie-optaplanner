# Copyright (c) Didier Stadelmann. All rights reserved.

import Config

pg_port = String.to_integer(System.get_env("HEXARAIL_PGPORT", "15432"))
test_port = String.to_integer(System.get_env("HEXARAIL_TEST_PORT", "15002"))

config :hexarail, HexaRail.Repo,
  username: "postgres",
  password: "postgres_password",
  hostname: "localhost",
  port: pg_port,
  database: "hexarail_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :hexarail, Oban, testing: :manual

config :hexarail, HexaRailWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: test_port],
  secret_key_base: "TEST_SECRET_KEY_BASE_HEXAPLANNER_VERY_LONG_MUST_BE_AT_LEAST_64_BYTES_LONG",
  server: false

config :hexarail,
  start_simulation_engine: false
