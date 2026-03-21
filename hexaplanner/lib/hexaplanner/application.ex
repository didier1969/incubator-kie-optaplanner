defmodule HexaPlanner.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HexaPlanner.Repo,
      {Horde.Registry, [name: HexaPlanner.HordeRegistry, keys: :unique]},
      {Horde.DynamicSupervisor, [name: HexaPlanner.HordeSupervisor, strategy: :one_for_one]}
      # Oban will be added to the children here in the DB setup phase.
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HexaPlanner.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
