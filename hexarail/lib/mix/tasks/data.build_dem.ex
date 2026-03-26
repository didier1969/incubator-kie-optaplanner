defmodule Mix.Tasks.Data.BuildDem do
  use Mix.Task
  require Logger

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started(:req)
    
    # Swiss Bounding Box
    lat_min = 45.8
    lat_max = 47.8
    lon_min = 5.9
    lon_max = 10.5
    
    # Grid dimensions (~1km resolution)
    lat_steps = 200
    lon_steps = 460
    
    lat_step_size = (lat_max - lat_min) / lat_steps
    lon_step_size = (lon_max - lon_min) / lon_steps
    
    Logger.info("Building DEM grid: #{lon_steps} x #{lat_steps}...")
    
    grid = 
      for lat_idx <- 0..lat_steps do
        lat = lat_min + lat_idx * lat_step_size
        lons = Enum.map(0..lon_steps, fn lon_idx -> lon_min + lon_idx * lon_step_size end)
        lats = List.duplicate(lat, length(lons))
        
        # Open-Meteo allows max 100 coordinates per request
        coord_pairs = Enum.zip(lats, lons)
        
        row_elevations = 
          coord_pairs
          |> Enum.chunk_every(100)
          |> Enum.flat_map(fn chunk ->
            chunk_lats = Enum.map(chunk, &elem(&1, 0))
            chunk_lons = Enum.map(chunk, &elem(&1, 1))
            
            url = "https://api.open-meteo.com/v1/elevation?latitude=#{Enum.join(chunk_lats, ",")}&longitude=#{Enum.join(chunk_lons, ",")}"
            
            case Req.get!(url, receive_timeout: 60_000) do
              %{status: 200, body: %{"elevation" => elevations}} ->
                Enum.map(elevations, fn
                  nil -> 400.0
                  e -> e * 1.0
                end)
              _ ->
                Logger.error("Failed to fetch chunk at lat #{lat}")
                List.duplicate(400.0, length(chunk))
            end
          end)
        
        # Print progress
        if rem(lat_idx, 10) == 0, do: IO.write(".")
        row_elevations
      end
      
    IO.puts("")
    
    flat_grid = List.flatten(grid)
    binary_data = for el <- flat_grid, into: <<>>, do: <<el::float-32>>
    
    # Header: [lat_min:32f, lat_max:32f, lon_min:32f, lon_max:32f, lat_steps:32u, lon_steps:32u]
    header = <<lat_min::float-32, lat_max::float-32, lon_min::float-32, lon_max::float-32, lat_steps::32, lon_steps::32>>
    
    out_path = Path.join([:code.priv_dir(:hexarail), "data", "swiss_dem_1km.bin"])
    File.mkdir_p!(Path.dirname(out_path))
    File.write!(out_path, header <> binary_data)
    
    Logger.info("✅ Saved Swiss DEM (1km resolution) to #{out_path}")
  end
end
