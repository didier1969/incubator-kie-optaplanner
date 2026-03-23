// Nexus Control Plane - High Performance WebGL Surface
// Using MapLibre for geographic context and PMTiles, and Deck.gl for spatial telemetry
let Hooks = {}

Hooks.DeckGLMap = {
  mounted() {
    console.log("[NEXUS] Initializing Tactical Surface with Vector Tiles...");
    
    this.trains = [];

    // 1. Initialize PMTiles Protocol for MapLibre
    let protocol = new pmtiles.Protocol();
    maplibregl.addProtocol("pmtiles", protocol.tile);

    // 2. Initialize MapLibre Base Map (The Geography + PMTiles Rails)
    this.map = new maplibregl.Map({
      container: 'deckgl-wrapper',
      style: 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
      center: [8.2275, 46.8182], // Center of Switzerland
      zoom: 7.2, 
      pitch: 0, 
      bearing: 0,
      interactive: true,
      antialias: true
    });

    this.map.on('load', () => {
      console.log("[NEXUS] Base Map loaded. Injecting PMTiles Layer...");
      // Add the local PMTiles source
      this.map.addSource('swiss-rails', {
        type: 'vector',
        url: 'pmtiles:///data/topology.pmtiles'
      });

      // Add the vector layer for the rails
      this.map.addLayer({
        'id': 'rails-layer',
        'type': 'line',
        'source': 'swiss-rails',
        'source-layer': 'rails', // This is the layer name we set in tippecanoe (-l rails)
        'paint': {
          'line-color': '#64748b', // Lighter slate for standard map
          'line-width': [
            'interpolate', ['linear'], ['zoom'],
            5, 0.5, // At zoom 5, line width is 0.5px
            15, 6   // At zoom 15, line width is 6px
          ]
        }
      });
      console.log("[NEXUS] PMTiles Layer active. 20MB GeoJSON successfully bypassed.");
    });

    // 3. Initialize Deck.gl overlay (The Telemetry)
    this.deck = new deck.MapboxOverlay({
      layers: [] // No GeoJsonLayer here anymore! Only trains.
    });

    this.map.addControl(this.deck);

    // 4. Listen for real-time telemetry from Elixir
    this.handleEvent("update_trains", (payload) => {
      this.trains = payload.positions.map(p => ({
        id: p[0],
        position: [p[1], p[2]]
      }));
      this.updateLayers();
    });
  },

  updateLayers() {
    if (!this.deck) return;

    const layers = [
      // Active Layer: Moving Trains (STIG)
      new deck.ScatterplotLayer({
        id: 'trains',
        data: this.trains,
        pickable: true,
        opacity: 0.85,
        stroked: true,
        filled: true,
        radiusUnits: 'meters',
        getRadius: 100, // Train occupies ~100 meters of physical space
        radiusMinPixels: 1.5, // From space, it's just a tiny dot
        radiusMaxPixels: 30, // When zoomed in, it scales up physically
        lineWidthMinPixels: 0.5,
        getPosition: d => d.position,
        getFillColor: d => [217, 119, 6], // amber-600
        getLineColor: [255, 255, 255]
      })
    ];

    this.deck.setProps({ layers });
  },

  destroyed() {
    if (this.map) this.map.remove();
    if (this.deck) this.deck.finalize();
  }
}

// Global LiveView Ignition
window.onload = () => {
  console.log("[NEXUS] Ignition...");
  let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
  let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {
    params: {_csrf_token: csrfToken},
    hooks: Hooks
  });
  
  liveSocket.connect();
  window.liveSocket = liveSocket;
};
