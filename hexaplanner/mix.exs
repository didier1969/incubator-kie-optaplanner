defmodule HexaPlanner.MixProject do
  use Mix.Project

  def project do
    [
      app: :hexaplanner,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {HexaPlanner.Application, []}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "phx.routes": "phx.routes HexaPlannerWeb.Router"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "== 0.35.0"},
      {:oban, "== 2.18.0"},
      {:horde, "== 0.9.0"},
      {:ecto_sql, "== 3.11.1"},
      {:postgrex, "== 0.17.5"},
      {:credo, "== 1.7.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "== 1.4.3", only: [:dev, :test], runtime: false},
      {:phoenix, "== 1.7.11"},
      {:phoenix_html, "== 4.1.1"},
      {:phoenix_live_view, "== 0.20.14"},
      {:jason, "== 1.4.1"},
      {:bandit, "== 1.4.2"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
