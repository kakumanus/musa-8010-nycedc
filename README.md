# MUSA Practicum 2026 - NYC Ferry ⛴️
#### Authors: Ming Cao, Sujan Kakumanu, Tyler Maynard, Simon Sun

## Background

NYC Ferry launched on May 1, 2017 to connect underserved waterfront neighborhoods to the broader transit network. Today the system operates seven routes across the five boroughs, carrying millions of riders annually. On-time performance varies substantially by route, time of day, and environmental conditions.

This project was done in partnership with the NYC Economic Development Corporation (NYCEDC), which oversees NYC Ferry operations. Our team — four graduate students from the University of Pennsylvania's Master of Urban Spatial Analytics program — built three deliverables:

1. **A historical analysis and associative model** that identifies the operational, environmental, and demand-side factors most associated with delays across the network.
2. **A 48-hour predictive model** that forecasts whether a given stop-level departure will be more than 10 minutes late, trained on historical ridership, vessel traffic (AIS), and environmental data.
3. **An interactive web app** that operationalizes the predictive model, giving dispatchers and riders a real-time view of delay risk by route and stop.

## Project Structure

```text
/
├── GeoJSONs/                        — Processed and raw geospatial files
│   ├── boroughs.geojson             — NYC borough boundaries
│   ├── ferry_landings*.geojson      — Stop/landing locations (raw + processed)
│   └── routes*.geojson              — Route geometries (raw + processed)
│
├── exploratory_code/                — All exploratory analysis and modeling
│   ├── ais-eda/                     — AIS vessel traffic exploration and feature engineering (Sujan)
│   ├── modeling/                    — Predictive model development
│   │   ├── associative/             — Associative model exploration (Ming)
│   │   ├── operational_eda_report.Rmd   — Stop-level lateness decomposition and delay genesis
│   │   ├── model_selection_report.Rmd  — Baseline screen + final RF vs XGBoost comparison
│   │   ├── train_final_rf_model_clean.Rmd — Final RF model training workflow
│   │   └── build_prediction_feature_table.Rmd — Feature table assembly
│   ├── ridership_eda/               — Stop, ridership, and trip data EDA (Simon)
│   ├── swiftly_eda/                 — Swiftly GPS data exploration (Tyler)
│   └── trip_eda/                    — Trip-level EDA (Ming)
│
├── nyc_ferry_app/                   — Interactive dashboard (Astro + Vue)
│
├── nyc_ferry_technical_report/      — Technical report (Quarto)
│   └── technical-report.qmd
│
├── nycferry.scss                    — Light theme styles (shared by app and report)
├── nycferry-dark.scss               — Dark theme styles
├── process_geojson.R                — GeoJSON processing script
├── visualize_geojson.R              — GeoJSON visualization script
└── _quarto.yml                      — Quarto project configuration
```
