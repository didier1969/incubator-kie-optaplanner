# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule Mix.Tasks.Hexafactory.Smoke do
  @shortdoc "Runs a reduced-volume HexaFactory end-to-end smoke path"

  use Mix.Task

  alias HexaFactory.CLI

  @impl Mix.Task
  def run(args) do
    CLI.bootstrap_planning_runtime!()

    args
    |> CLI.parse_common_opts(profile: "volumetry_smoke", seed: 1001, iterations: 200)
    |> CLI.solve_dataset()
    |> CLI.print_solve_summary("smoke")
  end
end
