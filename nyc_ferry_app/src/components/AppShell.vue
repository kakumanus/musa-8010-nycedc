<template>
  <div class="relative w-full h-full">
    <MapContainer
      ref="mapRef"
      :view="view"
      :selected-route="selectedRoute"
      :selected-routes="selectedRoutes"
      :active-tab-route="activeTabRoute"
      @update:selected-routes="selectedRoutes = $event"
      @update:all-routes="allRoutes = $event"
    />

    <div
      :class="[
        'absolute top-4 bottom-4 left-4 z-10 flex flex-col rounded-lg overflow-hidden bg-ferry-dark-blue/90 backdrop-blur-sm border border-white/10 shadow-xl transition-[width] duration-300',
        view === 'route' ? 'w-[640px]' : 'w-80',
      ]"
    >
      <Transition name="sidebar" mode="out-in">
        <SidebarResults
          v-if="view === 'route'"
          :route="selectedRoute"
          :date="selectedDate"
          :routes="selectedRoutes.length ? selectedRoutes : allRoutes"
          :temp="savedForm.temp"
          :precip="savedForm.precip"
          :direction="activeDirection"
          :risk-level="riskLevel"
          :delay-probability="delayProbability"
          :prediction-loading="predictionLoading"
          :hourly-curve="hourlyCurve"
          :hourly-loading="hourlyLoading"
          @update:active-route="activeTabRoute = $event"
          @update:selected-hour="onHourSelected"
          @update:direction="onDirectionToggle"
          @back="goToSystem"
        />
        <SidebarInput
          v-else
          :selected-routes="selectedRoutes"
          :all-routes="allRoutes"
          :saved-form="savedForm"
          @update:selected-routes="selectedRoutes = $event"
          @update:saved-form="savedForm = $event"
          @submit="handleSystemSubmit"
        />
      </Transition>
    </div>

    <!-- methodology overlay -->
    <Transition name="overlay">
      <div
        v-if="showMethodology"
        class="absolute inset-0 z-30 bg-ferry-dark-blue/95 backdrop-blur-sm overflow-y-auto p-10"
      >
        <button
          class="flex items-center gap-1.5 text-sm text-ferry-light-blue hover:text-white transition-colors mb-6"
          @click="showMethodology = false"
        >
          ← Close
        </button>

        <div class="max-w-2xl mx-auto flex flex-col gap-6 text-ferry-light-gray">
          <h1 class="font-heading text-4xl uppercase tracking-wide text-white">Methodology</h1>

          <div class="flex flex-col gap-2">
            <h2 class="font-heading text-lg uppercase tracking-wider text-white">Overview</h2>
            <p class="text-sm leading-relaxed">
              Add your methodology text here. Explain how the delay risk model works,
              what data sources are used, and how predictions are generated.
            </p>
          </div>

          <div class="flex flex-col gap-2">
            <h2 class="font-heading text-lg uppercase tracking-wider text-white">Data Sources</h2>
            <p class="text-sm leading-relaxed">
              Describe your data sources here.
            </p>
          </div>

          <div class="flex flex-col gap-2">
            <h2 class="font-heading text-lg uppercase tracking-wider text-white">Model</h2>
            <p class="text-sm leading-relaxed">
              Describe your model here.
            </p>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, onMounted } from 'vue'
import MapContainer from './ui/MapContainer.vue'
import SidebarInput from './sections/SidebarInput.vue'
import SidebarResults from './sections/SidebarResults.vue'
import { getSeasonFromDate, getDaytypeFromDate, getLookupDefaults } from './predictionlookup.js'
import { loadCache, lookupPrediction } from './predictionCache'

type View = 'system' | 'route'
type RiskLevel = 'low' | 'medium' | 'high' | null

const HOURS = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]

const view = ref<View>('system')
const selectedRoute = ref<string | undefined>(undefined)
const selectedDate = ref<string | undefined>(undefined)
const selectedRoutes = ref<string[]>([])
const allRoutes = ref<string[]>([])
const activeTabRoute = ref<string | null>(null)
const activeDirection = ref<'NB' | 'SB'>('SB')
const showMethodology = ref(false)
const mapRef = ref<InstanceType<typeof MapContainer> | null>(null)
const riskLevel = ref<RiskLevel>(null)
const delayProbability = ref<number | null>(null)
const predictionLoading = ref(false)
const hourlyCurve = ref<{ hour: number; probability: number; risk: string }[]>([])
const hourlyLoading = ref(false)

const savedForm = ref({
  date: '',
  temp: null as number | null,
  precip: null as number | null,
})

const ROUTE_NAME_MAP: Record<string, string> = {
  'Astoria': 'AS',
  'East River': 'ER',
  'Gouverneur Island': 'GI',
  'Rockaway': 'RR',
  'Rockaway Wave': 'RW',
  'South Brooklyn': 'SB',
  'St. George': 'SG',
  'Soundview': 'SV',
}

// To switch to a live hosted API, restore fetchPrediction() calls in
// handleSystemSubmit and onHourSelected, and update the URL below to your
// deployed R Plumber endpoint (e.g. https://your-app.onrender.com/predict).
//
// let lastPayload: Record<string, unknown> | null = null
//
// async function fetchPrediction(payload: Record<string, unknown>) {
//   const res = await fetch('http://localhost:8000/predict', {
//     method: 'POST',
//     headers: { 'Content-Type': 'application/json' },
//     body: JSON.stringify(payload),
//   })
//   return res.json()
// }

