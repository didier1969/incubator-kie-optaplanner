import Config
config :hexarail, ecto_repos: [HexaRail.Repo]

config :hexarail, HexaRail.Repo, types: HexaRail.PostgresTypes

config :hexarail, Oban,
  name: Oban,
  repo: HexaRail.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, solver: 16]

config :hexarail, HexaRailWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HexaRailWeb.ErrorHTML, json: HexaRailWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: HexaRail.PubSub,
  live_view: [signing_salt: "HEXAPLANNER_SALT_VERY_SECURE"]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
