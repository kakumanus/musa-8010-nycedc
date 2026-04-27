library(arrow)
library(dplyr)
library(jsonlite)

# ── Resolve script directory ──────────────────────────────────────────────────
script_dir <- if (!is.null(sys.frames()[[1]]$ofile)) {
  dirname(normalizePath(sys.frames()[[1]]$ofile))
} else {
  dirname(normalizePath(rstudioapi::getSourceEditorContext()$path))
}

gtfs_dir <- file.path(script_dir, "../../public/gtfs")
out_path <- file.path(script_dir, "../../public/route_stop_pairs.json")

parquet    <- read_parquet(file.path(script_dir, "../../../exploratory_code/modeling/baseline_prediction_table_stop_level_v2.parquet"))
trips      <- read.csv(file.path(gtfs_dir, "trips.txt"),      stringsAsFactors = FALSE)
stop_times <- read.csv(file.path(gtfs_dir, "stop_times.txt"), stringsAsFactors = FALSE)

# ── Build (from, to) → direction lookup from the training parquet ─────────────
# This is the source of truth for what NB/SB means for each stop pair.
pair_dir <- parquet %>%
  distinct(from_stop_id, to_stop_id, direction) %>%
  mutate(
    pair_key  = paste0(as.character(from_stop_id), "_", as.character(to_stop_id)),
    direction = as.character(direction)
  )

# ── Routes shown in the app (GeoJSON long_name → GTFS route_id) ──────────────
active_routes <- c(
  "Astoria"            = "AS",
  "East River"         = "ER",
  "Rockaway-Soundview" = "RS",
  "South Brooklyn"     = "SB",
  "St. George"         = "SG"
)

# Primary service IDs used for regular operations
primary_services <- c("1", "5")

result <- list()

for (display_name in names(active_routes)) {
  gtfs_id <- active_routes[[display_name]]

  route_trips <- trips[trips$route_id == gtfs_id & trips$service_id %in% primary_services, ]
  if (nrow(route_trips) == 0) {
    route_trips <- trips[trips$route_id == gtfs_id, ]
  }
  if (nrow(route_trips) == 0) {
    cat(sprintf("  WARNING: no trips found for %s (%s), skipping\n", display_name, gtfs_id))
    next
  }

  direction_map <- list()

  for (dir_id in c(0L, 1L)) {
    dir_trips <- route_trips[route_trips$direction_id == dir_id, ]
    if (nrow(dir_trips) == 0) next

    dir_st <- stop_times[stop_times$trip_id %in% dir_trips$trip_id, ]

    # Find the most common stop sequence pattern across trips
    trip_seqs <- dir_st %>%
      arrange(trip_id, stop_sequence) %>%
      group_by(trip_id) %>%
      summarise(seq_str = paste(stop_id, collapse = ","), .groups = "drop")

    most_common <- names(sort(table(trip_seqs$seq_str), decreasing = TRUE))[1]
    stops <- strsplit(most_common, ",")[[1]]
    if (length(stops) < 2) next

    # Convert ordered stop list to consecutive (from, to) pairs
    pairs <- lapply(seq_len(length(stops) - 1), function(k) {
      list(as.character(stops[k]), as.character(stops[k + 1]))
    })

    # Determine NB or SB by majority vote against the parquet direction lookup
    pair_keys  <- sapply(pairs, function(p) paste0(p[[1]], "_", p[[2]]))
    directions <- pair_dir$direction[match(pair_keys, pair_dir$pair_key)]
    directions <- directions[!is.na(directions)]

    if (length(directions) == 0) {
      # Pair not seen in training data — fall back to GTFS convention (0=NB, 1=SB)
      dir_label <- if (dir_id == 0L) "NB" else "SB"
      cat(sprintf("  WARNING: %s dir_id=%d — no parquet match, defaulting to %s\n",
                  display_name, dir_id, dir_label))
    } else {
      nb_n <- sum(directions == "NB")
      sb_n <- sum(directions == "SB")
      dir_label <- if (nb_n >= sb_n) "NB" else "SB"
    }

    direction_map[[dir_label]] <- pairs
  }

  if (length(direction_map) > 0) {
    result[[display_name]] <- direction_map
    for (dir in names(direction_map)) {
      cat(sprintf("  %s %s: %d segments\n", display_name, dir, length(direction_map[[dir]])))
    }
  }
}

cat(sprintf("\nWriting to %s...\n", out_path))
write(toJSON(result, auto_unbox = FALSE), out_path)
cat("Done.\n")
