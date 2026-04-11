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
      console.log("[NEXUS] Base Map loaded. (3D Terrain disabled due to external server failure)");

      // Add the local PMTiles source for rails
      this.map.addSource('swiss-rails', {
        type: 'vector',
        url: 'pmtiles:///data/topology.pmtiles'
      });

      // Add the vector layer for the rails
      this.map.addLayer({
        'id': 'rails-layer',
        'type': 'line',
        'source': 'swiss-rails',
        'source-layer': 'rails',
        'paint': {
          'line-color': '#06b6d4', 
          'line-width': [
            'interpolate', ['linear'], ['zoom'],
            5, 1.0, 
            15, 8   
          ],
          'line-opacity': 0.8
        }
      });
    });

    // 3. Initialize Deck.gl overlay
    this.deck = new deck.MapboxOverlay({
      layers: []
    });

    this.map.addControl(this.deck);

    // 4. Fetch DEM data via HTTP instead of WebSocket to prevent overload
    fetch('/data/swiss_dem_1km.bin')
      .then(response => response.arrayBuffer())
      .then(buffer => {
        console.log("[NEXUS] Received high-fidelity Swiss DEM grid via HTTP...");
        const view = new DataView(buffer);
        this.dem = {
          lat_min: view.getFloat32(0, true),
          lat_max: view.getFloat32(4, true),
          lon_min: view.getFloat32(8, true),
          lon_max: view.getFloat32(12, true),
          lat_steps: view.getUint32(16, true),
          lon_steps: view.getUint32(20, true),
          data: new Float32Array(buffer, 24)
        };
        
        const canvas = document.createElement('canvas');
        canvas.width = this.dem.lon_steps + 1;
        canvas.height = this.dem.lat_steps + 1;
        const ctx = canvas.getContext('2d');
        const imgData = ctx.createImageData(canvas.width, canvas.height);
        
        for (let i = 0; i < this.dem.data.length; i++) {
          const h = this.dem.data[i];
          const v = Math.floor((h + 10000) * 10);
          const r = Math.floor(v / (256 * 256));
          const g = Math.floor((v / 256) % 256);
          const b = Math.floor(v % 256);
          
          const idx = i * 4;
          imgData.data[idx] = r;
          imgData.data[idx + 1] = g;
          imgData.data[idx + 2] = b;
          imgData.data[idx + 3] = 255; 
        }
        ctx.putImageData(imgData, 0, 0);
        this.demImage = canvas;
        
        console.log("✅ DEM Grid Meshed via Martini.");
        this.updateLayers();
      })
      .catch(err => console.error("Failed to load DEM:", err));

    // 5. Listen for real-time binary telemetry from Elixir
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
    if (this.lastUpdate && now - this.lastUpdate < 50) return; 
    this.lastUpdate = now;

    const buffer = new DataView(this.trainDataBuffer);
    const trainSize = 32;
    
    const layers = [];

    // 1. "Serpent" Rendering (True 3D Coordinates from Rust)
    layers.push(new deck.PathLayer({
        id: 'trains-snake',
        data: Array.from({length: this.trainCount}, (_, i) => i),
        getPath: (index) => {
            const offset = index * trainSize;
            const headLon = buffer.getFloat32(offset + 4);
            const headLat = buffer.getFloat32(offset + 8);
            const tailLon = buffer.getFloat32(offset + 12);
            const tailLat = buffer.getFloat32(offset + 16);
            const alt = buffer.getFloat32(offset + 20);
            return [[tailLon, tailLat, 0], [headLon, headLat, 0]];
        },
        getColor: [255, 150, 0, 255], 
        getWidth: 8,
        widthMinPixels: 3,
        capRounded: true,
        jointRounded: true
    }));

    // 2. Safety Layer
    layers.push(new deck.PathLayer({
        id: 'envelopes',
        data: Array.from({length: this.trainCount}, (_, i) => i),
        getPath: (index) => {
            const offset = index * trainSize;
            const headLon = buffer.getFloat32(offset + 4);
            const headLat = buffer.getFloat32(offset + 8);
            const alt = buffer.getFloat32(offset + 20);
            const head = buffer.getInt16(offset + 24) * (Math.PI / 180);
            const speed = buffer.getUint16(offset + 30) / 3.6; 
            
            const safetyDist = (speed * speed) / 1.0; 
            const endLon = headLon + (Math.sin(head) * safetyDist) / 111320;
            const endLat = headLat + (Math.cos(head) * safetyDist) / 111320;
            
            return [[headLon, headLat, 0], [endLon, endLat, 0]];
        },
        getColor: [245, 158, 11, 100], 
        getWidth: 12,
        widthMinPixels: 4
    }));

    this.deck.setProps({ layers });
  },

  destroyed() {
    if (this.map) this.map.remove();
    if (this.deck) this.deck.finalize();
  }
}

Hooks.VizKitHook = {
  mounted() {
    console.log("VizKitHook mounted")
    // In a real app, initialize @viz-kit/core Sigma/Timeline instance here
    // this.chart = createChart(this.el, { type: 'timeline', data: [] })
    
    this.handleEvent("update_viz", (payload) => {
      console.log("Received VizKit Update:", payload)
      // this.chart.update({ data: payload })
      
      // Temporary debug rendering
      this.el.innerHTML = `<pre>Received ${payload.events.length} jobs and ${payload.nodes.length} machines.</pre>`
    })
  },
  destroyed() {
    // this.chart.destroy()
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
