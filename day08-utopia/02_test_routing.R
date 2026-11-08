## Adapted from Nathaniel Henry's city_walkability analysis, released under the MIT License.
## Copyright (c) 2023 Henry Spatial Analysis. See ../LICENSE.

source(file.path(dirname(sub("^--file=", "", grep(
  "^--file=", commandArgs(trailingOnly = FALSE), value = TRUE
)[[1]])), "walkability_helpers.R"))
inputs <- read_routing_inputs()

set.seed(20261108)
sample_size <- min(20L, nrow(inputs$origins))
sampled_origins <- inputs$origins[
  sample(seq_len(nrow(inputs$origins)), sample_size),
  ,
  drop = FALSE
]

r5r_core <- start_r5_network()

sample_times <- calculate_nearest_times(
  r5r_core = r5r_core,
  origins = sampled_origins,
  destinations = inputs$destinations,
  batch_size = sample_size,
  max_trip_duration = 120L
)
stop_r5_network(r5r_core)

finite_by_category <- vapply(
  unname(category_fields),
  function(field) sum(is.finite(sample_times[[field]])),
  integer(1)
)
if (any(finite_by_category == 0L)) {
  stop(
    paste(
      "Routing test failed; no finite walking routes for:",
      paste(names(finite_by_category)[finite_by_category == 0L], collapse = ", ")
    ),
    call. = FALSE
  )
}

utils::write.csv(
  sample_times,
  file.path(results_dir, "routing_test.csv"),
  row.names = FALSE,
  na = ""
)
message(sprintf("Routing test passed for %d sampled cells.", sample_size))
for (category in names(finite_by_category)) {
  message(sprintf("  %s: %d/%d cells routed", category, finite_by_category[[category]], sample_size))
}
