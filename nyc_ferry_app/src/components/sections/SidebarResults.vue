<template>
  <aside class="flex flex-col w-full h-full">
    <div class="flex flex-col gap-4 flex-1 overflow-y-auto p-5 scrollbar-thin">
      <button
        class="flex items-center gap-1.5 text-sm text-ferry-light-blue hover:text-white transition-colors"
        @click="$emit('back')"
      >
        ← Back
      </button>

      <div>
        <h2 class="font-heading text-2xl uppercase tracking-wide text-white">
          {{ activeRoute ?? 'All Routes' }}
        </h2>
        <p class="text-xs text-ferry-light-gray mt-0.5">{{ formattedDate }}</p>
        <p class="text-xs text-ferry-light-gray mt-0.5">Direction: {{ direction === 'NB' ? 'Northbound' : 'Southbound' }}</p>
        <p class="text-xs text-ferry-light-gray mt-0.5">Temperature: {{ temp !== null ? `${temp}°F` : '—' }}</p>
        <p class="text-xs text-ferry-light-gray mt-0.5">Precipitation: {{ precip !== null ? `${precip}%` : '—' }}</p>
      </div>

      <!-- direction toggle -->
      <div class="flex rounded-md overflow-hidden border border-white/10 self-start">
        <button
          v-for="d in (['SB', 'NB'] as const)"
          :key="d"
          class="px-4 py-1.5 text-xs font-heading uppercase tracking-wider transition-colors"
          :class="direction === d
            ? 'bg-ferry-light-blue text-ferry-dark-blue'
            : 'text-ferry-light-gray hover:text-white'"
          @click="direction = d"
        >
          {{ d === 'SB' ? '↓ Southbound' : '↑ Northbound' }}
        </button>
      </div>

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

          <template v-else-if="hourlyCurve.length">
            <svg viewBox="0 0 260 80" class="w-full" xmlns="http://www.w3.org/2000/svg">
              <line x1="0" y1="20" x2="260" y2="20" stroke="rgba(255,255,255,0.05)" stroke-width="1"/>
              <line x1="0" y1="40" x2="260" y2="40" stroke="rgba(255,255,255,0.05)" stroke-width="1"/>
              <line x1="0" y1="60" x2="260" y2="60" stroke="rgba(255,255,255,0.05)" stroke-width="1"/>
              <rect x="0" y="0" width="260" :height="probToY(0.6)" fill="rgba(239,68,68,0.05)" />
              <rect x="0" :y="probToY(0.6)" width="260" :height="probToY(0.3) - probToY(0.6)" fill="rgba(234,179,8,0.05)" />
              <rect x="0" :y="probToY(0.3)" width="260" :height="80 - probToY(0.3)" fill="rgba(34,197,94,0.05)" />
              <path :d="areaPath" fill="rgba(99,179,237,0.15)" />
              <path :d="linePath" fill="none" stroke="#63b3ed" stroke-width="1.5" stroke-linejoin="round" />
              <circle
                v-if="selectedHour !== null"
                :cx="hourToX(selectedHour)"
                :cy="probToY(hourlyCurve.find(p => p.hour === selectedHour)?.probability ?? 0)"
                r="4"
                :fill="selectedDotColor"
                stroke="white"
                stroke-width="1.5"
              />
            </svg>

            <div class="flex flex-col gap-1">
              <input
                type="range"
                :min="hourlyCurve[0].hour"
                :max="hourlyCurve[hourlyCurve.length - 1].hour"
                :value="selectedHour ?? hourlyCurve[0].hour"
                step="1"
                class="w-full slider-custom"
                @input="onSliderInput"
              />
              <div class="flex justify-between text-xs text-ferry-light-gray">
                <span>6 AM</span>
                <span v-if="selectedHour !== null" class="text-white font-medium">{{ formatHour(selectedHour) }}</span>
                <span>10 PM</span>
              </div>
            </div>

            <!-- hourly stats card -->
            <div v-if="selectedHour !== null && hourlyStats" class="mt-1 rounded-lg bg-white/5 border border-white/10 p-3 flex flex-col gap-2">
              <p class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">{{ formatHour(selectedHour) }} Conditions</p>
              <div class="grid grid-cols-3 gap-2">
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Trips</p>
                  <p class="text-sm font-heading text-white">
                    {{ hourlyStats.avg_trips !== null ? hourlyStats.avg_trips : '—' }}
                  </p>
                </div>
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Max Load</p>
                  <p class="text-sm font-heading" :class="loadFactorClass">
                    {{ hourlyStats.max_load_factor !== null ? `${(hourlyStats.max_load_factor * 100).toFixed(0)}%` : '—' }}
                  </p>
                </div>
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Vessel</p>
                  <p class="text-sm font-heading text-white">
                    {{ hourlyStats.vessel_capacity !== null ? hourlyStats.vessel_capacity : '—' }}
                  </p>
                </div>
              </div>
            </div>

            <!-- route summary card -->
            <div v-if="activeRoute && routeSummary" class="mt-1 rounded-lg bg-white/5 border border-white/10 p-3 flex flex-col gap-2">
              <p class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">Route Summary</p>
              <div class="grid grid-cols-2 gap-2">
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Peak Hour</p>
                  <p class="text-sm font-heading text-white">{{ routeSummary.peakHour }}</p>
                </div>
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Hrs Over Capacity</p>
                  <p class="text-sm font-heading" :class="routeSummary.hoursOverCapacity > 0 ? 'text-red-400' : 'text-green-400'">
                    {{ routeSummary.hoursOverCapacity }}
                  </p>
                </div>
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Avg Load</p>
                  <p class="text-sm font-heading" :class="routeSummary.avgLoadClass">
                    {{ `${(routeSummary.avgLoad * 100).toFixed(0)}%` }}
                  </p>
                </div>
                <div class="flex flex-col gap-0.5">
                  <p class="text-xs text-ferry-light-gray">Avg Trips / Hr</p>
                  <p class="text-sm font-heading text-white">
                    {{ routeSummary.avgTrips !== null ? routeSummary.avgTrips : '—' }}
                  </p>
                </div>
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

