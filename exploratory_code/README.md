# exploratory_code

This folder contains all exploratory analysis, feature engineering, and modeling work produced during the project. Each subfolder corresponds to a team member's area of responsibility or a distinct analytical phase.

## Folder Structure

```text
exploratory_code/
│
├── ais-eda/                         — AIS vessel traffic EDA and feature engineering (Sujan)
│   ├── ais-exploration-1.qmd        — Initial AIS data exploration
│   ├── ais-exploration-2.qmd        — Extended AIS exploration
│   ├── ais-feature-engineering.qmd  — Feature engineering pipeline (v1)
│   ├── ais-feature-engineering-2.qmd — Feature engineering pipeline (v2, final)
│   ├── AIS_landing_features.csv     — Per-landing vessel count features
│   ├── AIS_segment_features.csv     — Per-segment vessel count features
│   ├── AIS_historical_averages.csv  — Historical vessel traffic averages by stop/hour
│   └── AIS_Notes.md                 — Methodology notes and decisions
│
├── modeling/                        — Model development and evaluation
│   ├── associative/                 — Associative (historical analysis) model (Ming)
│   │   ├── associative_models_reduced.Rmd              — Reduced associative model
│   │   ├── associative_baseline_models_simplified.Rmd  — Simplified baseline
│   │   ├── associative_baseline_models_trimmed.Rmd     — Trimmed baseline
│   │   ├── grouped_associative_models.Rmd              — Grouped route-level models
│   │   ├── associative_model_results_with_exploratory_plots.Rmd — Results + plots
│   │   └── build_final_tables_direct.Rmd               — Final feature table build
│   ├── operational_eda_report.Rmd   — Stop-level lateness decomposition and delay genesis analysis
│   ├── build_prediction_feature_table.Rmd — Assembles the final predictive feature table
│   ├── model_selection_report.Rmd   — Baseline model family screen + RF vs XGBoost comparison
│   ├── train_final_rf_model_clean.Rmd — Final Random Forest training workflow
│   └── modeling-take1/2.qmd         — Early exploratory modeling iterations
│
├── ridership_eda/                   — Ridership, stop, and trip data EDA (Simon)
│   ├── Ridership Markdown #1.Rmd    — Main ridership EDA
│   ├── NYCF_ridership_details_*.csv — Ridership detail data (2024–2025)
│   ├── NYCF_stop_data_*.csv         — Stop-level boarding/alighting data
│   └── NYCF_trip_data_*.csv         — Trip-level schedule and lateness data
│
├── swiftly_eda/                     — Swiftly GPS data exploration (Tyler)
│   ├── swiftly_eda.Rmd              — Main Swiftly EDA
│   └── swiftly_pres_2.Rmd           — Presentation-ready version
│
├── trip_eda/                        — Trip-level EDA (Ming)
│   ├── Trip_data_EDA.qmd            — Trip EDA including lateness definitions and distributions
│   └── environment_master_hourly_2024_2025.csv — Hourly environmental conditions (wind, temp, etc.)
│
├── hex_grid_100m.geojson            — 100m hex grid over the NYC Ferry service area
├── new_routes_segmentation.geojson  — Route segmentation geometry
└── schedule_calendar_2024-01-01_to_2025-06-30.csv — Ferry schedule calendar lookup
```

## Data Notes

- Raw ridership CSVs (`NYCF_*.csv`) are gitignored due to file size; contact the team for access.
- AIS raw monthly CSVs are gitignored; filtered output CSVs are committed.
- The final predictive feature table (`final_predictive_feature_table.parquet/csv`) is gitignored.
