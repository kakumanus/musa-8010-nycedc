// Precomputed stop-pair prediction lookup — no server required.
//
// predictions_precomputed.json keys:
//   {from_stop_id}_{to_stop_id}_{direction}_{season}_{daytype}_{tempF}_{precipPct}_{hour}
//   e.g. "8_4_NB_FALL_WEEKDAY_65_0_8"
//
// route_stop_pairs.json maps each route's display name to an ordered list of
// (from_stop_id, to_stop_id) pairs for each direction, derived from GTFS.
// The app averages segment probabilities across all pairs to get a route-level number.
//
// To switch to a live API (e.g. R Plumber hosted on Render/Railway):
//   1. Remove loadCache() from AppShell.vue onMounted
//   2. Restore fetchPrediction() calls in handleSystemSubmit and onHourSelected
//   3. Update the API URL in fetchPrediction to your hosted endpoint

type PredictionResult = { delay_probability: number; risk_level: string }
type StopPair = [string, string]
type RoutePairs = Record<string, Record<string, StopPair[]>>

// Cache stores just the raw probability float — risk_level is derived at lookup time.
let cache: Record<string, number> | null = null
let routePairs: RoutePairs | null = null

export async function loadCache(): Promise<void> {
  const base = (import.meta.env.BASE_URL ?? '/').replace(/\/?$/, '/')

  // Load predictions
  for (const url of [`${base}predictions_precomputed.json`, `/predictions_precomputed.json`]) {
    try {
      const res = await fetch(url)
      console.log(`[predictionCache] ${url} → ${res.status}`)
      if (!res.ok) continue
      cache = await res.json()
      console.log(`[predictionCache] Loaded predictions from ${url}`)
      break
    } catch (err) {
      console.warn(`[predictionCache] Failed at ${url}:`, err)
    }
  }
  if (!cache) {
    console.error('[predictionCache] Could not load predictions_precomputed.json — predictions will return defaults.')
  }

  // Load route stop pairs
  for (const url of [`${base}route_stop_pairs.json`, `/route_stop_pairs.json`]) {
    try {
      const res = await fetch(url)
      console.log(`[predictionCache] ${url} → ${res.status}`)
      if (!res.ok) continue
      routePairs = await res.json()
      console.log(`[predictionCache] Loaded route pairs from ${url}`)
      break
    } catch (err) {
      console.warn(`[predictionCache] Failed route pairs at ${url}:`, err)
    }
  }
  if (!routePairs) {
    console.error('[predictionCache] Could not load route_stop_pairs.json — route predictions will be empty.')
  }
}

function snapTemp(tempF: number): number {
  return Math.round(Math.max(-20, Math.min(120, tempF)) / 5) * 5
}

function snapPrecip(pct: number): number {
  const bins = [0, 25, 50, 75, 100]
  return bins.reduce((prev, curr) =>
    Math.abs(curr - pct) < Math.abs(prev - pct) ? curr : prev
  )
}

export function lookupPrediction(
  fromStopId: string,
  toStopId: string,
  direction: string,
  season: string,
  daytype: string,
  tempF: number,
  precipPct: number,
  hour: number
): PredictionResult {
  const key = `${fromStopId}_${toStopId}_${direction}_${season}_${daytype}_${snapTemp(tempF)}_${snapPrecip(precipPct)}_${hour}`
  const prob = cache?.[key] ?? 0
  const risk_level = prob >= 0.6 ? 'high' : prob >= 0.3 ? 'medium' : 'low'
  return { delay_probability: prob, risk_level }
}

export function getRoutePairs(routeLongName: string, direction: string): StopPair[] {
  return (routePairs?.[routeLongName]?.[direction] as StopPair[] | undefined) ?? []
}
