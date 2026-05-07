<template>
  <aside class="flex flex-col w-full h-full">

    <!-- Fixed header -->
    <div class="flex-shrink-0 px-5 pt-5 pb-3 flex flex-col gap-3 border-b border-white/10">
      <button
        class="flex items-center gap-1.5 text-sm text-ferry-light-blue hover:text-white transition-colors self-start"
        @click="$emit('back')"
      >
        ← Back
      </button>

      <div class="flex items-start justify-between gap-4">
        <div>
          <h2 class="font-heading text-2xl uppercase tracking-wide text-white">
            {{ activeRoute ?? 'All Routes' }}
          </h2>
          <p class="text-xs text-ferry-light-gray mt-0.5">{{ formattedDate }}</p>
          <p class="text-xs text-ferry-light-gray mt-0.5">{{ temp !== null ? `${temp}°F` : '—' }} · {{ precip !== null ? `${precip}% precip` : '—' }}</p>
        </div>

        <div class="flex rounded-md overflow-hidden border border-white/10 flex-shrink-0">
          <button
            v-for="d in (['SB', 'NB'] as const)"
            :key="d"
            class="px-4 py-1.5 text-xs font-heading uppercase tracking-wider transition-colors"
            :class="direction === d
              ? 'bg-ferry-light-blue text-ferry-dark-blue'
              : 'text-ferry-light-gray hover:text-white'"
            @click="$emit('update:direction', d)"
          >
            {{ d === 'SB' ? '↓ SB' : '↑ NB' }}
          </button>
        </div>
      </div>
    </div>

    <div class="flex flex-col gap-4 flex-1 overflow-y-auto p-5 scrollbar-thin">
      <div class="flex flex-col gap-3">

        <!-- delay risk card -->
        <div class="rounded-lg border p-4 flex flex-col gap-2 transition-colors" :class="cardClass">
          <p class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">
            Delay Risk{{ selectedHour !== null ? ` · ${formatHour(selectedHour)}` : '' }}
          </p>

          <div v-if="predictionLoading" class="flex items-center gap-2">
            <div class="w-4 h-4 rounded-full border-2 border-ferry-light-blue border-t-transparent animate-spin" />
            <p class="text-sm text-ferry-light-gray">Predicting…</p>
          </div>

          <template v-else-if="riskLevel !== null">
            <p class="text-3xl font-heading" :class="labelClass">{{ riskLabel }}</p>
            <div class="w-full h-1.5 rounded-full bg-white/10 mt-1">
              <div
                class="h-1.5 rounded-full transition-all duration-500"
                :class="barClass"
                :style="{ width: `${(delayProbability ?? 0) * 100}%` }"
              />
            </div>
            <p class="text-xs text-ferry-light-gray">
              {{ Math.round((delayProbability ?? 0) * 100) }}% delay probability — {{ riskDescription }}
            </p>
          </template>

          <template v-else>
            <p class="text-3xl font-heading text-white">—</p>
            <p class="text-xs text-ferry-light-gray">Prediction will appear here</p>
          </template>
        </div>

        <!-- hourly curve card -->
        <div class="rounded-lg bg-white/5 border border-white/10 p-4 flex flex-col gap-3">
          <p class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">Risk Throughout the Day</p>

          <div v-if="hourlyLoading" class="flex items-center gap-2">
            <div class="w-4 h-4 rounded-full border-2 border-ferry-light-blue border-t-transparent animate-spin" />
            <p class="text-sm text-ferry-light-gray">Building hourly forecast…</p>
          </div>

          <template v-else-if="filteredCurve.length">
            <svg viewBox="0 0 260 80" class="w-full px-2" xmlns="http://www.w3.org/2000/svg">
              <line x1="0" y1="20" x2="260" y2="20" stroke="rgba(255,255,255,0.05)" stroke-width="1"/>
              <line x1="0" y1="40" x2="260" y2="40" stroke="rgba(255,255,255,0.05)" stroke-width="1"/>
              <line x1="0" y1="60" x2="260" y2="60" stroke="rgba(255,255,255,0.05)" stroke-width="1"/>
              <rect x="0" y="0" width="260" :height="probToY(0.6)" fill="rgba(239,68,68,0.20)" />
              <rect x="0" :y="probToY(0.6)" width="260" :height="probToY(0.3) - probToY(0.6)" fill="rgba(234,179,8,0.20)" />
              <rect x="0" :y="probToY(0.3)" width="260" :height="80 - probToY(0.3)" fill="rgba(34,197,94,0.20)" />
              <path :d="areaPath" fill="rgba(99,179,237,0.15)" />
              <path :d="linePath" fill="none" stroke="#63b3ed" stroke-width="1.5" stroke-linejoin="round" />
              <line
                v-if="selectedHour !== null"
                :x1="hourToX(selectedHour)"
                :x2="hourToX(selectedHour)"
                y1="0"
                y2="80"
                :stroke="selectedLineColor"
                stroke-width="1"
                stroke-dasharray="3 3"
                opacity="0.5"
              />
            </svg>

            <div class="flex flex-col gap-1">
              <input
                type="range"
                :min="curveMinHour"
                :max="curveMaxHour"
                :value="selectedHour ?? curveMinHour"
                step="1"
                class="w-full slider-custom"
                @input="onSliderInput"
              />
              <div class="flex justify-between text-xs text-ferry-light-gray">
                <span>{{ formatHour(curveMinHour) }}</span>
                <span v-if="selectedHour !== null" class="text-white font-medium">{{ formatHour(selectedHour) }}</span>
                <span>{{ formatHour(curveMaxHour) }}</span>
              </div>
            </div>

            <!-- hourly stats card — only shown for a specific route, not All -->
            <div v-if="activeRoute && selectedHour !== null" class="mt-1 rounded-lg bg-white/5 border border-white/10 p-3 flex flex-col gap-2">
              <p class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">{{ formatHour(selectedHour) }} Conditions</p>
              <div class="grid grid-cols-3 gap-2">
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Current GTFS Trips</p>
                  <p class="text-sm font-heading text-white">
                    {{ hourlyStats?.avg_trips !== null ? hourlyStats?.avg_trips : '—' }}
                  </p>
                </div>
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Max Load Factor*</p>
                  <p class="text-sm font-heading" :class="loadFactorClass">
                    {{ hourlyStats?.max_load_factor !== null ? `${(hourlyStats!.max_load_factor! * 100).toFixed(0)}%` : '—' }}
                  </p>
                </div>
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Vessel Capacity*</p>
                  <p class="text-sm font-heading text-white">
                    {{ hourlyStats?.vessel_capacity !== null ? hourlyStats?.vessel_capacity : '—' }}
                  </p>
                </div>
              </div>
            </div>

            <!-- route summary card -->
            <div v-if="routeSummary" class="mt-1 rounded-lg bg-white/5 border border-white/10 p-3 flex flex-col gap-2">
              <p class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">Route Summary</p>
              <div class="grid grid-cols-2 gap-2">
                <div v-if="dailyDelayRiskPct !== null" class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Daily Delay Risk</p>
                  <p
                    class="text-sm font-heading"
                    :class="dailyDelayRiskPct >= 60 ? 'text-red-400' : dailyDelayRiskPct >= 30 ? 'text-yellow-400' : 'text-green-400'"
                  >
                    {{ dailyDelayRiskPct }}%
                  </p>
                </div>
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">High Risk Hrs</p>
                  <p class="text-sm font-heading" :class="highRiskHours > 0 ? 'text-red-400' : 'text-green-400'">
                    {{ highRiskHours }}
                  </p>
                </div>
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Peak Load Factor Hour*</p>
                  <p class="text-sm font-heading text-white">{{ routeSummary.peakHour }}</p>
                </div>
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Avg Trips / Hr*</p>
                  <p class="text-sm font-heading text-white">
                    {{ routeSummary.avgTrips !== null ? routeSummary.avgTrips : '—' }}
                  </p>
                </div>
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Avg Load Factor*</p>
                  <p class="text-sm font-heading" :class="routeSummary.avgLoadClass">
                    {{ `${(routeSummary.avgLoad * 100).toFixed(0)}%` }}
                  </p>
                </div>
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Hrs Onboard Over Capacity*</p>
                  <p class="text-sm font-heading" :class="routeSummary.hoursOverCapacity > 0 ? 'text-red-400' : 'text-green-400'">
                    {{ routeSummary.hoursOverCapacity }}
                  </p>
                </div>
              </div>

              <!-- load factor bar chart -->
              <div v-if="loadChartEntries.length" class="mt-2">
                <p class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray mb-2">Load by Hour</p>
                <svg :viewBox="`0 0 ${loadChartWidth} ${loadChartHeight}`" class="w-full" xmlns="http://www.w3.org/2000/svg">
                  <line
                    x1="0" :y1="loadChartYScale(1.0)"
                    :x2="loadChartWidth" :y2="loadChartYScale(1.0)"
                    stroke="rgba(248,113,113,0.6)" stroke-width="1" stroke-dasharray="3 2"
                  />
                  <g v-for="(entry, i) in loadChartEntries" :key="entry.hour">
                    <rect
                      :x="i * loadChartBarStep"
                      :y="loadChartYScale(entry.lf)"
                      :width="loadChartBarW"
                      :height="loadChartHeight - loadChartPadBottom - loadChartYScale(entry.lf)"
                      :fill="entry.lf > 1.0 ? 'rgba(248,113,113,0.7)' : entry.lf >= 0.9 ? 'rgba(250,204,21,0.5)' : 'rgba(74,222,128,0.4)'"
                      rx="1"
                    />
                    <text
                      :x="i * loadChartBarStep + loadChartBarW / 2"
                      :y="loadChartHeight - 2"
                      text-anchor="middle"
                      font-size="6"
                      fill="rgba(255,255,255,0.4)"
                    >{{ entry.hourLabel }}</text>
                  </g>
                  <text x="1" :y="loadChartYScale(1.0) - 2" font-size="6" fill="rgba(248,113,113,0.8)">100%</text>
                </svg>
                <div v-if="overCapacityHours.length" class="mt-1 flex flex-wrap gap-1">
                  <p class="text-xs text-ferry-light-gray w-full">Over capacity:</p>
                  <span
                    v-for="h in overCapacityHours" :key="h"
                    class="text-xs bg-red-500/20 text-red-400 rounded px-1.5 py-0.5"
                  >{{ formatHour(h) }}</span>
                </div>
                <p v-if="overCapacityHours.length" class="text-xs text-ferry-light-gray mt-1">
                  *Based on same-week data from last year (±2 weeks).
                </p>
                <p v-else class="text-xs text-green-400 mt-1">No hours over capacity</p>
              </div>
            </div>

          </template>
        </div>

      </div>
    </div>

    <!-- tabs -->
    <div v-if="routes?.length" class="border-t border-white/10 bg-ferry-dark-blue/80 flex overflow-x-auto">
      <button
        class="flex-shrink-0 px-3 py-3 text-xs font-heading uppercase tracking-wider transition-colors border-b-2"
        :class="activeRoute === null ? 'text-white border-ferry-light-blue' : 'text-ferry-light-gray border-transparent hover:text-white'"
        @click="activeRoute = null"
      >All</button>
      <button
        v-for="r in routes" :key="r"
        class="flex-shrink-0 px-3 py-3 text-xs font-heading uppercase tracking-wider transition-colors border-b-2 whitespace-nowrap"
        :class="activeRoute === r ? 'text-white border-ferry-light-blue' : 'text-ferry-light-gray border-transparent hover:text-white'"
        @click="activeRoute = r"
      >{{ r }}</button>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'

