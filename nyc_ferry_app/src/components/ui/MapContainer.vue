<template>
  <div ref="mapEl" class="absolute inset-0 w-full h-full" />
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import { CARTO_DARK_STYLE, MAP_CENTER, MAP_DEFAULT_ZOOM, FERRY_ROUTE_COLORS } from '../../constants'

const props = defineProps<{
  view: 'system' | 'route'
  selectedRoute?: string
}>()

const mapEl = ref<HTMLDivElement | null>(null)
let map: maplibregl.Map | null = null

onMounted(() => {
  if (!mapEl.value) return

  map = new maplibregl.Map({
    container: mapEl.value,
    style: CARTO_DARK_STYLE,
    center: MAP_CENTER,
    zoom: MAP_DEFAULT_ZOOM,
    attributionControl: false,
  })

  map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'bottom-right')
  map.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-right')

  map.on('load', () => {
    addPlaceholderLayers()
  })
})

onUnmounted(() => {
  map?.remove()
})

function addPlaceholderLayers() {
  if (!map) return

  // Placeholder: add a simple GeoJSON source for route lines (empty for now)
  map.addSource('ferry-routes', {
    type: 'geojson',
    data: {
      type: 'FeatureCollection',
      features: [],
    },
  })

  map.addLayer({
    id: 'ferry-route-lines',
    type: 'line',
    source: 'ferry-routes',
    paint: {
      'line-color': ['get', 'color'],
      'line-width': 3,
      'line-opacity': 0.85,
    },
  })

  map.addSource('ferry-stops', {
    type: 'geojson',
    data: {
      type: 'FeatureCollection',
      features: [],
    },
  })

  map.addLayer({
    id: 'ferry-stop-circles',
    type: 'circle',
    source: 'ferry-stops',
    paint: {
      'circle-radius': 7,
      'circle-color': ['get', 'color'],
      'circle-stroke-width': 2,
      'circle-stroke-color': '#ffffff',
    },
  })
}

watch(
  () => props.selectedRoute,
  (route) => {
    if (!map || !route) return
    // Placeholder: in the future, zoom to the selected route's bounding box
  }
)
</script>
