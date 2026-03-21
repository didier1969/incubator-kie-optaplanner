defmodule HexaPlanner.GTFS.TripTest do
  use HexaPlanner.DataCase
  alias HexaPlanner.GTFS.Trip

  test "validates required trip fields" do
    changeset = Trip.changeset(%Trip{}, %{})
    assert %{original_trip_id: ["can't be blank"], route_id: ["can't be blank"], service_id: ["can't be blank"]} = errors_on(changeset)
  end
end

defmodule HexaPlanner.GTFS.StopTimeTest do
  use HexaPlanner.DataCase
  alias HexaPlanner.GTFS.StopTime

  test "validates required stop time fields" do
    changeset = StopTime.changeset(%StopTime{}, %{})

    assert %{
             trip_id: ["can't be blank"],
             stop_id: ["can't be blank"],
             arrival_time: ["can't be blank"],
             stop_sequence: ["can't be blank"]
           } = errors_on(changeset)
  end
end

defmodule HexaPlanner.GTFS.TransferTest do
  use HexaPlanner.DataCase
  alias HexaPlanner.GTFS.Transfer

  test "validates required transfer fields" do
    changeset = Transfer.changeset(%Transfer{}, %{})

    assert %{
             from_stop_id: ["can't be blank"],
             to_stop_id: ["can't be blank"],
             transfer_type: ["can't be blank"]
           } = errors_on(changeset)
  end
end
