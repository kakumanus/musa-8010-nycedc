library(jsonlite)
library(dplyr)
library(tidyr)
library(ggplot2)

# ── Load JSON ─────────────────────────────────────────────────────────────────
script_dir <- if (!is.null(sys.frames()[[1]]$ofile)) {
  dirname(normalizePath(sys.frames()[[1]]$ofile))
} else {
  dirname(normalizePath(rstudioapi::getSourceEditorContext()$path))
}

json_path <- file.path(script_dir, "../../public/predictions_precomputed.json")
raw <- fromJSON(json_path)

# ── Parse keys into a flat data frame ─────────────────────────────────────────
# Key format: {from_stop_id}_{to_stop_id}_{direction}_{season}_{daytype}_{tempF}_{precipPct}_{hour}
# SUMMER_1 / SUMMER_2 contain underscores — handle explicitly in regex.
pattern <- "^([0-9]+)_([0-9]+)_(NB|SB)_(SUMMER_[12]|FALL|SPRING|WINTER)_(WEEKDAY|WEEKEND)_(-?[0-9]+)_([0-9]+)_([0-9]+)$"

keys <- names(raw)
mat  <- regmatches(keys, regexec(pattern, keys, perl = TRUE))
mat  <- do.call(rbind, lapply(mat, `[`, -1))  # drop full-match column

df <- tibble(
  from_stop_id      = mat[, 1],
  to_stop_id        = mat[, 2],
  direction         = mat[, 3],
  season            = mat[, 4],
  daytype           = mat[, 5],
  temp_f            = as.integer(mat[, 6]),
  precip_pct        = as.integer(mat[, 7]),
  hour              = as.integer(mat[, 8]),
  delay_probability = as.numeric(raw)
) |>
  mutate(
    pair       = paste0(from_stop_id, " → ", to_stop_id),
    risk_level = factor(
      ifelse(delay_probability >= 0.6, "high", ifelse(delay_probability >= 0.3, "medium", "low")),
      levels = c("low", "medium", "high")
    ),
    direction  = factor(direction),
    season     = factor(season),
    daytype    = factor(daytype),
    precip_pct = factor(precip_pct, levels = c(0, 25, 50, 75, 100))
  )

cat(sprintf("Loaded %d predictions across %d stop-pair/direction combos.\n",
            nrow(df), n_distinct(paste(df$from_stop_id, df$to_stop_id, df$direction))))

# ── 1. Overall distribution of delay probability ──────────────────────────────
p1 <- ggplot(df, aes(x = delay_probability)) +
  geom_histogram(bins = 60, fill = "#63b3ed", color = NA, alpha = 0.85) +
  geom_vline(xintercept = c(0.3, 0.6), linetype = "dashed", color = c("#facc15", "#f87171")) +
  annotate("text", x = 0.31, y = Inf, label = "medium", hjust = 0, vjust = 2,
           size = 3, color = "#facc15") +
  annotate("text", x = 0.61, y = Inf, label = "high", hjust = 0, vjust = 2,
           size = 3, color = "#f87171") +
  scale_x_continuous(labels = scales::percent) +
  labs(title = "Distribution of Precomputed Delay Probabilities",
       x = "Delay Probability", y = "Count") +
  theme_minimal()

print(p1)

# ── 2. Risk level breakdown ───────────────────────────────────────────────────
risk_summary <- df |>
  count(risk_level) |>
  mutate(pct = n / sum(n) * 100)

cat("\n--- Risk Level Breakdown ---\n")
print(risk_summary)

p2 <- ggplot(risk_summary, aes(x = risk_level, y = pct, fill = risk_level)) +
  geom_col(width = 0.6) +
  scale_fill_manual(values = c(low = "#4ade80", medium = "#facc15", high = "#f87171")) +
  scale_y_continuous(labels = scales::percent_format(scale = 1)) +
  labs(title = "Share of Predictions by Risk Level", x = NULL, y = "% of Predictions") +
  theme_minimal() +
  theme(legend.position = "none")

print(p2)

# ── 3. Top 20 stop pairs by median probability ────────────────────────────────
by_pair <- df |>
  group_by(pair, direction) |>
  summarise(median_prob = median(delay_probability), .groups = "drop")

top_pairs <- by_pair |>
  group_by(pair) |>
  summarise(max_median = max(median_prob), .groups = "drop") |>
  slice_max(max_median, n = 20) |>
  pull(pair)

cat("\n--- Top 20 Stop Pairs by Median Delay Probability ---\n")
print(by_pair |> filter(pair %in% top_pairs) |> arrange(desc(median_prob)))

