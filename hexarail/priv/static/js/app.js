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

    // 2. Initialize MapLibre Base Map (Corrected URL for Swisstopo)
    this.map = new maplibregl.Map({
      container: 'deckgl-wrapper',
      style: 'https://vectortiles.geo.admin.ch/styles/ch.swisstopo.basemap.vt/style.json',
      center: [8.2275, 46.8182], 
      zoom: 12, 
      pitch: 60, 
      bearing: 0,
      interactive: true,
      antialias: true
    });

    this.map.on('error', (e) => {
      console.error("[NEXUS] MapLibre Error:", e.error.message);
    });

    this.map.on('load', () => {
      console.log("[NEXUS] Base Map loaded. Activating 3D Volumetric Terrain...");
      
      // Add Terrain-RGB source for 3D extrusion
      this.map.addSource('swiss-terrain', {
        type: 'raster-dem',
        url: 'https://tiles.maplibre.org/terrain-rgb/tiles.json', // Global 30m DEM (Replace with local SwissAlti3D for 0.5m precision)
        tileSize: 256
      });

      this.map.setTerrain({ source: 'swiss-terrain', exaggeration: 1.5 });

      // Add the local PMTiles source for rails
      this.map.addSource('swiss-rails', {
        type: 'vector',
        url: 'pmtiles:///data/topology.pmtiles'
      });

      // Add the vector layer for the rails (Draped on 3D terrain)
      this.map.addLayer({
        'id': 'rails-layer',
        'type': 'line',
        'source': 'swiss-rails',
        'source-layer': 'rails',
        'paint': {
          'line-color': '#06b6d4', // Bright cyan
          'line-width': [
            'interpolate', ['linear'], ['zoom'],
            5, 1.0, 
            15, 8   
          ],
          'line-opacity': 0.8
        }
      });
    });

    // 3. Initialize Deck.gl overlay (The Telemetry)
    this.deck = new deck.MapboxOverlay({
      layers: [] // No GeoJsonLayer here anymore! Only trains.
    });

    this.map.addControl(this.deck);

    // 4. Listen for real-time binary telemetry from Elixir
    this.handleEvent("update_trains_binary", (payload) => {
      // Decode Base64 payload from Elixir
      const binaryString = atob(payload.data);
      const len = binaryString.length;
      const bytes = new Uint8Array(len);
      for (let i = 0; i < len; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }
      const buffer = bytes.buffer;
      const trainSize = 32; // Expanded for Head/Tail coordinates
      const count = buffer.byteLength / trainSize;
      
      this.trainDataBuffer = buffer;
      this.trainCount = count;
      this.updateLayers();
    });
  },

  updateLayers() {
    if (!this.deck || !this.trainDataBuffer) return;

    const now = Date.now();
    if (this.lastUpdate && now - this.lastUpdate < 50) return; // 20 FPS refresh
    this.lastUpdate = now;

    const buffer = new DataView(this.trainDataBuffer);
    const trainSize = 32;
    
    const layers = [
      // Active Layer: "Serpent" Rendering (Curvilinear line tracing the track)
      new deck.PathLayer({
        id: 'trains-snake',
        data: {
          length: this.trainCount,
          attributes: {
            // Path requires an array of points for each train
            // Since we use attributes, we can't easily build nested arrays in zero-copy mode here
            // We use a mapping function for absolute fidelity at a slight CPU cost
          }
        },
        data: Array.from({length: this.trainCount}, (_, i) => i),
        getPath: (index) => {
            const offset = index * trainSize;
            const headLon = buffer.getFloat32(offset + 4);
            const headLat = buffer.getFloat32(offset + 8);
            const tailLon = buffer.getFloat32(offset + 12);
            const tailLat = buffer.getFloat32(offset + 16);
            const alt = buffer.getFloat32(offset + 20);
            return [[tailLon, tailLat, alt], [headLon, headLat, alt]];
        },
        getColor: [255, 150, 0, 255], // Bright Neon Orange
        getWidth: 8,
        widthMinPixels: 3,
        capRounded: true,
        jointRounded: true
      }),

      // Safety Layer: Newtonian Moving Block Envelopes (Dynamic length)
      new deck.PathLayer({
        id: 'envelopes',
        data: Array.from({length: this.trainCount}, (_, i) => i),
        getPath: (index) => {
            const offset = index * trainSize;
            const headLon = buffer.getFloat32(offset + 4);
            const headLat = buffer.getFloat32(offset + 8);
            const alt = buffer.getFloat32(offset + 20);
            const head = buffer.getInt16(offset + 24) * (Math.PI / 180);
            const speed = buffer.getUint16(offset + 30) / 3.6; // m/s
            
            // Safety distance: v^2 / 2a (approx 150m at 80km/h)
            const safetyDist = (speed * speed) / 1.0; 
            const endLon = headLon + (Math.sin(head) * safetyDist) / 111320;
            const endLat = headLat + (Math.cos(head) * safetyDist) / 111320;
            
            return [[headLon, headLat, alt], [endLon, endLat, alt]];
        },
        getColor: [245, 158, 11, 100], // Amber semi-transparent
        getWidth: 12,
        widthMinPixels: 4
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
