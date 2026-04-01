# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule Mix.Tasks.Hexafactory.TasksTest do
  use HexaRail.DataCase, async: false

  import ExUnit.CaptureIO

  setup do
    Mix.Task.reenable("hexafactory.generate")
    Mix.Task.reenable("hexafactory.persist")
    Mix.Task.reenable("hexafactory.solve")
    :ok
  end

  test "generate task prints a deterministic dataset summary" do
    output =
      capture_io(fn ->
        Mix.Tasks.Hexafactory.Generate.run([
          "--profile",
          "smoke",
          "--seed",
          "42"
        ])
      end)

    assert output =~ "HexaFactory generate"
    assert output =~ "profile=smoke"
    assert output =~ "plants=2"
    assert output =~ "machines=6"
    assert output =~ "signature="
  end

  test "persist task stores a planning horizon snapshot and prints its reference" do
    output =
      capture_io(fn ->
        Mix.Tasks.Hexafactory.Persist.run([
          "--profile",
          "smoke",
          "--seed",
          "43"
        ])
      end)

    assert output =~ "HexaFactory persist"
    assert output =~ "profile=smoke"
    assert output =~ "dataset_ref="
    assert output =~ "signature="
  end

  test "solve task runs the persisted industrial path and prints a solver summary" do
    output =
      capture_io(fn ->
        Mix.Tasks.Hexafactory.Solve.run([
          "--profile",
          "volumetry_smoke",
          "--seed",
          "44",
          "--iterations",
          "96"
        ])
      end)

    assert output =~ "HexaFactory solve"
    assert output =~ "profile=volumetry_smoke"
    assert output =~ "dataset_ref="
    assert output =~ "late_jobs="
    assert output =~ "setup_minutes="
  end
end
