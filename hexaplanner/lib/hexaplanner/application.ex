defmodule HexaPlanner.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HexaPlanner.Repo,
      {Oban, Application.fetch_env!(:hexaplanner, Oban)},
      {Horde.Registry, [name: HexaPlanner.HordeRegistry, keys: :unique]},
      {Horde.DynamicSupervisor, [name: HexaPlanner.HordeSupervisor, strategy: :one_for_one]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HexaPlanner.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
