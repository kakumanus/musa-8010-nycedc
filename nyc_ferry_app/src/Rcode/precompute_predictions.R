library(tidymodels)
library(arrow)
library(dplyr)
library(jsonlite)

# ── Resolve script directory ──────────────────────────────────────────────────
script_dir <- if (!is.null(sys.frames()[[1]]$ofile)) {
  dirname(normalizePath(sys.frames()[[1]]$ofile))
} else {
  dirname(normalizePath(rstudioapi::getSourceEditorContext()$path))
}

model    <- readRDS(file.path(script_dir, "final_rf_model_workflow.rds"))
parquet  <- read_parquet(file.path(script_dir, "../../../exploratory_code/modeling/baseline_prediction_table_stop_level_v2.parquet"))
out_path <- file.path(script_dir, "../../public/predictions_precomputed.json")

# ── Compute lookup medians per stop pair ──────────────────────────────────────
# Group by the actual (from, to) stop pair + direction/season/daytype.
# from_stop_id and to_stop_id are now the group keys, not aggregated medians.
lookup <- parquet %>%
  group_by(from_stop_id, to_stop_id, direction, schedule_season, schedule_daytype) %>%
  summarise(
    boardings_lag_7d                = median(boardings_lag_7d,                na.rm = TRUE),
    alightings_lag_7d               = median(alightings_lag_7d,               na.rm = TRUE),
    curr_vessel_count_lag_7d        = median(curr_vessel_count_lag_7d,        na.rm = TRUE),
    prev_vessel_count_lag_7d        = median(prev_vessel_count_lag_7d,        na.rm = TRUE),
    expected_water_min              = median(expected_water_min,              na.rm = TRUE),
    planned_turnaround_gap_min      = median(planned_turnaround_gap_min,      na.rm = TRUE),
    scheduled_headway_min           = median(scheduled_headway_min,           na.rm = TRUE),
    stop_sequence                   = median(stop_sequence,                   na.rm = TRUE),
    vessel_capacity                 = median(vessel_capacity,                 na.rm = TRUE),
    vessel_trip_seq_in_chain        = median(vessel_trip_seq_in_chain,        na.rm = TRUE),
    segment_hourly_vessel_count_all = median(segment_hourly_vessel_count_all, na.rm = TRUE),
    env_narrows_current_obs         = median(env_narrows_current_obs,         na.rm = TRUE),
    env_battery_water_level_obs     = median(env_battery_water_level_obs,     na.rm = TRUE),
    prev_stop_shared_stop_flag      = median(as.numeric(prev_stop_shared_stop_flag), na.rm = TRUE) >= 0.5,
    curr_stop_shared_stop_flag      = median(as.numeric(curr_stop_shared_stop_flag), na.rm = TRUE) >= 0.5,
    is_terminal_stop                = median(as.numeric(is_terminal_stop),           na.rm = TRUE) >= 0.5,
    .groups = "drop"
  )

stop_id_levels <- sort(unique(as.character(c(parquet$from_stop_id, parquet$to_stop_id))))

# ── Grid of user-controllable inputs ─────────────────────────────────────────
temp_f_vals     <- seq(-20, 120, by = 5)   # 29 values
precip_pct_vals <- c(0, 25, 50, 75, 100)   # 5 values
hours           <- 6:22                    # 17 values

grid <- expand.grid(
  temp_f     = temp_f_vals,
  precip_pct = precip_pct_vals,
  hour       = hours,
  KEEP.OUT.ATTRS = FALSE
)

total <- nrow(lookup) * nrow(grid)
cat(sprintf("Pre-computing %d predictions across %d stop-pair/season combos...\n",
            total, nrow(lookup)))

# ── Pre-computation ───────────────────────────────────────────────────────────
results   <- vector("list", total)
names_vec <- character(total)
idx       <- 1

for (i in seq_len(nrow(lookup))) {
  d <- lookup[i, ]

  # Key: {from}_{to}_{direction}_{season}_{daytype}_{temp}_{precip}_{hour}
  combo_key <- paste(d$from_stop_id, d$to_stop_id, d$direction,
                     d$schedule_season, d$schedule_daytype, sep = "_")

  batch <- tibble(
    boardings_lag_7d                = d$boardings_lag_7d,
    alightings_lag_7d               = d$alightings_lag_7d,
    curr_vessel_count_lag_7d        = d$curr_vessel_count_lag_7d,
    prev_vessel_count_lag_7d        = d$prev_vessel_count_lag_7d,
    expected_water_min              = d$expected_water_min,
    planned_turnaround_gap_min      = d$planned_turnaround_gap_min,
    scheduled_headway_min           = d$scheduled_headway_min,
    stop_sequence                   = d$stop_sequence,
    vessel_capacity                 = d$vessel_capacity,
    vessel_trip_seq_in_chain        = d$vessel_trip_seq_in_chain,
    segment_hourly_vessel_count_all = d$segment_hourly_vessel_count_all,
    env_narrows_current_obs         = d$env_narrows_current_obs,
    env_battery_water_level_obs     = d$env_battery_water_level_obs,
    env_visibility_m                = 10000,
    env_wind_speed_mps              = 3.0,
    direction                  = factor(d$direction,         levels = c("NB", "SB")),
    schedule_season            = factor(d$schedule_season,   levels = c("FALL", "SPRING", "SUMMER_1", "SUMMER_2", "WINTER")),
    schedule_daytype           = factor(d$schedule_daytype,  levels = c("WEEKDAY", "WEEKEND")),
    curr_stop_shared_stop_flag = factor(as.character(d$curr_stop_shared_stop_flag), levels = c("FALSE", "TRUE")),
    prev_stop_shared_stop_flag = factor(as.character(d$prev_stop_shared_stop_flag), levels = c("FALSE", "TRUE")),
    is_terminal_stop           = factor(as.character(d$is_terminal_stop),           levels = c("FALSE", "TRUE")),
    from_stop_id               = factor(as.character(d$from_stop_id), levels = stop_id_levels),
    to_stop_id                 = factor(as.character(d$to_stop_id),   levels = stop_id_levels),
    env_temperature_c    = (grid$temp_f - 32) * 5 / 9,
    env_precipitation_mm = grid$precip_pct / 100 * 25.4,
    prev_stop_sched_hour = as.numeric(grid$hour)
  )

  delay_probs <- round(predict(model, new_data = batch, type = "prob")$.pred_yes, 4)

  keys <- paste(combo_key, grid$temp_f, grid$precip_pct, grid$hour, sep = "_")
  for (j in seq_len(nrow(grid))) {
    results[[idx]] <- jsonlite::unbox(delay_probs[j])
    names_vec[idx] <- keys[j]
    idx <- idx + 1
  }

  cat(sprintf("  [%d/%d] %s done\n", i, nrow(lookup), combo_key))
}

names(results) <- names_vec

cat("Writing JSON...\n")
write(toJSON(results), out_path)
cat(sprintf("Done. %d entries written to %s\n", length(results), out_path))
