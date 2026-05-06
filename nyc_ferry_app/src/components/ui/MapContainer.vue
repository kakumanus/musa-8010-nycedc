<template>
  <div ref="mapEl" class="absolute inset-0 w-full h-full" />
  <!-- reset view button -->
  <button
    class="absolute top-2.5 right-12 z-10 bg-white rounded shadow px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-100"
    @click="resetView"
  >
    Reset
  </button>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import { CARTO_DARK_STYLE, MAP_CENTER, MAP_DEFAULT_ZOOM } from '../../constants'

const props = defineProps<{
  view: 'system' | 'route'
  selectedRoute?: string
  selectedRoutes?: string[]
  activeTabRoute?: string | null
}>()

const emit = defineEmits<{
  'update:selectedRoutes': [routes: string[]]
  'update:allRoutes': [routes: string[]]
}>()

const mapEl = ref<HTMLDivElement | null>(null)
let map: maplibregl.Map | null = null

// ─── dropdown state ───────────────────────────────────────────────────────────

const search = ref('')
const showDropdown = ref(false)
const selectedRoutes = ref<string[]>([])
const allRoutes = ref<string[]>([])

const filteredRoutes = computed(() =>
  allRoutes.value.filter(r =>
    r.toLowerCase().includes(search.value.toLowerCase())
  )
)

// sync from sidebar selections
watch(
  () => props.selectedRoutes,
  (val) => {
    if (val) {
      selectedRoutes.value = [...val]
      updateHighlight()
    }
  },
  { deep: true }
)

// highlight active tab route
watch(
  () => props.activeTabRoute,
  (val) => {
    if (!map) return
    const ids = val ? [val] : selectedRoutes.value

    map.setPaintProperty('ferry-route-lines', 'line-width', [
      'case',
      ['in', ['get', 'long_name'], ['literal', ids]],
      5,
      2,
    ])
    map.setPaintProperty('ferry-route-lines', 'line-opacity', [
      'case',
      ['in', ['get', 'long_name'], ['literal', ids]],
      1,
      ids.length ? 0.2 : 0.85,
    ])
  }
)

function toggleRoute(long_name: string) {
  if (selectedRoutes.value.includes(long_name)) {
    selectedRoutes.value = selectedRoutes.value.filter(id => id !== long_name)
  } else {
    selectedRoutes.value = [...selectedRoutes.value, long_name]
    search.value = ''
    showDropdown.value = false
  }
  updateHighlight()
  emit('update:selectedRoutes', selectedRoutes.value)
}

function onClickOutside(e: MouseEvent) {
  if (!(e.target as HTMLElement).closest('.relative')) {
    showDropdown.value = false
  }
}

// ─── lifecycle ────────────────────────────────────────────────────────────────

onMounted(() => {
  if (!mapEl.value) return

  document.addEventListener('click', onClickOutside)

  map = new maplibregl.Map({
    container: mapEl.value,
    style: CARTO_DARK_STYLE,
    center: MAP_CENTER,
    zoom: MAP_DEFAULT_ZOOM,
    attributionControl: false,
  })

  map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right')
  map.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-right')

  map.on('load', async () => {
    addLayers()
    await loadData()
  })
})

onUnmounted(() => {
  map?.remove()
  document.removeEventListener('click', onClickOutside)
})

// ─── per-route line offsets (pixels, perpendicular to line direction) ─────────
// Positive = right of travel direction, negative = left.
// Adjust these values to taste — routes sharing a corridor will spread apart.
const ROUTE_LINE_OFFSET: maplibregl.ExpressionSpecification = [
  'match', ['get', 'route_id'],
  'ER',  0,
  'SG',  0,
  'SB',  0,
  'AS',  0,
  'RS',  0,
  'GI',  0,
  'SV',  0,
  0  // default
]

// ─── layers ───────────────────────────────────────────────────────────────────

