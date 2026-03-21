import Config
config :hexaplanner, ecto_repos: [HexaPlanner.Repo]

config :hexaplanner, Oban,
  name: Oban,
  repo: HexaPlanner.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, solver: 16]

import_config "#{config_env()}.exs"