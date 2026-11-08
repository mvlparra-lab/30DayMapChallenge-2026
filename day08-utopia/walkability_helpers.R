category_fields <- c(
  supermarket = "supermarket_min",
  park_entrance = "park_entrance_min",
  school = "school_min",
  pharmacy = "pharmacy_min",
  transit_stop = "transit_stop_min"
)

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) {
  stop("Could not determine the script path from Rscript arguments.", call. = FALSE)
}

script_path <- normalizePath(
  sub("^--file=", "", script_argument[[1]]),
  winslash = "/",
  mustWork = TRUE
)
project_dir <- normalizePath(
  file.path(dirname(script_path), ".."),
  winslash = "/",
  mustWork = TRUE
)
input_data_dir <- normalizePath(
  file.path(project_dir, "..", "augsburg_15_minute_city", "data"),
  winslash = "/",
  mustWork = TRUE
)
prepared_data_dir <- file.path(project_dir, "data")
results_dir <- file.path(project_dir, "results")
network_dir <- file.path(prepared_data_dir, "r5_network")

dir.create(prepared_data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(network_dir, recursive = TRUE, showWarnings = FALSE)

require_package <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop(
      sprintf("Required R package '%s' is not installed.", package),
      call. = FALSE
    )
  }
}

read_routing_inputs <- function() {
  origins_path <- file.path(prepared_data_dir, "origins.csv")
  destinations_path <- file.path(prepared_data_dir, "destinations.csv")
  if (!file.exists(origins_path) || !file.exists(destinations_path)) {
    stop("Prepared routing inputs are missing; run 01_prepare_inputs.R first.", call. = FALSE)
  }

  origins <- utils::read.csv(origins_path, stringsAsFactors = FALSE)
  destinations <- utils::read.csv(destinations_path, stringsAsFactors = FALSE)
  required_origin_fields <- c("id", "lon", "lat")
  required_destination_fields <- c("id", "category", "lon", "lat")
  if (!all(required_origin_fields %in% names(origins))) {
    stop("origins.csv is missing required fields.", call. = FALSE)
  }
  if (!all(required_destination_fields %in% names(destinations))) {
    stop("destinations.csv is missing required fields.", call. = FALSE)
  }
  if (!nrow(origins)) {
    stop("No residential origins were prepared.", call. = FALSE)
  }
  absent_categories <- setdiff(names(category_fields), unique(destinations$category))
  if (length(absent_categories)) {
    stop(
      paste("No destinations were prepared for:", paste(absent_categories, collapse = ", ")),
      call. = FALSE
    )
  }
  list(origins = origins, destinations = destinations)
}

start_r5_network <- function(memory_gb = 6L) {
  require_package("r5r")
  options(java.parameters = sprintf("-Xmx%dG", as.integer(memory_gb)))
  library(r5r)

  pbf_path <- file.path(network_dir, "Augsburg.osm.pbf")
  if (!file.exists(pbf_path)) {
    stop("R5 network PBF is missing; run 01_prepare_inputs.R first.", call. = FALSE)
  }
  network <- r5r::setup_r5(data_path = network_dir, verbose = TRUE)
  if (is.null(network) || !inherits(network, "r5r_network")) {
    stop(
      paste(
        "r5r::setup_r5() did not create an R5 network.",
        "Confirm that the R5 JAR can be downloaded or supplied in the r5r cache."
      ),
      call. = FALSE
    )
  }
  network
}

calculate_nearest_times <- function(
  r5r_core,
  origins,
  destinations,
  batch_size = 100L,
  max_trip_duration = 120L,
  workers = max(1L, min(4L, parallel::detectCores(logical = TRUE) - 1L))
) {
  output <- data.frame(id = origins$id, stringsAsFactors = FALSE)
  for (field in unname(category_fields)) {
    output[[field]] <- NA_real_
  }

  origin_batches <- split(
    seq_len(nrow(origins)),
    ceiling(seq_len(nrow(origins)) / as.integer(batch_size))
  )

  for (category in names(category_fields)) {
    category_destinations <- destinations[
      destinations$category == category,
      c("id", "lon", "lat"),
      drop = FALSE
    ]
    field <- unname(category_fields[[category]])
    message(
      sprintf(
        "Routing category '%s': %d destinations, %d origin batches.",
        category,
        nrow(category_destinations),
        length(origin_batches)
      )
    )

    for (batch_number in seq_along(origin_batches)) {
      indices <- origin_batches[[batch_number]]
      batch_origins <- origins[indices, c("id", "lon", "lat"), drop = FALSE]
      travel_times <- r5r::travel_time_matrix(
        r5r_network = r5r_core,
        origins = batch_origins,
        destinations = category_destinations,
        mode = "WALK",
        max_walk_time = max_trip_duration,
        max_trip_duration = as.integer(max_trip_duration),
        n_threads = as.integer(workers),
        verbose = FALSE,
        progress = FALSE
      )
      if (!nrow(travel_times)) {
        next
      }

      nearest <- stats::aggregate(
        travel_time_p50 ~ from_id,
        data = travel_times,
        FUN = min,
        na.rm = TRUE
      )
      nearest <- nearest[is.finite(nearest$travel_time_p50), , drop = FALSE]
      result_indices <- match(nearest$from_id, output$id)
      output[[field]][result_indices] <- nearest$travel_time_p50
    }
  }

  output
}

stop_r5_network <- function(r5r_core) {
  r5r::stop_r5(r5r_core)
}
