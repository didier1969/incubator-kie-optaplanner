defmodule HexaRail.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HexaRail.Repo,
      {Phoenix.PubSub, name: HexaRail.PubSub},
      HexaRailWeb.Endpoint,
      {Oban, Application.fetch_env!(:hexarail, Oban)},
      # Start Horde
      {Horde.Registry, [name: HexaRail.HordeRegistry, keys: :unique]},
      {Horde.DynamicSupervisor, [name: HexaRail.HordeSupervisor, strategy: :one_for_one]},

      # Start the Digital Twin Tick Engine
      HexaRail.Simulation.Engine
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HexaRail.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
