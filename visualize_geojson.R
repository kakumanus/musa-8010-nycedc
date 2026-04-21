# visualize_geojson.R
# Interactive map of processed routes and landings using mapview.
# Run this after process_geojson.R has written the *_processed.geojson files.

if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(tidyverse, sf, mapview)

# ── Read processed outputs ─────────────────────────────────────────────────────
routes   <- st_read("GeoJSONs/routes_processed.geojson",   quiet = TRUE)
landings <- st_read("GeoJSONs/landings_processed.geojson", quiet = TRUE)

# ── Build route layer ──────────────────────────────────────────────────────────
# Color each line by its brand hex; replace NA (unmapped routes) with gray
routes <- routes %>%
  mutate(color = if_else(is.na(color), "#888888", color))

map_routes <- mapview(
  routes,
  zcol        = "route_id",
  color       = routes$color,   # per-feature stroke color
  lwd         = 3,
  layer.name  = "Routes"
)

# ── Build landings layer ───────────────────────────────────────────────────────
landings <- landings %>%
  mutate(route_color = if_else(is.na(route_color), "#888888", route_color))

map_landings <- mapview(
  landings,
  zcol        = "primary_route_id",
  col.regions = landings$route_color,  # per-feature fill color
  color       = "#FFFFFF",             # white border on markers
  cex         = 6,
  layer.name  = "Landings"
)

# ── Combine and display ────────────────────────────────────────────────────────
map_routes + map_landings
