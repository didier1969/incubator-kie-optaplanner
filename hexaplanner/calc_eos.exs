alias HexaPlanner.Repo
alias HexaPlanner.GTFS.{Stop, StopTime}
alias HexaPlanner.SolverNif
import Ecto.Query

Mix.Task.run("app.start")

# 1. Initialize Rust
resource = SolverNif.init_network()

# 2. Load the gares related to DMT and MO
# Fixing the query syntax
stops = Repo.all(from s in Stop, where: ilike(s.original_stop_id, "8500109%") or ilike(s.original_stop_id, "8500105%"))
SolverNif.load_stops(resource, stops)

# 3. Get the legs specifically between these two stations
query = """
SELECT s1.trip_id
FROM gtfs_stop_times s1
JOIN gtfs_stop_times s2 ON s1.trip_id = s2.trip_id AND s2.stop_sequence = s1.stop_sequence + 1
JOIN gtfs_stops st1 ON s1.stop_id = st1.id
JOIN gtfs_stops st2 ON s2.stop_id = st2.id
WHERE (st1.original_stop_id LIKE '8500109%' AND st2.original_stop_id LIKE '8500105%')
   OR (st1.original_stop_id LIKE '8500105%' AND st2.original_stop_id LIKE '8500109%')
"""
{:ok, result} = Repo.query(query)
trip_ids = Enum.map(result.rows, fn [id] -> id end) |> Enum.uniq()

# 4. Load all events for these trips to build the graph
all_trip_events = Repo.all(from st in StopTime, where: st.trip_id in ^trip_ids)
SolverNif.load_stop_times(resource, all_trip_events)

# 5. Finalize the graph in Rust
edge_count = SolverNif.finalize_temporal_graph(resource)

# 6. Count EOS specifically for this track in Rust
# Since we don't have a direct NIF to query count by track name, 
# we know from the logic that each direct leg between DMT and MO 
# in our trips generates 1 EOS in the current 'Gare-Gare' model.
# But if we were at 'Micro-Rail' level (14 segments), it would be 807 * 14.

IO.puts("\n--- Audit Réel STIG : Delémont-Moutier ---")
IO.puts("Nombre de gares/quais chargés (DMT/MO) : #{length(stops)}")
IO.puts("Nombre de trajets (Trips) empruntant ce tronçon : #{length(trip_ids)}")
IO.puts("Nombre de 'Legs' (segments directs) identifiés : #{length(result.rows)}")
IO.puts("\n--- Projection Maestria (Zéro Simplification) ---")
IO.puts("EOS actuels (Niveau Gare-Gare) : #{length(result.rows)}")
IO.puts("EOS cibles (Niveau Micro-Rail, ~14 segments/leg) : #{length(result.rows) * 14}")
IO.puts("-------------------------------------------")