p3 <- by_pair |>
  filter(pair %in% top_pairs) |>
  ggplot(aes(x = reorder(pair, median_prob), y = median_prob, fill = direction)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_fill_manual(values = c(NB = "#63b3ed", SB = "#f6ad55")) +
  scale_y_continuous(labels = scales::percent) +
  coord_flip() +
  labs(title = "Top 20 Stop Pairs — Median Delay Probability by Direction",
       x = NULL, y = "Median Probability", fill = "Direction") +
  theme_minimal(base_size = 9)

print(p3)

# ── 4. Probability by hour (across all pairs) ─────────────────────────────────
by_hour <- df |>
  group_by(hour) |>
  summarise(
    median_prob = median(delay_probability),
    p25 = quantile(delay_probability, 0.25),
    p75 = quantile(delay_probability, 0.75),
    .groups = "drop"
  )

p4 <- ggplot(by_hour, aes(x = hour)) +
  geom_ribbon(aes(ymin = p25, ymax = p75), fill = "#63b3ed", alpha = 0.2) +
  geom_line(aes(y = median_prob), color = "#63b3ed", linewidth = 1) +
  geom_hline(yintercept = c(0.3, 0.6), linetype = "dashed",
             color = c("#facc15", "#f87171"), alpha = 0.7) +
  scale_x_continuous(breaks = c(6, 9, 12, 15, 18, 21),
                     labels = c("6 AM", "9 AM", "12 PM", "3 PM", "6 PM", "9 PM")) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Delay Probability by Hour of Day (median ± IQR, all stop pairs)",
       x = NULL, y = "Delay Probability") +
  theme_minimal()

print(p4)

# ── 5. Effect of temperature ──────────────────────────────────────────────────
by_temp <- df |>
  group_by(temp_f) |>
  summarise(median_prob = median(delay_probability), .groups = "drop")

p5 <- ggplot(by_temp, aes(x = temp_f, y = median_prob)) +
  geom_line(color = "#63b3ed", linewidth = 1) +
  geom_hline(yintercept = c(0.3, 0.6), linetype = "dashed",
             color = c("#facc15", "#f87171"), alpha = 0.7) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Median Delay Probability vs Temperature",
       x = "Temperature (°F)", y = "Median Probability") +
  theme_minimal()

print(p5)

# ── 6. Effect of precipitation ────────────────────────────────────────────────
by_precip <- df |>
  group_by(precip_pct) |>
  summarise(median_prob = median(delay_probability), .groups = "drop")

cat("\n--- Median Probability by Precipitation Level ---\n")
print(by_precip)

p6 <- ggplot(df, aes(x = precip_pct, y = delay_probability)) +
  geom_boxplot(fill = "#63b3ed", alpha = 0.5, outlier.size = 0.5, outlier.alpha = 0.2) +
  geom_hline(yintercept = c(0.3, 0.6), linetype = "dashed",
             color = c("#facc15", "#f87171"), alpha = 0.7) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Delay Probability Distribution by Precipitation Level",
       x = "Precipitation (%)", y = "Delay Probability") +
  theme_minimal()

print(p6)

# ── 7. Season × daytype heatmap ───────────────────────────────────────────────
by_season_day <- df |>
  group_by(season, daytype) |>
  summarise(median_prob = median(delay_probability), .groups = "drop")

p7 <- ggplot(by_season_day, aes(x = daytype, y = season, fill = median_prob)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = scales::percent(median_prob, accuracy = 0.1)),
            size = 3.5, color = "white") +
  scale_fill_gradient(low = "#4ade80", high = "#f87171", labels = scales::percent) +
  labs(title = "Median Delay Probability: Season × Day Type",
       x = NULL, y = NULL, fill = "Median Prob") +
  theme_minimal()

print(p7)

# ── 8. Hourly curves for top 12 highest-risk stop pairs ──────────────────────
top12_pairs <- by_pair |>
  group_by(pair) |>
  summarise(max_median = max(median_prob), .groups = "drop") |>
  slice_max(max_median, n = 12) |>
  pull(pair)

by_pair_hour <- df |>
  filter(pair %in% top12_pairs) |>
  group_by(pair, direction, hour) |>
  summarise(median_prob = median(delay_probability), .groups = "drop")

p8 <- ggplot(by_pair_hour, aes(x = hour, y = median_prob, color = direction)) +
  geom_line(linewidth = 0.8) +
  geom_hline(yintercept = 0.3, linetype = "dashed", color = "#facc15", alpha = 0.6) +
  geom_hline(yintercept = 0.6, linetype = "dashed", color = "#f87171", alpha = 0.6) +
  scale_color_manual(values = c(NB = "#63b3ed", SB = "#f6ad55")) +
  scale_x_continuous(breaks = c(6, 12, 18, 22)) +
  scale_y_continuous(labels = scales::percent) +
  facet_wrap(~pair, ncol = 4) +
  labs(title = "Hourly Delay Curves — Top 12 Highest-Risk Stop Pairs (NB vs SB)",
       x = "Hour", y = "Median Probability", color = "Direction") +
  theme_minimal(base_size = 9) +
  theme(legend.position = "bottom")

print(p8)

cat("\nDone. 8 plots printed.\n")

# ── 9. Top 5 highest-probability combos ───────────────────────────────────────
top5 <- df |>
  slice_max(delay_probability, n = 5) |>
  select(from_stop_id, to_stop_id, direction, season, daytype,
         temp_f, precip_pct, hour, delay_probability, risk_level)

cat("\n--- Top 5 Highest Delay Probability Combos ---\n")
print(top5, n = 5)