function addLayers() {
  if (!map) return

  map.addSource('ferry-routes', {
    type: 'geojson',
    data: { type: 'FeatureCollection', features: [] },
  })

  map.addLayer({
    id: 'ferry-route-lines-hitbox',
    type: 'line',
    source: 'ferry-routes',
    paint: {
      'line-color': 'transparent',
      'line-width': 20,
      'line-offset': ROUTE_LINE_OFFSET,
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
      'line-offset': ROUTE_LINE_OFFSET,
    },
  })

  map.addSource('ferry-stops', {
    type: 'geojson',
    data: { type: 'FeatureCollection', features: [] },
  })

  map.addLayer({
    id: 'ferry-stop-circles',
    type: 'circle',
    source: 'ferry-stops',
    paint: {
      'circle-radius': ['case', ['>', ['get', 'route_count'], 1], 7, 5],
      'circle-color': ['case', ['>', ['get', 'route_count'], 1], '#ffffff', ['get', 'route_color']],
      'circle-stroke-width': ['case', ['>', ['get', 'route_count'], 1], 2, 1],
      'circle-stroke-color': ['case', ['>', ['get', 'route_count'], 1], '#aaaaaa', '#ffffff'],
    },
  })

  map.addLayer({
    id: 'ferry-stop-circles-hitbox',
    type: 'circle',
    source: 'ferry-stops',
    paint: {
      'circle-radius': 15,
      'circle-color': 'transparent',
    },
  })

  // ─── stop hover popup ──────────────────────────────────────────────────────

  const stopPopup = new maplibregl.Popup({
    closeButton: false,
    closeOnClick: false,
    offset: 10,
  })

  const ROUTE_COLORS: Record<string, string> = {
    ER: '#228B9D',
    RS: '#AD1AAC',
    SB: '#FFD100',
    AS: '#FE5000',
    SV: '#4E008E',
    SG: '#D0006F',
    GI: '#9893A0',
  }

  map.on('mousemove', 'ferry-stop-circles-hitbox', (e) => {
    const props = e.features?.[0]?.properties
    if (!props?.stop_name) return

    // route_info is serialized as a JSON string by sf — parse it to get all route IDs
    let routeIds: string[] = []
    try {
      routeIds = JSON.parse(props.route_info).route_id ?? []
    } catch {}

    const badges = routeIds
      .map(id => {
        const color = ROUTE_COLORS[id] ?? '#888888'
        // Use dark text on yellow (SB), white on everything else
        const textColor = id === 'SB' ? '#000000' : '#ffffff'
        return `<span style="background:${color};color:${textColor};padding:1px 6px;border-radius:3px;font-size:11px;font-weight:600;">${id}</span>`
      })
      .join(' ')

    map!.getCanvas().style.cursor = 'pointer'
    stopPopup
      .setLngLat((e.features![0].geometry as GeoJSON.Point).coordinates as [number, number])
      .setHTML(`<div style="display:flex;flex-direction:column;gap:4px;">
        <span style="font-weight:600;">${props.stop_name}</span>
        <div style="display:flex;gap:4px;flex-wrap:wrap;">${badges}</div>
      </div>`)
      .addTo(map!)
  })

  map.on('mouseleave', 'ferry-stop-circles-hitbox', () => {
    map!.getCanvas().style.cursor = ''
    stopPopup.remove()
  })

  map.on('mouseenter', 'ferry-route-lines-hitbox', () => map!.getCanvas().style.cursor = 'pointer')
  map.on('mouseleave', 'ferry-route-lines-hitbox', () => map!.getCanvas().style.cursor = '')

  map.on('click', 'ferry-route-lines-hitbox', (e) => {
    const long_name = e.features?.[0]?.properties?.long_name
    if (long_name) toggleRoute(long_name)
  })
}

// ─── data ─────────────────────────────────────────────────────────────────────

async function loadData() {
  const base      = import.meta.env.BASE_URL.replace(/\/$/, '')
  const routeUrl  = `${base}/routes_processed.geojson`
  const stopUrl   = `${base}/landings_processed.geojson`

  const [routes, stops] = await Promise.all([
    fetch(routeUrl).then(r => r.json()),
    fetch(stopUrl).then(r => r.json()),
  ])

  ;(map?.getSource('ferry-routes') as maplibregl.GeoJSONSource)?.setData(routes)
  ;(map?.getSource('ferry-stops') as maplibregl.GeoJSONSource)?.setData(stops)

  allRoutes.value = [...new Set(
    routes.features.map((f: GeoJSON.Feature) => f.properties?.long_name).filter(Boolean)
  )]
  emit('update:allRoutes', allRoutes.value)
}

// ─── highlight ────────────────────────────────────────────────────────────────

function updateHighlight() {
  if (!map) return
  const ids = selectedRoutes.value

  map.setPaintProperty('ferry-route-lines', 'line-width', [
    'case',
    ['in', ['get', 'long_name'], ['literal', ids]],
    5,
    2,
  ])
  map.setPaintProperty('ferry-route-lines', 'line-opacity', [
    'case',
    ['in', ['get', 'long_name'], ['literal', ids]],
    1,
    ids.length ? 0.25 : 0.85,
  ])
}

// ─── reset view ───────────────────────────────────────────────────────────────

function resetView() {
  map?.flyTo({ center: MAP_CENTER, zoom: MAP_DEFAULT_ZOOM })
}

// ─── expose ───────────────────────────────────────────────────────────────────

defineExpose({
  fitToRoutes(routeNames: string[], leftPadding = 60) {
    if (!map) return
    const source = map.getSource('ferry-routes') as maplibregl.GeoJSONSource
    const data = (source as any)._data as GeoJSON.FeatureCollection<GeoJSON.LineString>
    if (!data?.features.length) return

    const matched = routeNames.length
      ? data.features.filter(f => routeNames.includes(f.properties?.long_name))
      : data.features

    const allCoords = matched.flatMap(f => f.geometry.coordinates) as [number, number][]
    if (!allCoords.length) return

    const bounds = allCoords.reduce(
      (b, c) => b.extend(c),
      new maplibregl.LngLatBounds(allCoords[0], allCoords[0])
    )
    map.fitBounds(bounds, { padding: { top: 60, bottom: 60, left: leftPadding, right: 60 } })
  },
  resetView,
})
</script>

<style>
.maplibregl-popup-content {
  background: rgba(10, 20, 40, 0.9) !important;
  color: white !important;
  padding: 6px 10px !important;
  border-radius: 6px !important;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4) !important;
  font-size: 12px !important;
  font-weight: 500 !important;
}
.maplibregl-popup-tip {
  display: none !important;
}
</style>