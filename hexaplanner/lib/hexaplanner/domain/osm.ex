defmodule HexaPlanner.Domain.OsmNode do
  defstruct [:id, :lat, :lon, tags: %{}]
end

defmodule HexaPlanner.Domain.OsmWay do
  defstruct [:id, nodes: [], tags: %{}]
end
