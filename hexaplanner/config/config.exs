import Config
config :hexaplanner, ecto_repos: [HexaPlanner.Repo]

config :hexaplanner, Oban,
  name: Oban,
  repo: HexaPlanner.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, solver: 16]

config :hexaplanner, HexaPlannerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HexaPlannerWeb.ErrorHTML, json: HexaPlannerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: HexaPlanner.PubSub,
  live_view: [signing_salt: "HEXAPLANNER_SALT_VERY_SECURE"]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
