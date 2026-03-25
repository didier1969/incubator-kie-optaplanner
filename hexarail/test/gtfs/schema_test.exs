defmodule HexaRail.GTFS.TripTest do
  use HexaRail.DataCase
  alias HexaRail.GTFS.Trip

  test "validates required trip fields" do
    changeset = Trip.changeset(%Trip{}, %{})

    assert %{
             original_trip_id: ["can't be blank"],
             route_id: ["can't be blank"],
             service_id: ["can't be blank"]
           } = errors_on(changeset)
  end
end

defmodule HexaRail.GTFS.StopTimeTest do
  use HexaRail.DataCase
  alias HexaRail.GTFS.StopTime

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

defmodule HexaRail.GTFS.TransferTest do
  use HexaRail.DataCase
  alias HexaRail.GTFS.Transfer

  test "validates required transfer fields" do
    changeset = Transfer.changeset(%Transfer{}, %{})

    assert %{
             from_stop_id: ["can't be blank"],
             to_stop_id: ["can't be blank"],
             transfer_type: ["can't be blank"]
           } = errors_on(changeset)
  end
end
