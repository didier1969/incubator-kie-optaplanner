defmodule Mix.Tasks.Data.BuildDem do
  use Mix.Task
  require Logger

  @impl Mix.Task
  def run(_args) do
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
    
    Logger.info("Building Procedural DEM grid (No API): #{lon_steps} x #{lat_steps}...")
    
    # Generate a complex procedural terrain (Swiss Alps approximation)
    grid = 
      for lat_idx <- 0..lat_steps do
        lat = lat_min + lat_idx * lat_step_size
        for lon_idx <- 0..lon_steps do
          lon = lon_min + lon_idx * lon_step_size
          
          # Base altitude (Swiss plateau ~400m)
          base = 400.0
          
          # Alps (South-East) get higher. Jura (North-West) gets smaller bumps.
          alps_factor = max(0.0, 47.0 - lat) * max(0.0, lon - 7.0) * 1000.0
          
          wave1 = :math.sin(lon * 15.0) * 300.0
          wave2 = :math.cos(lat * 20.0) * 200.0
          wave3 = :math.sin((lon + lat) * 50.0) * 50.0
          
          elevation = base + alps_factor + wave1 + wave2 + wave3
          max(200.0, min(4000.0, elevation))
        end
      end
      
    flat_grid = List.flatten(grid)
    binary_data = for el <- flat_grid, into: <<>>, do: <<el::float-32>>
    
    # Header: [lat_min:32f, lat_max:32f, lon_min:32f, lon_max:32f, lat_steps:32u, lon_steps:32u]
    header = <<lat_min::float-32, lat_max::float-32, lon_min::float-32, lon_max::float-32, lat_steps::32, lon_steps::32>>
    
    out_path = Path.join([:code.priv_dir(:hexarail), "data", "swiss_dem_1km.bin"])
    File.mkdir_p!(Path.dirname(out_path))
    File.write!(out_path, header <> binary_data)
    
    Logger.info("✅ Saved Procedural Swiss DEM (1km resolution) to #{out_path}")
  end
end
