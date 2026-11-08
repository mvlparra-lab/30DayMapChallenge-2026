## Adapted from Nathaniel Henry's city_walkability analysis, released under the MIT License.
## Copyright (c) 2023 Henry Spatial Analysis. See ../LICENSE.

script_file <- sub(
  "^--file=",
  "",
  grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[[1]]
)
source(file.path(dirname(script_file), "walkability_helpers.R"))
require_package("sf")

working_crs <- 25832
destination_buffer_m <- 2500
grid_size_m <- 100
park_entrance_tolerance_m <- 30

boundary_path <- file.path(input_data_dir, "Augsburg_boundary.geojson")
features_path <- file.path(
  input_data_dir,
  "feature_extract",
  "Augsburg-geopackage",
  "Augsburg.gpkg"
)
source_pbf <- file.path(input_data_dir, "Augsburg.osm.pbf")
target_pbf <- file.path(network_dir, "Augsburg.osm.pbf")

for (path in c(boundary_path, features_path, source_pbf)) {
  if (!file.exists(path)) {
    stop(sprintf("Required input file does not exist: %s", path), call. = FALSE)
  }
}
if (!file.copy(source_pbf, target_pbf, overwrite = TRUE)) {
  stop("Could not copy the OSM PBF into the analysis network folder.", call. = FALSE)
}

boundary <- sf::st_read(boundary_path, quiet = TRUE) |>
  sf::st_transform(working_crs) |>
  sf::st_make_valid()
city_geometry <- sf::st_union(sf::st_geometry(boundary))
destination_roi <- sf::st_buffer(city_geometry, destination_buffer_m)
osm_bbox_filter <- sf::st_as_text(sf::st_transform(destination_roi, 4326))

read_other_tag <- function(tags, key) {
  tag_text <- ifelse(is.na(tags), "", tags)
  pattern <- paste0('"', key, '"\\s*=>\\s*"([^"]*)"')
  matches <- regexec(pattern, tag_text, perl = TRUE)
  extracted <- regmatches(tag_text, matches)
  vapply(extracted, function(value) {
    if (length(value) < 2L) NA_character_ else value[[2]]
  }, character(1))
}

read_layer_tags <- function(features, keys) {
  attributes <- sf::st_drop_geometry(features)
  output <- setNames(vector("list", length(keys)), keys)
  for (key in keys) {
    direct <- if (key %in% names(attributes)) {
      as.character(attributes[[key]])
    } else {
      rep(NA_character_, nrow(attributes))
    }
    extra <- read_other_tag(attributes$other_tags, key)
    missing <- is.na(direct) | direct == ""
    direct[missing] <- extra[missing]
    output[[key]] <- direct
  }
  output
}

within_destination_roi <- function(features) {
  lengths(sf::st_intersects(features, destination_roi)) > 0L
}

make_point_destinations <- function(features, category) {
  if (!nrow(features)) {
    return(NULL)
  }
  result <- sf::st_sf(
    category = category,
    osm_id = as.character(sf::st_drop_geometry(features)$osm_id),
    geometry = sf::st_geometry(features)
  )
  result[within_destination_roi(result), , drop = FALSE]
}

make_polygon_destinations <- function(features, category) {
  if (!nrow(features)) {
    return(NULL)
  }
  result <- sf::st_sf(
    category = category,
    osm_id = as.character(sf::st_drop_geometry(features)$osm_id),
    geometry = sf::st_point_on_surface(sf::st_geometry(features))
  )
  result[within_destination_roi(result), , drop = FALSE]
}

message("Reading OSM polygons within the destination search extent...")
polygons <- sf::st_read(
  features_path,
  layer = "multipolygons",
  quiet = TRUE,
  wkt_filter = osm_bbox_filter
) |>
  sf::st_transform(working_crs)
polygon_tags <- read_layer_tags(
  polygons,
  c("shop", "amenity", "leisure", "landuse", "building", "access")
)

polygon_destinations <- list(
  make_polygon_destinations(
    polygons[which(polygon_tags$shop == "supermarket"), , drop = FALSE],
    "supermarket"
  ),
  make_polygon_destinations(
    polygons[which(polygon_tags$amenity == "school"), , drop = FALSE],
    "school"
  ),
  make_polygon_destinations(
    polygons[which(
      polygon_tags$amenity == "pharmacy" | polygon_tags$shop == "chemist"
    ), , drop = FALSE],
    "pharmacy"
  )
)

public_park_indices <- which(
  polygon_tags$leisure == "park" &
    !(polygon_tags$access %in% c("private", "no"))
)
public_parks <- polygons[public_park_indices, , drop = FALSE]

residential_buildings <- c(
  "apartments", "bungalow", "detached", "dormitory", "house",
  "houseboat", "residential", "semidetached_house", "static_caravan", "terrace"
)
residential_indices <- which(
  polygon_tags$landuse == "residential" |
    polygon_tags$building %in% residential_buildings
)
residential_areas <- polygons[residential_indices, , drop = FALSE]
if (!nrow(residential_areas)) {
  stop("No residential OSM polygons were found for constructing the grid.", call. = FALSE)
}
residential_geometry <- sf::st_union(
  sf::st_make_valid(sf::st_geometry(residential_areas))
)
rm(polygons, polygon_tags, residential_areas)
invisible(gc())

