library(ranger)
library(dplyr)
library(jsonlite)

model <- readRDS("C:/Users/tjama/Practicum/rf_model_current_best_preview.rds")

MODEL_COLS <- c(
  "alightings_lag_7d", "boardings_lag_7d",
  "curr_stop_shared_stop_flagFALSE", "curr_stop_shared_stop_flagTRUE", "curr_stop_shared_stop_flagOTHER",
  "curr_vessel_count_lag_7d", "directionSB", "directionOTHER",
  "expected_water_min", "is_terminal_stopTRUE", "is_terminal_stopOTHER",
  "planned_turnaround_gap_min", "prev_stop_sched_hour",
  "prev_stop_shared_stop_flagTRUE", "prev_stop_shared_stop_flagOTHER",
  "prev_vessel_count_lag_7d", "schedule_daytypeWEEKEND", "schedule_daytypeOTHER",
  "schedule_seasonSPRING", "schedule_seasonSUMMER_1", "schedule_seasonSUMMER_2",
  "schedule_seasonWINTER", "schedule_seasonOTHER",
  "scheduled_headway_min", "stop_sequence", "vessel_capacity",
  "vessel_trip_seq_in_chain", "env_battery_water_level_obs",
  "env_narrows_current_obs", "env_precipitation_mm", "env_temperature_c",
  "env_visibility_m", "env_wind_speed_mps",
  "from_stop_id111", "from_stop_id112", "from_stop_id113", "from_stop_id114",
  "from_stop_id115", "from_stop_id118", "from_stop_id120", "from_stop_id136",
  "from_stop_id137", "from_stop_id138", "from_stop_id141", "from_stop_id17",
  "from_stop_id18", "from_stop_id19", "from_stop_id20", "from_stop_id23",
  "from_stop_id24", "from_stop_id25", "from_stop_id4", "from_stop_id8",
  "from_stop_id87", "from_stop_id88", "from_stop_id89", "from_stop_id90",
  "from_stop_idOTHER",
  "to_stop_id111", "to_stop_id112", "to_stop_id113", "to_stop_id114",
  "to_stop_id115", "to_stop_id118", "to_stop_id120", "to_stop_id136",
  "to_stop_id137", "to_stop_id138", "to_stop_id141", "to_stop_id17",
  "to_stop_id18", "to_stop_id19", "to_stop_id20", "to_stop_id23",
  "to_stop_id24", "to_stop_id25", "to_stop_id4", "to_stop_id8",
  "to_stop_id87", "to_stop_id88", "to_stop_id89", "to_stop_id90",
  "to_stop_idOTHER",
  "segment_hourly_vessel_count_all"
)

#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list())
  }
  plumber::forward()
}

#* @post /predict
function(req) {
  body <- req$body

  direction   <- body$direction
  season      <- body$schedule_season
  daytype     <- body$schedule_daytype
  temp_c      <- (as.numeric(body$env_temperature_f) - 32) * 5 / 9
  precip_mm   <- as.numeric(body$env_precipitation_pct) / 100 * 25.4
  from_stop   <- as.character(body$from_stop_id)
  to_stop     <- as.character(body$to_stop_id)
  curr_shared <- as.logical(body$curr_stop_shared_stop_flag)
  prev_shared <- as.logical(body$prev_stop_shared_stop_flag)
  is_terminal <- as.logical(body$is_terminal_stop)

  # Allow hour override for daily curve
  sched_hour <- if (!is.null(body$prev_stop_sched_hour_override)) {
    as.numeric(body$prev_stop_sched_hour_override)
  } else {
    as.numeric(body$prev_stop_sched_hour)
  }

  new_data <- as.data.frame(matrix(0, nrow = 1, ncol = length(MODEL_COLS)))
  colnames(new_data) <- MODEL_COLS

  new_data$alightings_lag_7d               <- as.numeric(body$alightings_lag_7d)
  new_data$boardings_lag_7d                <- as.numeric(body$boardings_lag_7d)
  new_data$curr_vessel_count_lag_7d        <- as.numeric(body$curr_vessel_count_lag_7d)
  new_data$expected_water_min              <- as.numeric(body$expected_water_min)
  new_data$planned_turnaround_gap_min      <- as.numeric(body$planned_turnaround_gap_min)
  new_data$prev_stop_sched_hour            <- sched_hour
  new_data$prev_vessel_count_lag_7d        <- as.numeric(body$prev_vessel_count_lag_7d)
  new_data$scheduled_headway_min           <- as.numeric(body$scheduled_headway_min)
  new_data$stop_sequence                   <- as.numeric(body$stop_sequence)
  new_data$vessel_capacity                 <- as.numeric(body$vessel_capacity)
  new_data$vessel_trip_seq_in_chain        <- as.numeric(body$vessel_trip_seq_in_chain)
  new_data$env_battery_water_level_obs     <- as.numeric(body$env_battery_water_level_obs)
  new_data$env_narrows_current_obs         <- as.numeric(body$env_narrows_current_obs)
  new_data$env_precipitation_mm            <- precip_mm
  new_data$env_temperature_c               <- temp_c
  new_data$env_visibility_m                <- 10000
  new_data$env_wind_speed_mps              <- 3.0
  new_data$segment_hourly_vessel_count_all <- as.numeric(body$segment_hourly_vessel_count_all)

  if (direction == "SB") new_data$directionSB <- 1
  if (!direction %in% c("NB", "SB")) new_data$directionOTHER <- 1

  if (season == "SPRING")   new_data$schedule_seasonSPRING   <- 1
  if (season == "SUMMER_1") new_data$schedule_seasonSUMMER_1 <- 1
  if (season == "SUMMER_2") new_data$schedule_seasonSUMMER_2 <- 1
  if (season == "WINTER")   new_data$schedule_seasonWINTER   <- 1
  if (!season %in% c("FALL","SPRING","SUMMER_1","SUMMER_2","WINTER")) new_data$schedule_seasonOTHER <- 1

  if (daytype == "WEEKEND") new_data$schedule_daytypeWEEKEND <- 1
  if (!daytype %in% c("WEEKDAY","WEEKEND")) new_data$schedule_daytypeOTHER <- 1

  if (isTRUE(curr_shared))  new_data$curr_stop_shared_stop_flagTRUE  <- 1
  if (is.na(curr_shared))   new_data$curr_stop_shared_stop_flagOTHER <- 1
  if (isFALSE(curr_shared)) new_data$curr_stop_shared_stop_flagFALSE <- 1

  if (isTRUE(prev_shared)) new_data$prev_stop_shared_stop_flagTRUE  <- 1
  if (is.na(prev_shared))  new_data$prev_stop_shared_stop_flagOTHER <- 1

  if (isTRUE(is_terminal)) new_data$is_terminal_stopTRUE  <- 1
  if (is.na(is_terminal))  new_data$is_terminal_stopOTHER <- 1

  from_col <- paste0("from_stop_id", from_stop)
  if (from_col %in% MODEL_COLS) new_data[[from_col]] <- 1 else new_data$from_stop_idOTHER <- 1

  to_col <- paste0("to_stop_id", to_stop)
  if (to_col %in% MODEL_COLS) new_data[[to_col]] <- 1 else new_data$to_stop_idOTHER <- 1

  probs      <- predict(model, data = new_data)$predictions
  delay_prob <- as.numeric(probs[1, 2])
  risk_level <- if (delay_prob >= 0.6) "high" else if (delay_prob >= 0.3) "medium" else "low"

  list(
    delay_probability = jsonlite::unbox(round(delay_prob, 4)),
    risk_level        = jsonlite::unbox(risk_level)
  )
}