spatial aggregation pattern (st_make_grid → st_join → group_by(grid_id))

Filtering to moving vessels (sog > 0.5)

ping count is not the same as vessel count!

A large slow-moving tanker sitting in the harbor for 6 hours will 
generate far more pings than a fast-moving tug that crosses a cell in 2 minutes.

WE WANT: how many distinct vessels were in a cell during a time window.
THUS: count distinct MMSIs per cell per time window rather than raw pings