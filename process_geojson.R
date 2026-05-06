# process_geojson.R
# Processes raw ferry routes and landings GeoJSONs for use in the NYC Ferry delay app.
# Outputs:
#   GeoJSONs/routes_processed.geojson   — smoothed, direction-labeled, brand-colored route lines
#   GeoJSONs/landings_processed.geojson — landings with route_color and delay_prob placeholder

# ── 0. Packages ────────────────────────────────────────────────────────────────
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(tidyverse, sf, smoothr)

# ── 1. Brand color lookup ──────────────────────────────────────────────────────
# Official NYC Ferry route colors keyed by route_id
route_colors <- c(
  ER = "#228B9D",
  RS = "#AD1AAC",   # Rockaway/Soundview combined route
  SB = "#FFD100",
  AS = "#FE5000",
  SV = "#4E008E",
  SG = "#D0006F",
  GI = "#9893A0"
)

# ══════════════════════════════════════════════════════════════════════════════
# ROUTES PROCESSING
# ══════════════════════════════════════════════════════════════════════════════

# ── 2. Read routes ─────────────────────────────────────────────────────────────
routes_raw <- st_read("GeoJSONs/routes.geojson", quiet = TRUE)

# Drop RES (Rockaway East) and RWS (Rockaway West) — these are bus routes, not ferry
routes_raw <- routes_raw %>% filter(!route_id %in% c("RES", "RWS"))

# Print property names and a sample feature for verification
cat("\n── routes.geojson ──\n")
cat("Property names:", paste(names(routes_raw), collapse = ", "), "\n")
cat("Sample feature (row 1):\n")
print(routes_raw[1, ] %>% st_drop_geometry())

# ── 3. Add direction property ──────────────────────────────────────────────────
# Routes already exist as separate NB/SB features but lack an explicit direction label.
# Within each route_id group, features are ordered so that the first occurrence is
# treated as NB (outbound from Wall St) and the second as SB (inbound to Wall St).
# shape_id values are typically consecutive pairs per route.
routes_directed <- routes_raw %>%
  group_by(route_id) %>%
  mutate(
    # Rank by shape_id (numeric) within each route; first = NB, second = SB
    direction = if_else(
      rank(as.numeric(shape_id), ties.method = "first") == 1,
      "NB",
      "SB"
    )
  ) %>%
  ungroup()

cat("\nDirection counts per route:\n")
print(routes_directed %>% st_drop_geometry() %>% count(route_id, direction))

# ── 4. Apply brand colors ──────────────────────────────────────────────────────
# Replace the existing 'color' field with the official brand hex values.
# Routes not in the lookup receive NA for color.
routes_colored <- routes_directed %>%
  mutate(color = route_colors[route_id])

# ── 5. Chaikin smoothing ───────────────────────────────────────────────────────
# Smooth sharp angular turns using Chaikin's corner-cutting algorithm (5 refinements).
# This improves visual appearance on the map without altering stop locations.
routes_smoothed <- routes_colored %>%
  smooth(method = "chaikin", refinements = 5)

# ── 6. Write routes output ─────────────────────────────────────────────────────
st_write(
  routes_smoothed,
  "GeoJSONs/routes_processed.geojson",
  driver    = "GeoJSON",
  delete_dsn = TRUE  # overwrite if file already exists
)

cat("\n── routes_processed.geojson summary ──\n")
cat("Rows:", nrow(routes_smoothed), "\n")
cat("Properties:", paste(names(routes_smoothed), collapse = ", "), "\n")
cat("CRS:", st_crs(routes_smoothed)$input, "\n")

# ══════════════════════════════════════════════════════════════════════════════
# LANDINGS PROCESSING
# ══════════════════════════════════════════════════════════════════════════════

# ── 7. Read landings ───────────────────────────────────────────────────────────
landings_raw <- st_read("GeoJSONs/landings.geojson", quiet = TRUE)

# Drop stops that exclusively serve bus routes (RES/RWS, route_type "3")
# route_info is stored as a JSON string by sf; ferry stops always have route_type "4"
landings_raw <- landings_raw %>%
  filter(str_detect(route_info, '"route_type": \\[ "4" \\]'))

# Print property names and a sample feature for verification
cat("\n── landings.geojson ──\n")
cat("Property names:", paste(names(landings_raw), collapse = ", "), "\n")
cat("Sample feature (row 1):\n")
print(landings_raw[1, ] %>% st_drop_geometry())

# ── 8. Add route_color ─────────────────────────────────────────────────────────
# sf reads the nested route_info object as a raw JSON character string, not a
# parsed list. Use a regex to pull the first route_id value from that string.
# e.g. '{ "route_id": [ "ER" ], ... }' -> "ER"
# Stops serving multiple routes (e.g. Wall St/Pier 11) get the color of their
# first-listed route; this can be updated once per-stop primary routes are confirmed.
landings_colored <- landings_raw %>%
  mutate(
    # str_match returns a matrix; column 2 is the first capture group
    primary_route_id = str_match(route_info, '"route_id":\\s*\\[\\s*"([A-Z]+)"')[, 2],
    route_color      = route_colors[primary_route_id]
  )

# ── 9. Add route_count and delay_prob ─────────────────────────────────────────
# route_count: number of ferry routes serving this stop, used by the map to
# visually distinguish interchange stops (white, larger) from single-route stops.
# delay_prob: placeholder for model-predicted delay probabilities.
landings_final <- landings_colored %>%
  mutate(
    route_count = str_count(route_info, '"[A-Z]{2}"'),
    delay_prob  = 0
  )

# ── 10. Write landings output ──────────────────────────────────────────────────
st_write(
  landings_final,
  "GeoJSONs/landings_processed.geojson",
  driver     = "GeoJSON",
  delete_dsn = TRUE
)

cat("\n── landings_processed.geojson summary ──\n")
cat("Rows:", nrow(landings_final), "\n")
cat("Properties:", paste(names(landings_final), collapse = ", "), "\n")
cat("CRS:", st_crs(landings_final)$input, "\n")
cat("\nRoute color counts:\n")
print(landings_final %>% st_drop_geometry() %>% count(primary_route_id, route_color))