onMounted(async () => { await loadCache() })

// Shared helper — runs main prediction + full hourly curve for the given inputs.
// Called on initial submit and again whenever the direction toggle changes.
function runPredictions(routeId: string, direction: string, season: string, daytype: string, temp: number, precip: number) {
  riskLevel.value = null
  delayProbability.value = null
  hourlyCurve.value = []

  const defaults   = getLookupDefaults(routeId, direction, season, daytype)
  const medianHour = Math.round(defaults.prev_stop_sched_hour ?? 13)

  const main = lookupPrediction(routeId, direction, season, daytype, temp, precip, medianHour)
  riskLevel.value       = main.risk_level as 'low' | 'medium' | 'high'
  delayProbability.value = main.delay_probability

  hourlyCurve.value = HOURS.map(hour => {
    const r = lookupPrediction(routeId, direction, season, daytype, temp, precip, hour)
    return { hour, probability: r.delay_probability, risk: r.risk_level }
  })

  // --- API version (restore for live hosted deployment) ---
  // predictionLoading.value = true
  // try {
  //   const data = await fetchPrediction({ ...payload })
  //   riskLevel.value = data.risk_level
  //   delayProbability.value = data.delay_probability
  // } catch (err) { console.error('Prediction API error:', err)
  // } finally { predictionLoading.value = false }
  // hourlyLoading.value = true
  // try {
  //   const results = await Promise.all(
  //     HOURS.map(hour =>
  //       fetchPrediction({ ...payload, prev_stop_sched_hour_override: hour })
  //         .then(d => ({ hour, probability: d.delay_probability, risk: d.risk_level }))
  //         .catch(() => ({ hour, probability: 0, risk: 'low' }))
  //     )
  //   )
  //   hourlyCurve.value = results
  // } catch (err) { console.error('Hourly curve error:', err)
  // } finally { hourlyLoading.value = false }
}

function handleSystemSubmit(values: {
  route: string
  routes: string[]
  date: string
  temp: number | null
  precip: number | null
}) {
  selectedRoute.value = values.routes[0] ?? values.route ?? undefined
  selectedDate.value  = values.date
  view.value          = 'route'
  mapRef.value?.fitToRoutes(values.routes, 680)

  const season  = getSeasonFromDate(values.date)
  const daytype = getDaytypeFromDate(values.date)
  const fullName = values.routes[0] ?? values.route ?? ''
  const routeId  = ROUTE_NAME_MAP[fullName] ?? fullName ?? 'ER'

  runPredictions(routeId, activeDirection.value, season, daytype, values.temp ?? 60, values.precip ?? 0)
}

function onDirectionToggle(direction: 'NB' | 'SB') {
  activeDirection.value = direction
  if (view.value !== 'route' || !savedForm.value.date) return
  const season  = getSeasonFromDate(savedForm.value.date)
  const daytype = getDaytypeFromDate(savedForm.value.date)
  const routeName = activeTabRoute.value ?? selectedRoute.value ?? ''
  const routeId = (ROUTE_NAME_MAP[routeName] ?? routeName) || 'ER'
  runPredictions(routeId, direction, season, daytype, savedForm.value.temp ?? 60, savedForm.value.precip ?? 0)
}

function onHourSelected(hour: number) {
  if (!selectedRoute.value || !savedForm.value.date) return
  const season  = getSeasonFromDate(savedForm.value.date)
  const daytype = getDaytypeFromDate(savedForm.value.date)
  const routeId = ROUTE_NAME_MAP[selectedRoute.value] ?? selectedRoute.value ?? 'ER'
  const result  = lookupPrediction(routeId, activeDirection.value, season, daytype, savedForm.value.temp ?? 60, savedForm.value.precip ?? 0, hour)
  riskLevel.value        = result.risk_level as 'low' | 'medium' | 'high'
  delayProbability.value = result.delay_probability

  // --- API version (restore for live hosted deployment) ---
  // if (!lastPayload) return
  // try {
  //   const data = await fetchPrediction({ ...lastPayload, prev_stop_sched_hour_override: hour })
  //   riskLevel.value = data.risk_level
  //   delayProbability.value = data.delay_probability
  // } catch (err) { console.error('Hour prediction error:', err) }
}

watch(activeTabRoute, (val) => {
  if (view.value !== 'route') return
  const targets = val ? [val] : (selectedRoutes.value.length ? selectedRoutes.value : allRoutes.value)
  mapRef.value?.fitToRoutes(targets, 680)
})

function goToSystem() {
  view.value = 'system'
  selectedRoute.value = undefined
  activeTabRoute.value = null
  riskLevel.value = null
  delayProbability.value = null
  hourlyCurve.value = []
  // lastPayload = null  // restore when switching back to API mode
  mapRef.value?.resetView()
}
</script>

<style>
.sidebar-enter-active,
.sidebar-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.sidebar-enter-from {
  opacity: 0;
  transform: translateX(-8px);
}
.sidebar-leave-to {
  opacity: 0;
  transform: translateX(-8px);
}
.overlay-enter-active,
.overlay-leave-active {
  transition: opacity 0.2s ease;
}
.overlay-enter-from,
.overlay-leave-to {
  opacity: 0;
}
</style>