const gtfsTripsPerHour = ref<Record<string, Record<string, Record<number, number>>>>({})

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

  const tripInfo: Record<string, { route_id: string; daytype: string }> = {}
  const primaryServices = new Set(['1', '5'])

  for (const line of tripsText.trim().split('\n').slice(1)) {
    const cols = line.split(',')
    const route_id = cols[0].replace(/"/g, '').trim()
    const service_id = cols[1].replace(/"/g, '').trim()
    const trip_id = cols[2].replace(/"/g, '').trim()
    if (!primaryServices.has(service_id)) continue
    const daytype = serviceType[service_id] ?? 'WEEKDAY'
    tripInfo[trip_id] = { route_id, daytype }
  }

  const counts: Record<string, Record<string, Record<number, Set<string>>>> = {}
  for (const line of stopTimesText.trim().split('\n').slice(1)) {
    const cols = line.split(',')
    const trip_id = cols[0].trim()
    const departure = cols[2].trim()
    const stop_sequence = parseInt(cols[4].trim())
    if (stop_sequence !== 1) continue
    const hour = parseInt(departure.split(':')[0])
    if (hour < 6 || hour > 22) continue
    const info = tripInfo[trip_id]
    if (!info) continue
    const { route_id, daytype } = info
    if (!counts[route_id]) counts[route_id] = {}
    if (!counts[route_id][daytype]) counts[route_id][daytype] = {}
    if (!counts[route_id][daytype][hour]) counts[route_id][daytype][hour] = new Set()
    counts[route_id][daytype][hour].add(trip_id)
  }

  const result: Record<string, Record<string, Record<number, number>>> = {}
  for (const route in counts) {
    result[route] = {}
    for (const daytype in counts[route]) {
      result[route][daytype] = {}
      for (const hour in counts[route][daytype]) {
        result[route][daytype][parseInt(hour)] = counts[route][daytype][parseInt(hour)].size
      }
    }
  }
  gtfsTripsPerHour.value = result
}

onMounted(() => { loadGtfsStats() })

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

const HOURLY_STATS: Record<string, Record<number, { max_load_factor: number; vessel_capacity: number }>> = {"AS": {"6": {"max_load_factor": 0.3, "vessel_capacity": 299}, "7": {"max_load_factor": 0.79, "vessel_capacity": 299}, "8": {"max_load_factor": 0.9, "vessel_capacity": 299}, "9": {"max_load_factor": 0.75, "vessel_capacity": 299}, "10": {"max_load_factor": 0.9, "vessel_capacity": 299}, "11": {"max_load_factor": 1.0, "vessel_capacity": 299}, "12": {"max_load_factor": 1.23, "vessel_capacity": 299}, "13": {"max_load_factor": 1.0, "vessel_capacity": 299}, "14": {"max_load_factor": 1.0, "vessel_capacity": 299}, "15": {"max_load_factor": 1.0, "vessel_capacity": 299}, "16": {"max_load_factor": 1.17, "vessel_capacity": 299}, "17": {"max_load_factor": 1.0, "vessel_capacity": 299}, "18": {"max_load_factor": 1.0, "vessel_capacity": 299}, "19": {"max_load_factor": 1.0, "vessel_capacity": 299}, "20": {"max_load_factor": 1.0, "vessel_capacity": 299}, "21": {"max_load_factor": 1.0, "vessel_capacity": 299}, "22": {"max_load_factor": 0.61, "vessel_capacity": 299}}, "ER": {"6": {"max_load_factor": 0.61, "vessel_capacity": 150}, "7": {"max_load_factor": 1.0, "vessel_capacity": 150}, "8": {"max_load_factor": 1.04, "vessel_capacity": 150}, "9": {"max_load_factor": 1.0, "vessel_capacity": 150}, "10": {"max_load_factor": 1.03, "vessel_capacity": 150}, "11": {"max_load_factor": 1.07, "vessel_capacity": 150}, "12": {"max_load_factor": 1.05, "vessel_capacity": 150}, "13": {"max_load_factor": 1.14, "vessel_capacity": 150}, "14": {"max_load_factor": 1.39, "vessel_capacity": 150}, "15": {"max_load_factor": 1.13, "vessel_capacity": 150}, "16": {"max_load_factor": 1.25, "vessel_capacity": 150}, "17": {"max_load_factor": 1.2, "vessel_capacity": 150}, "18": {"max_load_factor": 1.09, "vessel_capacity": 150}, "19": {"max_load_factor": 1.02, "vessel_capacity": 150}, "20": {"max_load_factor": 1.06, "vessel_capacity": 150}, "21": {"max_load_factor": 1.01, "vessel_capacity": 150}, "22": {"max_load_factor": 1.01, "vessel_capacity": 150}}, "GI": {"9": {"max_load_factor": 0.03, "vessel_capacity": 350}, "10": {"max_load_factor": 0.59, "vessel_capacity": 150}, "11": {"max_load_factor": 1.0, "vessel_capacity": 150}, "12": {"max_load_factor": 1.0, "vessel_capacity": 150}, "13": {"max_load_factor": 1.0, "vessel_capacity": 150}, "14": {"max_load_factor": 1.0, "vessel_capacity": 150}, "15": {"max_load_factor": 1.0, "vessel_capacity": 150}, "16": {"max_load_factor": 1.0, "vessel_capacity": 150}, "17": {"max_load_factor": 1.0, "vessel_capacity": 150}, "18": {"max_load_factor": 0.98, "vessel_capacity": 350}}, "RR": {"9": {"max_load_factor": 0.92, "vessel_capacity": 350}, "11": {"max_load_factor": 0.0, "vessel_capacity": 350}, "12": {"max_load_factor": 0.79, "vessel_capacity": 350}, "14": {"max_load_factor": 0.39, "vessel_capacity": 350}, "15": {"max_load_factor": 0.17, "vessel_capacity": 350}, "16": {"max_load_factor": 0.02, "vessel_capacity": 350}, "17": {"max_load_factor": 0.85, "vessel_capacity": 350}, "18": {"max_load_factor": 0.36, "vessel_capacity": 350}}, "RW": {"6": {"max_load_factor": 0.61, "vessel_capacity": 150}, "7": {"max_load_factor": 0.92, "vessel_capacity": 150}, "8": {"max_load_factor": 0.83, "vessel_capacity": 150}, "9": {"max_load_factor": 1.0, "vessel_capacity": 150}, "10": {"max_load_factor": 1.17, "vessel_capacity": 150}, "11": {"max_load_factor": 1.17, "vessel_capacity": 150}, "12": {"max_load_factor": 1.17, "vessel_capacity": 150}, "13": {"max_load_factor": 1.17, "vessel_capacity": 150}, "14": {"max_load_factor": 1.11, "vessel_capacity": 150}, "15": {"max_load_factor": 1.0, "vessel_capacity": 150}, "16": {"max_load_factor": 1.1, "vessel_capacity": 150}, "17": {"max_load_factor": 1.17, "vessel_capacity": 150}, "18": {"max_load_factor": 1.17, "vessel_capacity": 150}, "19": {"max_load_factor": 1.16, "vessel_capacity": 150}, "20": {"max_load_factor": 1.17, "vessel_capacity": 150}, "21": {"max_load_factor": 0.94, "vessel_capacity": 350}, "22": {"max_load_factor": 0.78, "vessel_capacity": 350}}, "SB": {"6": {"max_load_factor": 0.12, "vessel_capacity": 150}, "7": {"max_load_factor": 0.53, "vessel_capacity": 150}, "8": {"max_load_factor": 0.75, "vessel_capacity": 150}, "9": {"max_load_factor": 1.4, "vessel_capacity": 150}, "10": {"max_load_factor": 1.0, "vessel_capacity": 150}, "11": {"max_load_factor": 1.02, "vessel_capacity": 150}, "12": {"max_load_factor": 1.17, "vessel_capacity": 150}, "13": {"max_load_factor": 1.17, "vessel_capacity": 150}, "14": {"max_load_factor": 1.03, "vessel_capacity": 150}, "15": {"max_load_factor": 1.0, "vessel_capacity": 150}, "16": {"max_load_factor": 1.02, "vessel_capacity": 150}, "17": {"max_load_factor": 1.17, "vessel_capacity": 150}, "18": {"max_load_factor": 1.05, "vessel_capacity": 150}, "19": {"max_load_factor": 1.0, "vessel_capacity": 150}, "20": {"max_load_factor": 1.0, "vessel_capacity": 150}, "21": {"max_load_factor": 1.0, "vessel_capacity": 150}, "22": {"max_load_factor": 0.48, "vessel_capacity": 150}}, "SG": {"6": {"max_load_factor": 0.44, "vessel_capacity": 150}, "7": {"max_load_factor": 0.8, "vessel_capacity": 150}, "8": {"max_load_factor": 0.63, "vessel_capacity": 150}, "9": {"max_load_factor": 1.0, "vessel_capacity": 150}, "10": {"max_load_factor": 0.93, "vessel_capacity": 150}, "11": {"max_load_factor": 0.68, "vessel_capacity": 150}, "12": {"max_load_factor": 0.59, "vessel_capacity": 150}, "13": {"max_load_factor": 0.83, "vessel_capacity": 150}, "14": {"max_load_factor": 0.71, "vessel_capacity": 150}, "15": {"max_load_factor": 0.99, "vessel_capacity": 150}, "16": {"max_load_factor": 1.0, "vessel_capacity": 150}, "17": {"max_load_factor": 1.0, "vessel_capacity": 150}, "18": {"max_load_factor": 0.79, "vessel_capacity": 150}, "19": {"max_load_factor": 0.77, "vessel_capacity": 150}, "20": {"max_load_factor": 0.75, "vessel_capacity": 150}, "21": {"max_load_factor": 0.75, "vessel_capacity": 150}}, "SV": {"6": {"max_load_factor": 0.83, "vessel_capacity": 299}, "7": {"max_load_factor": 0.75, "vessel_capacity": 299}, "8": {"max_load_factor": 0.71, "vessel_capacity": 299}, "9": {"max_load_factor": 0.73, "vessel_capacity": 299}, "10": {"max_load_factor": 1.0, "vessel_capacity": 299}, "11": {"max_load_factor": 1.01, "vessel_capacity": 299}, "12": {"max_load_factor": 1.13, "vessel_capacity": 299}, "13": {"max_load_factor": 1.1, "vessel_capacity": 299}, "14": {"max_load_factor": 1.23, "vessel_capacity": 299}, "15": {"max_load_factor": 1.16, "vessel_capacity": 299}, "16": {"max_load_factor": 1.11, "vessel_capacity": 299}, "17": {"max_load_factor": 1.0, "vessel_capacity": 299}, "18": {"max_load_factor": 1.0, "vessel_capacity": 299}, "19": {"max_load_factor": 1.07, "vessel_capacity": 299}, "20": {"max_load_factor": 1.17, "vessel_capacity": 299}, "21": {"max_load_factor": 0.95, "vessel_capacity": 299}, "22": {"max_load_factor": 0.69, "vessel_capacity": 299}}}

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
}>()

const activeRoute = ref<string | null>(props.routes?.[0] ?? null)
const selectedHour = ref<number | null>(6)

const CHART_W = 260
const CHART_H = 80

function hourToX(hour: number): number {
  return ((hour - 6) / (22 - 6)) * CHART_W
}

function probToY(prob: number): number {
  return CHART_H - prob * CHART_H
}

const linePath = computed(() => {
  if (!props.hourlyCurve?.length) return ''
  return props.hourlyCurve
    .map((p, i) => `${i === 0 ? 'M' : 'L'}${hourToX(p.hour).toFixed(1)},${probToY(p.probability).toFixed(1)}`)
    .join(' ')
})

const areaPath = computed(() => {
  if (!props.hourlyCurve?.length) return ''
  const line = props.hourlyCurve
    .map((p, i) => `${i === 0 ? 'M' : 'L'}${hourToX(p.hour).toFixed(1)},${probToY(p.probability).toFixed(1)}`)
    .join(' ')
  const first = props.hourlyCurve[0]
  const last = props.hourlyCurve[props.hourlyCurve.length - 1]
  return `${line} L${hourToX(last.hour).toFixed(1)},${CHART_H} L${hourToX(first.hour).toFixed(1)},${CHART_H} Z`
})

const selectedDotColor = computed(() => {
  const point = props.hourlyCurve?.find(p => p.hour === selectedHour.value)
  if (!point) return '#63b3ed'
  if (point.risk === 'high') return '#f87171'
  if (point.risk === 'medium') return '#facc15'
  return '#4ade80'
})

const hourlyStats = computed(() => {
  if (selectedHour.value === null || !activeRoute.value) return null
  const routeId = ROUTE_NAME_MAP[activeRoute.value] ?? activeRoute.value
  const staticData = HOURLY_STATS[routeId]?.[selectedHour.value] ?? null
  if (!staticData) return null

  let daytype = 'WEEKDAY'
  if (props.date) {
    const [month, day, year] = props.date.split('/').map(Number)
    const dow = new Date(year, month - 1, day).getDay()
    daytype = (dow === 0 || dow === 6) ? 'WEEKEND' : 'WEEKDAY'
  }

  const trips = gtfsTripsPerHour.value[routeId]?.[daytype]?.[selectedHour.value] ?? null
  return { ...staticData, avg_trips: trips }
})

const highRiskHours = computed(() => {
  if (!props.hourlyCurve?.length) return 0
  return props.hourlyCurve.filter(p => p.probability >= 0.6).length
})

const routeSummary = computed(() => {
  if (!activeRoute.value) return null
  const routeId = ROUTE_NAME_MAP[activeRoute.value] ?? activeRoute.value
  const stats = HOURLY_STATS[routeId]
  if (!stats) return null

  const entries = Object.entries(stats).map(([h, v]) => ({ hour: parseInt(h), ...v }))
  if (!entries.length) return null

  const peak = entries.reduce((a, b) => a.max_load_factor >= b.max_load_factor ? a : b)
  const peakHour = formatHour(peak.hour)
  const hoursOverCapacity = entries.filter(e => e.max_load_factor > 1.0).length
  const avgLoad = entries.reduce((sum, e) => sum + e.max_load_factor, 0) / entries.length
  const avgLoadClass = avgLoad >= 1.1 ? 'text-red-400' : avgLoad >= 0.9 ? 'text-yellow-400' : 'text-green-400'

  let avgTrips: number | null = null
  let daytype = 'WEEKDAY'
  if (props.date) {
    const [month, day, year] = props.date.split('/').map(Number)
    const dow = new Date(year, month - 1, day).getDay()
    daytype = (dow === 0 || dow === 6) ? 'WEEKEND' : 'WEEKDAY'
  }
  const tripsByHour = gtfsTripsPerHour.value[routeId]?.[daytype]
  if (tripsByHour) {
    const tripValues = Object.values(tripsByHour)
    if (tripValues.length) {
      avgTrips = Math.round(tripValues.reduce((s, v) => s + v, 0) / tripValues.length)
    }
  }

  return { peakHour, hoursOverCapacity, avgLoad, avgLoadClass, avgTrips }
})

const dailyDelayRiskPct = computed(() => {
  if (!props.hourlyCurve?.length) return null
  const avg = props.hourlyCurve.reduce((sum, p) => sum + p.probability, 0) / props.hourlyCurve.length
  return Math.round(avg * 100)
})

const loadChartPadBottom = 12
const loadChartHeight = 80

const loadChartEntries = computed(() => {
  if (!activeRoute.value) return []
  const routeId = ROUTE_NAME_MAP[activeRoute.value] ?? activeRoute.value
  const stats = HOURLY_STATS[routeId]
  if (!stats) return []
  return Object.entries(stats)
    .map(([h, v]) => ({
      hour: parseInt(h),
      lf: v.max_load_factor,
      hourLabel: parseInt(h) < 12 ? `${h}a` : parseInt(h) === 12 ? '12p' : `${parseInt(h) - 12}p`,
    }))
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
  if (!activeRoute.value) return []
  const routeId = ROUTE_NAME_MAP[activeRoute.value] ?? activeRoute.value
  const stats = HOURLY_STATS[routeId]
  if (!stats) return []
  return Object.entries(stats)
    .filter(([, v]) => v.max_load_factor > 1.0)
    .map(([h]) => parseInt(h))
    .sort((a, b) => a - b)
})

const loadFactorClass = computed(() => {
  if (!hourlyStats.value) return 'text-white'
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

watch(activeRoute, (val) => emit('update:activeRoute', val), { immediate: true })
watch(() => props.routes, (val) => { activeRoute.value = val?.[0] ?? null })
watch(() => props.hourlyCurve, (val) => {
  if (val?.length) selectedHour.value = null
})
</script>

<style scoped>
/* Scrollbar */
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

/* Firefox */
.overflow-y-auto {
  scrollbar-width: thin;
  scrollbar-color: rgba(255, 255, 255, 0.15) transparent;
}

/* Slider */
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