const TRIPS_URL = 'https://raw.githubusercontent.com/kakumanus/musa-8010-nycedc/refs/heads/main/nyc_ferry_app/public/gtfs/trips.txt'
const STOP_TIMES_URL = 'https://raw.githubusercontent.com/kakumanus/musa-8010-nycedc/refs/heads/main/nyc_ferry_app/public/gtfs/stop_times.txt'

// route_id → daytype → hour → direction_id → trip count
const gtfsTripsPerHour = ref<Record<string, Record<string, Record<number, Record<number, number>>>>>({})

async function loadGtfsStats() {
  const [tripsText, stopTimesText, calendarText] = await Promise.all([
    fetch(TRIPS_URL).then(r => r.text()),
    fetch(STOP_TIMES_URL).then(r => r.text()),
    fetch('https://raw.githubusercontent.com/kakumanus/musa-8010-nycedc/refs/heads/main/nyc_ferry_app/public/gtfs/calendar.txt').then(r => r.text()),
  ])

  const serviceType: Record<string, 'WEEKDAY' | 'WEEKEND'> = {}
  for (const line of calendarText.trim().split('\n').slice(1)) {
    const cols = line.split(',')
    const service_id = cols[0].trim()
    const monday = cols[1].trim()
    serviceType[service_id] = monday === '1' ? 'WEEKDAY' : 'WEEKEND'
  }

  const tripInfo: Record<string, { route_id: string; daytype: string; direction_id: number }> = {}

  for (const line of tripsText.trim().split('\n').slice(1)) {
    const cols = line.split(',')
    const route_id = cols[0].replace(/"/g, '').trim()
    const service_id = cols[1].replace(/"/g, '').trim()
    const trip_id = cols[2].replace(/"/g, '').trim()
    const direction_id = parseInt(cols[5]?.trim() ?? '0')
    const daytype = serviceType[service_id] ?? 'WEEKDAY'
    tripInfo[trip_id] = { route_id, daytype, direction_id }
  }

  const counts: Record<string, Record<string, Record<number, Record<number, Set<string>>>>> = {}

  for (const line of stopTimesText.trim().split('\n').slice(1)) {
    const cols = line.split(',')
    const trip_id = cols[0].trim()
    const departure = cols[2].trim()
    const stop_sequence = parseInt(cols[4].trim())
    if (stop_sequence !== 1) continue
    const hour = parseInt(departure.split(':')[0])
    if (hour < 5 || hour > 22) continue
    const info = tripInfo[trip_id]
    if (!info) continue
    const { route_id, daytype, direction_id } = info
    if (!counts[route_id]) counts[route_id] = {}
    if (!counts[route_id][daytype]) counts[route_id][daytype] = {}
    if (!counts[route_id][daytype][hour]) counts[route_id][daytype][hour] = {}
    if (!counts[route_id][daytype][hour][direction_id]) counts[route_id][daytype][hour][direction_id] = new Set()
    counts[route_id][daytype][hour][direction_id].add(trip_id)
  }

  const result: Record<string, Record<string, Record<number, Record<number, number>>>> = {}
  for (const route in counts) {
    result[route] = {}
    for (const daytype in counts[route]) {
      result[route][daytype] = {}
      for (const hour in counts[route][daytype]) {
        result[route][daytype][parseInt(hour)] = {}
        for (const dir in counts[route][daytype][parseInt(hour)]) {
          result[route][daytype][parseInt(hour)][parseInt(dir)] =
            counts[route][daytype][parseInt(hour)][parseInt(dir)].size
        }
      }
    }
  }
  gtfsTripsPerHour.value = result
  emitActiveHours()
}

onMounted(() => {
  loadGtfsStats()
  loadFerryData()
})

const ROUTE_NAME_MAP: Record<string, string> = {
  'Astoria': 'AS',
  'East River': 'ER',
  'Gouverneur Island': 'GI',
  'Rockaway': 'RR',
  'Rockaway Wave': 'RW',
  'Rockaway-Soundview': 'RS',
  'South Brooklyn': 'SB',
  'St. George': 'SG',
  'Soundview': 'SV',
}

const FERRY_LOAD_URL = 'https://raw.githubusercontent.com/kakumanus/musa-8010-nycedc/refs/heads/main/nyc_ferry_app/public/ferry_load_data.json'

const allLoadData = ref<{ route_id: string; date: string; hour: number; max_load_factor: number; vessel_capacity: number }[]>([])

async function loadFerryData() {
  const res = await fetch(FERRY_LOAD_URL)
  const data = await res.json()
  console.log('loaded rows:', data.length)
  console.log('sample row:', data[0])
  allLoadData.value = data
}

function getWindowDates(inputDate: string): Set<string> {
  const [month, day, year] = inputDate.split('/').map(Number)
  const target = new Date(year, month - 1, day)
  const anchor = new Date(target)
  anchor.setFullYear(anchor.getFullYear() - 1)

  const dates = new Set<string>()
  for (let offset = -14; offset <= 14; offset++) {
    const d = new Date(anchor)
    d.setDate(d.getDate() + offset)
    if (d.getDay() === target.getDay()) {
      dates.add(d.toISOString().split('T')[0])
    }
  }
  return dates
}

const HOURLY_STATS = computed(() => {
  if (!props.date || !allLoadData.value.length) return {}
  const window = getWindowDates(props.date)

  const result: Record<string, Record<number, { max_load_factor: number; vessel_capacity: number }>> = {}
  for (const row of allLoadData.value) {
    if (!window.has(row.date)) continue
    if (!result[row.route_id]) result[row.route_id] = {}
    const existing = result[row.route_id][row.hour]
    if (!existing || row.max_load_factor > existing.max_load_factor) {
      result[row.route_id][row.hour] = {
        max_load_factor: row.max_load_factor,
        vessel_capacity: row.vessel_capacity,
      }
    }
  }

  const RR = result['RR'] ?? {}
  const SV = result['SV'] ?? {}
  const allHours = new Set([...Object.keys(RR), ...Object.keys(SV)].map(Number))
  result['RS'] = {}
  for (const hour of allHours) {
    const rrEntry = RR[hour]
    const svEntry = SV[hour]
    if (rrEntry && svEntry) {
      result['RS'][hour] = {
        max_load_factor: (rrEntry.max_load_factor + svEntry.max_load_factor) / 2,
        vessel_capacity: Math.round((rrEntry.vessel_capacity + svEntry.vessel_capacity) / 2),
      }
    } else if (rrEntry) {
      result['RS'][hour] = { ...rrEntry }
    } else if (svEntry) {
      result['RS'][hour] = { ...svEntry }
    }
  }

  return result
})

const props = defineProps<{
  route?: string
  date?: string
  routes?: string[]
  temp?: number | null
  precip?: number | null
  direction?: string
  riskLevel?: 'low' | 'medium' | 'high' | null
  delayProbability?: number | null
  predictionLoading?: boolean
  hourlyCurve?: { hour: number; probability: number; risk: string }[]
  hourlyLoading?: boolean
}>()

const emit = defineEmits<{
  back: []
  'update:activeRoute': [route: string | null]
  'update:selectedHour': [hour: number]
  'update:activeHours': [hours: number[]]
  'update:dailyRisk': [risk: { level: 'low' | 'medium' | 'high'; probability: number }]
}>()

const activeRoute = ref<string | null>(props.routes?.[0] ?? null)
const selectedHour = ref<number | null>(null)

const CHART_W = 260
const CHART_H = 80

// helper: which route IDs to aggregate over
const activeRouteIds = computed(() => {
  if (activeRoute.value) return [ROUTE_NAME_MAP[activeRoute.value] ?? activeRoute.value]
  return (props.routes ?? []).map(r => ROUTE_NAME_MAP[r] ?? r)
})

// helper: get weekday/weekend type from the selected date
function getDaytype(): 'WEEKDAY' | 'WEEKEND' {
  if (!props.date) return 'WEEKDAY'
  const [month, day, year] = props.date.split('/').map(Number)
  const dow = new Date(year, month - 1, day).getDay()
  return (dow === 0 || dow === 6) ? 'WEEKEND' : 'WEEKDAY'
}

// helper: direction_id key — NB = 1, SB = 0
const dirKey = computed(() => props.direction === 'NB' ? 1 : 0)

// Hours where this route actually has trips for this direction + daytype
const activeHours = computed(() => {
  const ids = activeRouteIds.value
  const daytype = getDaytype()
  const hourSet = new Set<number>()
  for (const id of ids) {
    const byHour = gtfsTripsPerHour.value[id]?.[daytype]
    if (!byHour) continue
    for (const [h, byDir] of Object.entries(byHour)) {
      if ((byDir[dirKey.value] ?? 0) > 0) hourSet.add(parseInt(h))
    }
  }
  if (!hourSet.size) return [5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22]
  return Array.from(hourSet).sort((a, b) => a - b)
})

function emitActiveHours() {
  emit('update:activeHours', activeHours.value)
}

// Filter the incoming hourly curve to only hours this route actually operates
const filteredCurve = computed(() => {
  if (!props.hourlyCurve?.length) return []
  const hourSet = new Set(activeHours.value)
  return props.hourlyCurve.filter(p => hourSet.has(p.hour))
})

const curveMinHour = computed(() => filteredCurve.value[0]?.hour ?? 5)
const curveMaxHour = computed(() => filteredCurve.value[filteredCurve.value.length - 1]?.hour ?? 22)

function hourToX(hour: number): number {
  if (curveMaxHour.value === curveMinHour.value) return 0
  return ((hour - curveMinHour.value) / (curveMaxHour.value - curveMinHour.value)) * CHART_W
}

function probToY(prob: number): number {
  return CHART_H - prob * CHART_H
}

const linePath = computed(() => {
  if (!filteredCurve.value.length) return ''
  return filteredCurve.value
    .map((p, i) => `${i === 0 ? 'M' : 'L'}${hourToX(p.hour).toFixed(1)},${probToY(p.probability).toFixed(1)}`)
    .join(' ')
})

const areaPath = computed(() => {
  if (!filteredCurve.value.length) return ''
  const line = filteredCurve.value
    .map((p, i) => `${i === 0 ? 'M' : 'L'}${hourToX(p.hour).toFixed(1)},${probToY(p.probability).toFixed(1)}`)
    .join(' ')
  const first = filteredCurve.value[0]
  const last = filteredCurve.value[filteredCurve.value.length - 1]
  return `${line} L${hourToX(last.hour).toFixed(1)},${CHART_H} L${hourToX(first.hour).toFixed(1)},${CHART_H} Z`
})

const selectedLineColor = computed(() => {
  const point = filteredCurve.value.find(p => p.hour === selectedHour.value)
  if (!point) return '#63b3ed'
  if (point.risk === 'high') return '#f87171'
  if (point.risk === 'medium') return '#facc15'
  return '#4ade80'
})

const hourlyStats = computed(() => {
  if (selectedHour.value === null) return null
  const ids = activeRouteIds.value

  const entries = ids
    .map(id => HOURLY_STATS.value[id]?.[selectedHour.value!])
    .filter(Boolean) as { max_load_factor: number; vessel_capacity: number }[]

  const daytype = getDaytype()
  const trips = ids.reduce((sum, id) =>
    sum + (gtfsTripsPerHour.value[id]?.[daytype]?.[selectedHour.value!]?.[dirKey.value] ?? 0), 0)

  return {
    max_load_factor: entries.length ? Math.max(...entries.map(e => e.max_load_factor)) : null,
    vessel_capacity: entries.length ? Math.round(entries.reduce((s, e) => s + e.vessel_capacity, 0) / entries.length) : null,
    avg_trips: trips || null,
  }
})

const highRiskHours = computed(() => {
  if (!filteredCurve.value.length) return 0
  return filteredCurve.value.filter(p => p.probability >= 0.6).length
})

// Average probability across all active hours — used for popup and Route Summary card
const dailyDelayRiskPct = computed(() => {
  if (!filteredCurve.value.length) return null
  const avg = filteredCurve.value.reduce((sum, p) => sum + p.probability, 0) / filteredCurve.value.length
  return Math.round(avg * 100)
})

// Emit daily risk up to parent whenever it changes so the popup stays in sync
watch(dailyDelayRiskPct, (val) => {
  if (val === null) return
  const level = val >= 60 ? 'high' : val >= 30 ? 'medium' : 'low'
  emit('update:dailyRisk', { level, probability: val / 100 })
})

const routeSummary = computed(() => {
  const ids = activeRouteIds.value
  if (!ids.length) return null

  const hourMap: Record<number, { lfSum: number; count: number }> = {}
  for (const id of ids) {
    const stats = HOURLY_STATS.value[id]
    if (!stats) continue
    for (const [h, v] of Object.entries(stats)) {
      const hour = parseInt(h)
      if (!hourMap[hour]) hourMap[hour] = { lfSum: 0, count: 0 }
      hourMap[hour].lfSum += v.max_load_factor
      hourMap[hour].count++
    }
  }

  const hourEntries = Object.entries(hourMap).map(([h, { lfSum, count }]) => ({
    hour: parseInt(h),
    avgLf: lfSum / count,
  }))

  if (!hourEntries.length) return null

  const peak = hourEntries.reduce((a, b) => a.avgLf >= b.avgLf ? a : b)
  const peakHour = formatHour(peak.hour)
  const hoursOverCapacity = hourEntries.filter(e => e.avgLf > 1.0).length
  const avgLoad = hourEntries.reduce((sum, e) => sum + e.avgLf, 0) / hourEntries.length
  const avgLoadClass = avgLoad >= 1.1 ? 'text-red-400' : avgLoad >= 0.9 ? 'text-yellow-400' : 'text-green-400'

  const daytype = getDaytype()
  const totalTrips = ids.reduce((sum, id) => {
    const byHour = gtfsTripsPerHour.value[id]?.[daytype]
    return sum + (byHour
      ? Object.values(byHour).reduce((s, byDir) => s + (byDir[dirKey.value] ?? 0), 0)
      : 0)
  }, 0)
  const totalHours = ids.reduce((sum, id) => {
    const byHour = gtfsTripsPerHour.value[id]?.[daytype]
    return sum + (byHour ? Object.keys(byHour).length : 0)
  }, 0)
  const avgTrips = totalHours > 0 ? Math.round(totalTrips / totalHours) : null

  return { peakHour, hoursOverCapacity, avgLoad, avgLoadClass, avgTrips }
})

const loadChartPadBottom = 12
const loadChartHeight = 80

const loadChartEntries = computed(() => {
  const ids = activeRouteIds.value
  const hourMap: Record<number, { lfSum: number; count: number }> = {}
  for (const id of ids) {
    const stats = HOURLY_STATS.value[id]
    if (!stats) continue
    for (const [h, v] of Object.entries(stats)) {
      const hour = parseInt(h)
      if (!hourMap[hour]) hourMap[hour] = { lfSum: 0, count: 0 }
      hourMap[hour].lfSum += v.max_load_factor
      hourMap[hour].count++
    }
  }
  return Object.entries(hourMap)
    .map(([h, { lfSum, count }]) => {
      const hour = parseInt(h)
      return {
        hour,
        lf: lfSum / count,
        hourLabel: hour < 12 ? `${h}a` : hour === 12 ? '12p' : `${hour - 12}p`,
      }
    })
    .sort((a, b) => a.hour - b.hour)
})

const loadChartBarStep = computed(() => {
  const n = loadChartEntries.value.length
  return n > 0 ? 240 / n : 14
})

const loadChartBarW = computed(() => Math.max(loadChartBarStep.value - 2, 4))
const loadChartWidth = computed(() => loadChartEntries.value.length * loadChartBarStep.value)

const maxLF = computed(() => {
  if (!loadChartEntries.value.length) return 1.5
  return Math.max(1.5, ...loadChartEntries.value.map(e => e.lf))
})

function loadChartYScale(lf: number): number {
  const drawH = loadChartHeight - loadChartPadBottom
  return drawH - (lf / maxLF.value) * drawH
}

const overCapacityHours = computed(() => {
  return loadChartEntries.value
    .filter(e => e.lf > 1.0)
    .map(e => e.hour)
    .sort((a, b) => a - b)
})

const loadFactorClass = computed(() => {
  if (!hourlyStats.value || hourlyStats.value.max_load_factor === null) return 'text-white'
  const lf = hourlyStats.value.max_load_factor
  if (lf >= 1.1) return 'text-red-400'
  if (lf >= 0.9) return 'text-yellow-400'
  return 'text-green-400'
})

function onSliderInput(e: Event) {
  const hour = Number((e.target as HTMLInputElement).value)
  selectedHour.value = hour
  emit('update:selectedHour', hour)
}

function formatHour(hour: number): string {
  if (hour === 12) return '12 PM'
  if (hour < 12) return `${hour} AM`
  return `${hour - 12} PM`
}

const formattedDate = computed(() => {
  if (!props.date) return '—'
  const [month, day, year] = props.date.split('/')
  if (!month || !day || !year) return props.date
  const d = new Date(+year, +month - 1, +day)
  return d.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })
})

const cardClass = computed(() => {
  if (props.predictionLoading || props.riskLevel === null) return 'bg-white/5 border-white/10'
  if (props.riskLevel === 'high')   return 'bg-red-500/10 border-red-500/30'
  if (props.riskLevel === 'medium') return 'bg-yellow-500/10 border-yellow-500/30'
  return 'bg-green-500/10 border-green-500/30'
})

const labelClass = computed(() => {
  if (props.riskLevel === 'high')   return 'text-red-400'
  if (props.riskLevel === 'medium') return 'text-yellow-400'
  if (props.riskLevel === 'low')    return 'text-green-400'
  return 'text-white'
})

const barClass = computed(() => {
  if (props.riskLevel === 'high')   return 'bg-red-400'
  if (props.riskLevel === 'medium') return 'bg-yellow-400'
  return 'bg-green-400'
})

const riskLabel = computed(() => {
  if (props.riskLevel === 'high')   return 'High Risk'
  if (props.riskLevel === 'medium') return 'Medium Risk'
  if (props.riskLevel === 'low')    return 'Low Risk'
  return '—'
})

const riskDescription = computed(() => {
  if (props.riskLevel === 'high')   return 'Significant delays likely.'
  if (props.riskLevel === 'medium') return 'Some delays possible.'
  return 'Normal operations expected.'
})

watch(activeRoute, (val) => {
  emit('update:activeRoute', val)
  emitActiveHours()
}, { immediate: true })

watch(() => props.routes, (val) => { activeRoute.value = val?.[0] ?? null })

watch(() => props.direction, () => { emitActiveHours() })

watch(() => props.date, () => { emitActiveHours() })

watch(activeHours, () => { emitActiveHours() })

watch(() => props.hourlyCurve, (val) => {
  if (val?.length) {
    const firstActive = filteredCurve.value[0]?.hour ?? val[0].hour
    selectedHour.value = firstActive
  }
})
</script>

<style scoped>
.overflow-y-auto::-webkit-scrollbar {
  width: 4px;
}

.overflow-y-auto::-webkit-scrollbar-track {
  background: transparent;
}

.overflow-y-auto::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.15);
  border-radius: 999px;
}

.overflow-y-auto::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3);
}

.overflow-y-auto {
  scrollbar-width: thin;
  scrollbar-color: rgba(255, 255, 255, 0.15) transparent;
}

.slider-custom {
  -webkit-appearance: none;
  appearance: none;
  width: 100%;
  height: 4px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.15);
  outline: none;
  cursor: pointer;
}

.slider-custom::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  background: #63b3ed;
  border: 2px solid white;
  cursor: pointer;
  transition: background 0.2s;
}

.slider-custom::-webkit-slider-thumb:hover {
  background: #90cdf4;
}

.slider-custom::-moz-range-thumb {
  width: 14px;
  height: 14px;
  border-radius: 50%;
  background: #63b3ed;
  border: 2px solid white;
  cursor: pointer;
}
</style>