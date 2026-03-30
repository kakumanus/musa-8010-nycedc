# Baseline:
- Linear Regression
  - Can do stepwise with the feature list
  
  
  
# Predictice Model
- Logistic regression, focused on probability of severe delay (>10 mins)
- Issues: Severe delays are very under-represented in our data. So we need to make sure
  the modeling pipeline reflects that.
- We will look at precision and recall
  - Maximizing recall (sensitivity) means catching as many true positives as poss, but can result in false positives
  - Maximizing precision -> might miss a lot of true positives, but have more certainty with predictions

- Tuning parameters:
  - under-ratio tests:
  | Metric    | ratio=1 | ratio=3 | ratio=10 |
  |-----------|---------|---------|----------|
  | ROC AUC   | 0.707   | 0.706   | 0.704    |
  | Precision | 0.040   | 0.068   | 0.114    |
  | Recall    | 0.566   | 0.194   | 0.021    |
  | F1        | 0.074   | 0.089   | 0.043    |
  
  
**Features:**  
dep_hour — hour of departure
schedule_season — WINTER, SPRING, SUMMER_1, SUMMER_2, FALL
schedule_daytype — WEEKDAY, WEEKEND, HOLIDAY
day_of_week — Mon through Sun
route — ER, RW, GI, etc.
direction — NB or SB
stop_sequence — position of stop within the route
vessel_capacity — 150 or 350 passenger vessel
turn_slack_sched_min — scheduled turnaround buffer
median_vessel_count — median unique vessels in 500m buffer around stop, from AIS historical averages
  
  
  