message("Reading OSM points within the destination search extent...")
points <- sf::st_read(
  features_path,
  layer = "points",
  quiet = TRUE,
  wkt_filter = osm_bbox_filter
) |>
  sf::st_transform(working_crs)
point_tags <- read_layer_tags(
  points,
  c(
    "shop", "amenity", "barrier", "highway", "entrance",
    "access", "railway", "public_transport"
  )
)

point_destinations <- list(
  make_point_destinations(
    points[which(point_tags$shop == "supermarket"), , drop = FALSE],
    "supermarket"
  ),
  make_point_destinations(
    points[which(point_tags$amenity == "school"), , drop = FALSE],
    "school"
  ),
  make_point_destinations(
    points[which(
      point_tags$amenity == "pharmacy" | point_tags$shop == "chemist"
    ), , drop = FALSE],
    "pharmacy"
  )
)

park_entrance_mask <- (
  point_tags$barrier == "entrance" |
    point_tags$entrance %in% c("yes", "main", "exit", "staircase")
) & !(point_tags$access %in% c("private", "no"))
park_entrance_candidates <- points[which(park_entrance_mask), , drop = FALSE]
if (nrow(public_parks) && nrow(park_entrance_candidates)) {
  associated_entrances <- lengths(sf::st_is_within_distance(
    park_entrance_candidates,
    public_parks,
    dist = park_entrance_tolerance_m
  )) > 0L
  park_entrances <- make_point_destinations(
    park_entrance_candidates[associated_entrances, , drop = FALSE],
    "park_entrance"
  )
} else {
  park_entrances <- NULL
}

transit_mask <- point_tags$highway == "bus_stop" |
  point_tags$public_transport %in% c("platform", "stop_position", "station") |
  point_tags$railway %in% c("tram_stop", "station", "halt", "subway_entrance")
transit_stops <- make_point_destinations(
  points[which(transit_mask), , drop = FALSE],
  "transit_stop"
)
rm(points, point_tags, public_parks, park_entrance_candidates)
invisible(gc())

destinations_sf <- do.call(rbind, c(
  polygon_destinations,
  point_destinations,
  list(park_entrances, transit_stops)
))
if (is.null(destinations_sf) || !nrow(destinations_sf)) {
  stop("No OSM destinations were found in the search extent.", call. = FALSE)
}

grid_geometry <- sf::st_make_grid(
  city_geometry,
  cellsize = grid_size_m,
  square = TRUE,
  what = "polygons"
)
grid <- sf::st_sf(
  cell_id = sprintf("AUG%07d", seq_along(grid_geometry)),
  geometry = grid_geometry
)
centers <- sf::st_centroid(sf::st_geometry(grid))
inside_city <- lengths(sf::st_intersects(centers, city_geometry)) > 0L
inside_residential <- lengths(sf::st_intersects(centers, residential_geometry)) > 0L
grid <- grid[inside_city & inside_residential, , drop = FALSE]
if (!nrow(grid)) {
  stop("No 100 m cell centroids fell inside mapped residential areas.", call. = FALSE)
}

origin_wgs84 <- sf::st_coordinates(sf::st_transform(
  sf::st_centroid(sf::st_geometry(grid)),
  4326
))
origins <- data.frame(
  id = grid$cell_id,
  lon = origin_wgs84[, "X"],
  lat = origin_wgs84[, "Y"],
  stringsAsFactors = FALSE
)

destinations_wgs84 <- sf::st_transform(destinations_sf, 4326)
destination_xy <- sf::st_coordinates(destinations_wgs84)
destinations <- data.frame(
  id = sprintf("DEST%07d", seq_len(nrow(destinations_wgs84))),
  category = destinations_wgs84$category,
  osm_id = destinations_wgs84$osm_id,
  lon = destination_xy[, "X"],
  lat = destination_xy[, "Y"],
  stringsAsFactors = FALSE
)
destinations <- destinations[
  !duplicated(destinations[c("category", "lon", "lat")]),
  ,
  drop = FALSE
]

destination_counts <- table(factor(
  destinations$category,
  levels = names(category_fields)
))
if (any(destination_counts == 0L)) {
  empty_categories <- names(destination_counts)[destination_counts == 0L]
  stop(
    paste("No mapped destinations found for:", paste(empty_categories, collapse = ", ")),
    call. = FALSE
  )
}

utils::write.csv(origins, file.path(prepared_data_dir, "origins.csv"), row.names = FALSE)
utils::write.csv(
  destinations,
  file.path(prepared_data_dir, "destinations.csv"),
  row.names = FALSE
)

report <- c(
  "Augsburg walking accessibility input preparation",
  sprintf("Municipal boundary: %s", boundary_path),
  sprintf("Working CRS: EPSG:%d", working_crs),
  sprintf("Grid size: %d m; residential centroid-filtered cells: %d", grid_size_m, nrow(grid)),
  sprintf("Destination search buffer: %d m", destination_buffer_m),
  sprintf("OSM PBF copied to: %s", target_pbf),
  "Destination counts:",
  sprintf("  %s: %d", names(destination_counts), as.integer(destination_counts))
)
writeLines(report, file.path(results_dir, "preparation_report.txt"))

message(sprintf("Prepared %d residential origins.", nrow(origins)))
message(paste(
  sprintf("%s=%d", names(destination_counts), as.integer(destination_counts)),
  collapse = "; "
))
