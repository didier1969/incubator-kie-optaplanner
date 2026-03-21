import Config
config :hexaplanner, ecto_repos: [HexaPlanner.Repo]
import_config "#{config_env()}.exs"