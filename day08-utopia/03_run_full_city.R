## Adapted from Nathaniel Henry's city_walkability analysis, released under the MIT License.
## Copyright (c) 2023 Henry Spatial Analysis. See ../LICENSE.

source(file.path(dirname(sub("^--file=", "", grep(
  "^--file=", commandArgs(trailingOnly = FALSE), value = TRUE
)[[1]])), "walkability_helpers.R"))
require_package("sf")
inputs <- read_routing_inputs()

test_path <- file.path(results_dir, "routing_test.csv")
if (!file.exists(test_path)) {
  stop("The routing test has not been run; run 02_test_routing.R first.", call. = FALSE)
}

r5r_core <- start_r5_network()

walking_times <- calculate_nearest_times(
  r5r_core = r5r_core,
  origins = inputs$origins,
  destinations = inputs$destinations,
  batch_size = 100L,
  max_trip_duration = 120L
)
stop_r5_network(r5r_core)

times <- as.matrix(walking_times[, unname(category_fields), drop = FALSE])
complete_rows <- stats::complete.cases(times)
all_within_15 <- rep(NA_integer_, nrow(walking_times))
all_within_15[complete_rows] <- as.integer(
  apply(times[complete_rows, , drop = FALSE] <= 15, 1, all)
)
access_status <- ifelse(
  !complete_rows,
  "missing_data",
  ifelse(all_within_15 == 1L, "all_within_15_minutes", "over_15_minutes")
)

cell_lookup <- match(walking_times$id, inputs$origins$id)
grid_centers <- data.frame(
  cell_id = inputs$origins$id,
  lon = inputs$origins$lon,
  lat = inputs$origins$lat,
  stringsAsFactors = FALSE
)
center_coordinates <- sf::st_coordinates(sf::st_transform(
  sf::st_as_sf(grid_centers, coords = c("lon", "lat"), crs = 4326, remove = FALSE),
  25832
))
grid <- sf::st_sf(
  cell_id = walking_times$id,
  cell_area_m2 = 10000,
  walking_times[, unname(category_fields), drop = FALSE],
  all_five_within_15 = all_within_15,
  access_status = access_status,
  center_lon = grid_centers$lon[cell_lookup],
  center_lat = grid_centers$lat[cell_lookup],
  geometry = sf::st_sfc(lapply(seq_len(nrow(center_coordinates)), function(i) {
    x <- center_coordinates[i, "X"]
    y <- center_coordinates[i, "Y"]
    sf::st_polygon(list(rbind(
      c(x - 50, y - 50),
      c(x + 50, y - 50),
      c(x + 50, y + 50),
      c(x - 50, y + 50),
      c(x - 50, y - 50)
    )))
  }), crs = 25832)
)

csv_output <- file.path(results_dir, "augsburg_walkability.csv")
utils::write.csv(
  sf::st_drop_geometry(grid),
  csv_output,
  row.names = FALSE,
  na = ""
)

total_cells <- nrow(grid)
summary_rows <- list()
add_summary <- function(
  metric,
  category,
  count,
  denominator,
  valid_route_denominator = NA_integer_
) {
  summary_rows[[length(summary_rows) + 1L]] <<- data.frame(
    metric = metric,
    category = category,
    count = as.integer(count),
    denominator = as.integer(denominator),
    percentage = if (denominator > 0L) 100 * count / denominator else NA_real_,
    valid_route_denominator = as.integer(valid_route_denominator),
    valid_route_percentage = if (
      !is.na(valid_route_denominator) &&
        valid_route_denominator > 0L &&
        metric != "missing_data"
    ) {
      100 * count / valid_route_denominator
    } else {
      NA_real_
    },
    stringsAsFactors = FALSE
  )
}

status_levels <- c("all_within_15_minutes", "over_15_minutes", "missing_data")
for (status in status_levels) {
  add_summary(
    metric = status,
    category = "all_five",
    count = sum(access_status == status),
    denominator = total_cells
  )
}
for (category in names(category_fields)) {
  field <- unname(category_fields[[category]])
  valid <- is.finite(grid[[field]])
  within <- valid & grid[[field]] <= 15
  over <- valid & grid[[field]] > 15
  missing <- !valid
  add_summary(
    "within_15_minutes", category, sum(within), total_cells, sum(valid)
  )
  add_summary(
    "over_15_minutes", category, sum(over), total_cells, sum(valid)
  )
  add_summary(
    "missing_data", category, sum(missing), total_cells, sum(valid)
  )
}
summary_table <- do.call(rbind, summary_rows)
utils::write.csv(
  summary_table,
  file.path(results_dir, "augsburg_walkability_summary.csv"),
  row.names = FALSE,
  na = ""
)

destination_sf <- sf::st_as_sf(
  inputs$destinations,
  coords = c("lon", "lat"),
  crs = 4326,
  remove = FALSE
)
destination_sf <- sf::st_transform(destination_sf, 25832)
destination_sf <- destination_sf[, c("id", "category", "osm_id", "geometry")]

gpkg_output <- file.path(results_dir, "augsburg_walkability.gpkg")
if (file.exists(gpkg_output) && !file.remove(gpkg_output)) {
  stop("Could not replace the previous output GeoPackage.", call. = FALSE)
}
sf::st_write(grid, gpkg_output, layer = "walkability_grid", quiet = TRUE)
sf::st_write(
  destination_sf,
  gpkg_output,
  layer = "amenity_destinations",
  append = TRUE,
  quiet = TRUE
)

overall <- summary_table[summary_table$category == "all_five", ]
message(sprintf("Completed %d residential grid cells.", total_cells))
for (i in seq_len(nrow(overall))) {
  message(sprintf(
    "%s: %d/%d (%.1f%%)",
    overall$metric[i],
    overall$count[i],
    overall$denominator[i],
    overall$percentage[i]
  ))
}
message(sprintf("GeoPackage: %s", gpkg_output))
message(sprintf("Cell CSV: %s", csv_output))
message(sprintf(
  "Summary CSV: %s",
  file.path(results_dir, "augsburg_walkability_summary.csv")
))
