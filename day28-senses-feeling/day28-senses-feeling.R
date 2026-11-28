# # Day 28 | Cádiz, Feeling the Heat
#
# **Author:** María Victoria León Parra
# **Challenge:** 30DayMapChallenge 2026 · Day 28 · Senses: Feeling
#
# ## Purpose and sources
# Show annual mean air temperature anomalies from AEMET OpenData station
# 5973 inside the Cádiz peninsula silhouette from IGN-CNIG. Adapt Dominic
# Royé's R tutorial and Ed Hawkins' warming-stripes concept.
# https://dominicroye.github.io/blog/how-to-create-warming-stripes-in-r/index.html
#
# ## Workflow and execution
# Cache AEMET summaries, audit calendar coverage, calculate anomalies,
# intersect annual bands with the projected boundary, and export the halo PNG and PDF.
# Install the README packages, set AEMET_API_KEY or create a local .Renviron,
# and run `Rscript --vanilla day28-senses-feeling.R` from this folder.

# The public AEMET extremes inventory begins in 1955. Retain every year
# in the audit window, including any incomplete first or last year.
station <- "5973"
years <- 1955:2025
preferred_start <- 1991L
minimum_reference_years <- 24L
maximum_reference_gap <- 3L
page_mm <- 300
margin_mm <- 10
dpi <- 300
southern_cut_m <- 4041700
ocean_centre <- "#327B90"
ocean_edge <- "#1B4C5D"
ink <- "#F5F1E8"
muted <- "#D0E1E4"
missing_colour <- "#3F5A66"
coastline_colour <- "#D7ECEB"
side_colour <- "#123D49"

# Layout positions are fractions of the area inside the print margins.
map_padding_m <- 70
map_view <- c(x = 0.421, y = 0.488, width = 0.89, height = 0.89) * c(1, 1, 0.965, 0.965)
legend_position <- c(left = 0.030, top = 0.455, width = 0.180)
north_position <- c(x = 0.045, y = 0.875)
scale_position <- c(x = legend_position[["left"]], y = 0.045)
year_focal_size <- 11
guide_gap_px <- 40
guide_min_px <- 25
guide_label_gap_px <- 24
guide_opacity <- 0.35
legend_note_gap <- 0.066
wave_count <- 10L
wave_spacing_m <- 105
wave_opacity <- 0.21
wave_linewidth <- 0.38
wave_decay <- 1.50
wave_coast_close_m <- 150
wave_vertical_limits <- c(0.063, 0.915)
wave_horizontal_limits <- c(-0.02, 1.02)
wave_fade_width <- 0.14
wave_segment_m <- 12

cache_dir <- file.path("data", "cache", "aemet-monthly")

read_station_year <- function(year) {
  path <- file.path(cache_dir, sprintf("%s-%d.rds", station, year))
  if (file.exists(path)) return(readRDS(path))
  if (!nzchar(Sys.getenv("AEMET_API_KEY"))) {
    stop("Set AEMET_API_KEY or add it to this folder's .Renviron.", call. = FALSE)
  }

  # Capture package diagnostics privately. A no-data response can be cached,
  # whereas a transport, authentication or schema failure must be retried.
  diagnostics <- capture.output({
    result <- tryCatch(
      climaemet::aemet_monthly_clim(station, year, verbose = FALSE, progress = FALSE),
      error = identity
    )
  }, type = "message")
  fail <- function() stop(sprintf(
    "AEMET request failed or returned unexpected data for %s/%d. Check the key and connection, then rerun.",
    station, year
  ), call. = FALSE)
  fields <- c("indicativo", "fecha")
  if (inherits(result, "error")) fail()
  if (is.null(result) || (is.data.frame(result) && nrow(result) == 0L)) {
    if (!any(grepl("HTTP 404", diagnostics, fixed = TRUE))) fail()
    result <- data.frame(indicativo = character(), fecha = character(), tm_mes = numeric())
  } else {
    if (!is.data.frame(result) || !all(fields %in% names(result)) ||
        !all(result$indicativo %in% station) ||
        !all(grepl(sprintf("^%d-(0[1-9]|1[0-3])$", year), result$fecha))) fail()
    # An entire year can lack the temperature field while retaining other data.
    if (!"tm_mes" %in% names(result)) result$tm_mes <- NA_real_
    result <- as.data.frame(result[c(fields, "tm_mes")])
  }
  # Write through a temporary file so interrupted requests leave no partial cache.
  tmp <- tempfile(tmpdir = cache_dir)
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(result, tmp)
  if (!file.rename(tmp, path) && !file.exists(path)) stop("Could not save the AEMET cache.")
  result
}

summarise_year <- function(year, observations) {
  months <- sprintf("%d-%02d", year, 1:12)
  dates <- c(months, sprintf("%d-01", year + 1L))
  days <- as.integer(diff(as.Date(paste0(dates, "-01"))))
  temperature <- suppressWarnings(as.numeric(sub(",", ".", observations$tm_mes, fixed = TRUE)))

  # Each month must have exactly one record and a finite official mean.
  # AEMET encodes the annual summary as month 13.
  counts <- tabulate(match(observations$fecha, months), nbins = 12L)
  monthly <- temperature[match(months, observations$fecha)]
  valid <- counts == 1L & is.finite(monthly)
  complete <- all(valid)
  official <- temperature[which(observations$fecha == sprintf("%d-13", year))]
  has_official <- length(official) == 1L && is.finite(official)
  method <- if (!complete) "excluded" else if (has_official) "AEMET annual" else "day-weighted AEMET monthly"
  annual <- if (!complete) NA_real_ else if (has_official) official else weighted.mean(monthly, days)
  data.frame(year, annual_mean_c = annual, expected_months = 12L,
             valid_months = sum(valid), missing_or_invalid_months = paste(which(!valid), collapse = ";"),
             complete, annual_method = method)
}

reference_years <- function(annual) {
  # Require 80% coverage and avoid a long unobserved part of the reference.
  # Prefer standard 30-year periods before considering rolling alternatives.
  starts <- unique(c(preferred_start, 1981L, 1961L, seq.int(max(years) - 29L, min(years))))
  for (start in starts) {
    window <- start + 0:29
    if (!all(window %in% annual$year)) next
    complete <- annual$complete[match(window, annual$year)]
    runs <- rle(!complete)
    if (sum(complete) >= minimum_reference_years &&
        !any(runs$values & runs$lengths > maximum_reference_gap)) return(window)
  }
  integer()
}

city_geometry <- function() {
  municipality <- sf::st_read(file.path("data", "cadiz-municipality.geojson"), quiet = TRUE)
  stopifnot(nrow(municipality) == 1L, municipality$nationalCode == "34011111012")
  boundary <- sf::st_make_valid(sf::st_transform(sf::st_geometry(municipality), 25829))
  frame <- sf::st_bbox(boundary)
  frame["ymin"] <- southern_cut_m
  clipped <- sf::st_intersection(boundary, sf::st_as_sfc(frame))
  if (any(sf::st_geometry_type(clipped) == "GEOMETRYCOLLECTION")) {
    clipped <- sf::st_collection_extract(clipped, "POLYGON")
  }
  pieces <- sf::st_cast(clipped, "POLYGON")
  pieces[which.max(sf::st_area(pieces))]
}

make_stripes <- function(city, annual) {
  frame <- sf::st_bbox(city)
  # Horizontal bands run down the long axis, with the earliest year at the top.
  # Intersect real polygons in metres so the coastline keeps its proportions.
  edges <- seq(frame[["ymax"]], frame[["ymin"]], length.out = nrow(annual) + 1L)
  bands <- lapply(seq_len(nrow(annual)), function(i) {
    band <- frame
    band[c("ymin", "ymax")] <- c(edges[i + 1L], edges[i])
    sf::st_as_sfc(band)[[1L]]
  })
  stripes <- sf::st_sf(annual, geometry = sf::st_sfc(bands, crs = sf::st_crs(city)))
  clipped <- suppressWarnings(sf::st_intersection(stripes, city))
  stopifnot(identical(clipped$year, annual$year))
  clipped
}

# Build the printed face and swept sides at print resolution from the same rings.
# One face raster gives every stripe a shared edge in both export devices.
silhouette_layers <- function(city, stripes, gradient, limit, metres_per_mm) {
  pixels_per_mm <- dpi / 25.4
  metres_per_pixel <- metres_per_mm / pixels_per_mm
  sigma <- 1 * pixels_per_mm
  radius <- ceiling(4 * sigma)
  depth <- 0.5 * pixels_per_mm
  padding <- ceiling(2 * radius + depth + 1)
  weights <- stats::dnorm(seq.int(-radius, radius), sd = sigma)
  weights <- weights / sum(weights)

  bounds <- sf::st_bbox(city)
  left <- bounds[["xmin"]] - padding * metres_per_pixel
  bottom <- bounds[["ymin"]] - padding * metres_per_pixel
  width <- ceiling(diff(bounds[c("xmin", "xmax")]) / metres_per_pixel) + 2 * padding
  height <- ceiling(diff(bounds[c("ymin", "ymax")]) / metres_per_pixel) + 2 * padding
  xy <- sf::st_coordinates(city)
  x <- (xy[, "X"] - left) / (width * metres_per_pixel)
  y <- (xy[, "Y"] - bottom) / (height * metres_per_pixel)
  ring <- xy[, "L1"]
  white <- grid::gpar(fill = "white", col = NA)
  land <- function(dx = 0, dy = 0) {
    grid::grid.path(x + dx, y + dy, id = ring, rule = "evenodd", gp = white)
  }
  capture_mask <- function(draw) {
    capture <- ragg::agg_capture(width, height, units = "px", background = "black")
    on.exit(grDevices::dev.off())
    grid::grid.newpage()
    draw()
    matrix(bitwAnd(as.integer(capture(native = TRUE)), 255L) / 255,
           nrow = height, byrow = TRUE)
  }
  face <- capture_mask(land)
  # Sweep every coastline and hole edge into a quadrilateral. The end faces
  # and joined quadrilaterals form the solid piece without repeated outlines.
  solid <- capture_mask(function() {
    dx <- depth / width
    dy <- -depth / height
    land()
    land(dx, dy)
    edge <- which(head(ring, -1L) == tail(ring, -1L))
    next_vertex <- edge + 1L
    grid::grid.polygon(
      c(rbind(x[edge], x[next_vertex], x[next_vertex] + dx, x[edge] + dx)),
      c(rbind(y[edge], y[next_vertex], y[next_vertex] + dy, y[edge] + dy)),
      id = rep(seq_along(edge), each = 4L), gp = white
    )
  })

  # Assign each pixel row to a band using its centre and geographic y.
  rows_y <- bottom + (height - seq_len(height) + 0.5) * metres_per_pixel
  band <- floor((bounds[["ymax"]] - rows_y) / diff(bounds[c("ymin", "ymax")]) * nrow(stripes)) + 1L
  band <- pmax(1L, pmin(nrow(stripes), band))
  anomaly <- pmax(-limit, pmin(limit, stripes$anomaly_c))
  colours <- gradient[round((anomaly + limit) / (2 * limit) * (length(gradient) - 1L)) + 1L]
  colours[is.na(colours)] <- missing_colour
  layer <- function(colour, alpha, offset = 0) {
    channels <- grDevices::col2rgb(colour) / 255
    raster <- as.raster(matrix(grDevices::rgb(channels[1, ], channels[2, ], channels[3, ],
                                              alpha = pmin(1, alpha)), nrow = height))
    ggplot2::annotation_custom(grid::rasterGrob(raster, interpolate = FALSE),
                              xmin = left + offset, xmax = left + width * metres_per_pixel + offset,
                              ymin = bottom - offset, ymax = bottom + height * metres_per_pixel - offset)
  }
  # Blur the complete upper silhouette once. Padding keeps its Gaussian tails
  # clear of the raster edge, and the thin side is drawn above the shadow.
  shadow <- apply(face, 2, stats::filter, filter = weights)
  shadow[is.na(shadow)] <- 0
  shadow <- t(apply(shadow, 1, stats::filter, filter = weights))
  shadow[is.na(shadow)] <- 0
  list(layer("#000000", 0.30 * shadow, 0.3 * metres_per_mm),
       layer(side_colour, solid), layer(colours[band], face))
}

ocean_background <- function() {
  # Sample one smooth gradient for both graphics devices. Radius reaches one
  # at each page edge, with the lightest point centred behind the silhouette.
  positions <- seq(0, 1, length.out = 768)
  distance <- function(centre) {
    (positions - centre) / ifelse(positions < centre, centre, 1 - centre)
  }
  radius <- pmin(sqrt(outer(distance(1 - map_view[["y"]])^2,
                            distance(map_view[["x"]])^2, "+")), 1)
  mix <- radius^2 * (3 - 2 * radius)
  colours <- grDevices::colorRamp(c(ocean_centre, ocean_edge), space = "Lab")(as.vector(mix))
  grid::grid.raster(as.raster(matrix(grDevices::rgb(colours, maxColorValue = 255),
                                     nrow = length(positions))),
                    width = 1, height = 1, interpolate = TRUE)
}

draw_map <- function(city, stripes, reference) {
  frame <- sf::st_bbox(city)
  x_limits <- unname(frame[c("xmin", "xmax")]) + c(-1, 1) * map_padding_m
  y_limits <- unname(frame[c("ymin", "ymax")]) + c(-1, 1) * map_padding_m
  map_width <- map_view[["width"]]
  map_height <- map_view[["height"]]
  map_x <- map_view[["x"]]
  map_y <- map_view[["y"]]
  content_mm <- page_mm - 2 * margin_mm
  metres_per_mm <- max(diff(x_limits) / (map_width * content_mm),
                       diff(y_limits) / (map_height * content_mm))
  panel_half_width <- diff(x_limits) / (2 * metres_per_mm * content_mm)
  panel_half_height <- diff(y_limits) / (2 * metres_per_mm * content_mm)
  # Anchor both cartographic elements to the print area while ggspatial
  # still computes the distance and true north from the projected map.
  north_pad_x <- (north_position[["x"]] - (map_x - panel_half_width)) * content_mm - 4
  north_pad_y <- (map_y + panel_half_height - north_position[["y"]]) * content_mm - 7.5
  scale_pad_x <- (scale_position[["x"]] - (map_x - panel_half_width)) * content_mm
  scale_pad_y <- (scale_position[["y"]] - (map_y - panel_half_height)) * content_mm
  # Round the 95th percentile outward to a readable tenth of a degree.
  limit <- max(0.1, ceiling(10 * stats::quantile(abs(stripes$anomaly_c), 0.95, na.rm = TRUE)) / 10)
  palette <- rev(RColorBrewer::brewer.pal(11, "RdBu"))
  gradient <- grDevices::colorRampPalette(palette, space = "Lab")(1025)
  # Keep the lettering above the arrowhead inside the true-north grob.
  north_style <- function(...) {
    grid::grobTree(
      grid::textGrob("N", x = 0.5, y = 0.85,
                     gp = grid::gpar(fontfamily = "Roboto", fontsize = 10, col = muted)),
      grid::segmentsGrob(x0 = 0.5, x1 = 0.5, y0 = 0.08, y1 = 0.59,
                         arrow = grid::arrow(length = grid::unit(2, "mm"), type = "closed"),
                         gp = grid::gpar(col = muted, fill = muted))
    )
  }
  # Use exterior rings only. Close narrow harbour entrances for the waves
  # while leaving the printed coastline and its holes intact.
  exterior <- function(geometry) {
    polygons <- sf::st_cast(geometry, "POLYGON")
    sf::st_sfc(lapply(polygons, function(polygon) sf::st_polygon(polygon[1L])),
               crs = sf::st_crs(city))
  }
  land <- sf::st_union(exterior(city))
  wave_land <- sf::st_union(exterior(sf::st_buffer(sf::st_buffer(land, wave_coast_close_m),
                                                  -wave_coast_close_m)))
  # Densify lines so opacity can change gradually along each wave. A smooth
  # ramp reaches zero before the title, footer and sides of the wave field.
  edge_fade <- function(position, limits) {
    t <- pmax(0, pmin(1, (position - limits[1]) / wave_fade_width,
                      (limits[2] - position) / wave_fade_width))
    # The quintic ramp flattens at both ends, softening the last visible segments.
    t^3 * (10 - 15 * t + 6 * t^2)
  }
  waves <- do.call(rbind, lapply(seq_len(wave_count), function(index) {
    outline <- sf::st_boundary(exterior(sf::st_buffer(wave_land, index * wave_spacing_m)))
    lines <- sf::st_cast(sf::st_segmentize(outline, dfMaxLength = wave_segment_m), "LINESTRING")
    radial_fade <- (1 - (index - 1) / max(1L, wave_count - 1L))^wave_decay
    do.call(rbind, lapply(lines, function(line) {
      xy <- sf::st_coordinates(line)
      start <- xy[-nrow(xy), , drop = FALSE]
      end <- xy[-1L, , drop = FALSE]
      middle <- (start + end) / 2
      x <- map_x + (middle[, "X"] - mean(x_limits)) / (content_mm * metres_per_mm)
      y <- map_y + (middle[, "Y"] - mean(y_limits)) / (content_mm * metres_per_mm)
      opacity <- wave_opacity * radial_fade *
        edge_fade(x, wave_horizontal_limits) * edge_fade(y, wave_vertical_limits)
      segments <- data.frame(x = start[, "X"], y = start[, "Y"],
                             xend = end[, "X"], yend = end[, "Y"], opacity)
      segments[opacity > 0, ]
    }))
  }))
  map <- ggplot2::ggplot() +
    ggplot2::geom_segment(data = waves, ggplot2::aes(x, y, xend = xend, yend = yend, alpha = opacity),
                          colour = coastline_colour, linewidth = wave_linewidth, show.legend = FALSE) +
    ggplot2::scale_alpha_identity() +
    silhouette_layers(city, stripes, gradient, limit, metres_per_mm) +
    # The light rim belongs only to the upper face of the solid cut-out.
    ggplot2::geom_sf(data = sf::st_sf(geometry = city), fill = NA,
                    colour = coastline_colour, linewidth = 0.13) +
    ggspatial::annotation_scale(location = "bl", width_hint = 0.23, text_family = "Roboto",
                               pad_x = grid::unit(scale_pad_x, "mm"),
                               pad_y = grid::unit(scale_pad_y, "mm"),
                               text_col = ink, line_col = muted, bar_cols = c(ink, ocean_edge),
                               line_width = 0.25, text_cex = 0.65) +
    ggspatial::annotation_north_arrow(location = "tl", which_north = "true",
                                     pad_x = grid::unit(north_pad_x, "mm"),
                                     pad_y = grid::unit(north_pad_y, "mm"),
                                     height = grid::unit(15, "mm"), width = grid::unit(8, "mm"),
                                     style = north_style) +
    ggplot2::coord_sf(xlim = x_limits, ylim = y_limits, expand = FALSE, datum = NA, clip = "off") +
    ggplot2::theme_void() +
    ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0))

  grid::grid.newpage()
  ocean_background()
  inset <- (page_mm - 2 * margin_mm) / page_mm
  grid::pushViewport(grid::viewport(width = inset, height = inset))
  label <- function(text, y, size, x = 0.5, colour = ink, face = "plain") {
    grid::grid.text(text, x, y, gp = grid::gpar(fontfamily = "Roboto", fontsize = size,
                                              fontface = face, col = colour))
  }
  print(map, vp = grid::viewport(x = map_x, y = map_y, width = map_width, height = map_height))
  label("Day 28 | Cádiz, Feeling the Heat", 0.956, 34, face = "bold")

  # Locate the rightmost coastline at each exact stripe centre. Convert
  # projected metres to page coordinates using the same fit as coord_sf.
  focal <- max(stripes$year[is.finite(stripes$anomaly_c)])
  tick_years <- intersect(stripes$year, unique(c(1955, 1975, 1990, 2000, 2010, 2025, focal)))
  focal_text <- sprintf("%d · %+.2f °C", focal, stripes$anomaly_c[match(focal, stripes$year)])
  focal_style <- grid::gpar(fontfamily = "Roboto", fontsize = year_focal_size,
                            fontface = "bold", col = ink)
  focal_width <- grid::convertWidth(grid::grobWidth(grid::textGrob(focal_text, gp = focal_style)),
                                    "npc", valueOnly = TRUE)
  # Mirror the legend's left gutter at the right end of the focal label.
  year_x <- 1 - legend_position[["left"]] - focal_width
  content_px <- content_mm * dpi / 25.4
  guide_end <- year_x - guide_label_gap_px / content_px
  for (year in tick_years) {
    i <- match(year, stripes$year)
    stripe_bounds <- sf::st_bbox(sf::st_geometry(stripes)[i])
    y <- mean(stripe_bounds[c("ymin", "ymax")])
    cross_section <- sf::st_sfc(sf::st_linestring(cbind(x_limits, c(y, y))), crs = sf::st_crs(city))
    edge <- sf::st_bbox(sf::st_intersection(city, cross_section))[["xmax"]]
    page_x <- map_x + (edge - mean(x_limits)) / (metres_per_mm * content_mm)
    page_y <- map_y + (y - mean(y_limits)) / (metres_per_mm * content_mm)
    guide_start <- page_x + guide_gap_px / content_px
    stopifnot((guide_end - guide_start) * content_px >= guide_min_px)
    grid::grid.lines(c(guide_start, guide_end), rep(page_y, 2),
                     gp = grid::gpar(col = grDevices::adjustcolor(muted, alpha.f = guide_opacity), lwd = 0.8))
    text <- if (year == focal) focal_text else year
    grid::grid.text(text, x = year_x, y = page_y, just = "left",
                    gp = if (year == focal) focal_style else
                      grid::gpar(fontfamily = "Roboto", fontsize = 10, col = muted))
  }

  column_x <- legend_position[["left"]] + legend_position[["width"]] / 2
  legend_top <- legend_position[["top"]]
  bar_y <- legend_top - 0.148
  missing_y <- legend_top - 0.271
  label("Temperature anomaly (°C)", legend_top, 11, x = column_x, face = "bold")
  label(sprintf("%d–%d reference (%d/%d years)",
                min(reference), max(reference), sum(stripes$used_in_reference), length(reference)),
        legend_top - 0.026, 9, x = column_x, colour = muted)
  grid::grid.raster(matrix(rev(gradient), ncol = 1), x = column_x, y = bar_y,
                    width = grid::unit(4, "mm"), height = 0.18, interpolate = FALSE)
  high <- if (any(stripes$anomaly_c > limit, na.rm = TRUE)) "≥ " else ""
  # The lower inequality marks the colour scale endpoint by design.
  grid::grid.text(c(sprintf("%s+%g", high, limit), "0", sprintf("≤ −%g", limit)),
                  x = column_x + 0.025, y = bar_y + c(0.09, 0, -0.09), just = "left",
                  gp = grid::gpar(fontfamily = "Roboto", fontsize = 10, col = ink))
  grid::grid.rect(x = column_x - 0.064, y = missing_y, width = grid::unit(3, "mm"),
                  height = grid::unit(3, "mm"), gp = grid::gpar(fill = missing_colour, col = NA))
  label("Incomplete / missing", missing_y, 10, x = column_x + 0.010)
  label(paste("Each stripe is one year.",
              "Colours show change over time,",
              "with no neighbourhood-level",
              "variation encoded.", sep = "\n"),
        missing_y - legend_note_gap, 10, x = column_x, colour = muted)
  label("#30DayMapChallenge | 2026 | Day – 28 | Senses: Feeling | Map by María Victoria León Parra",
        0.015, 11, face = "bold")
  grid::popViewport()
}

export_map <- function(file, city, stripes, reference) {
  if (endsWith(file, ".png")) {
    ragg::agg_png(file, width = page_mm, height = page_mm, units = "mm", res = dpi)
    showtext::showtext_opts(dpi = dpi)
  } else {
    grDevices::pdf(file, width = page_mm / 25.4, height = page_mm / 25.4)
  }
  showtext::showtext_begin()
  on.exit({ showtext::showtext_end(); grDevices::dev.off() }, add = TRUE)
  draw_map(city, stripes, reference)
}

main <- function() {
  if (!nzchar(Sys.getenv("AEMET_API_KEY")) && file.exists(".Renviron")) {
    readRenviron(".Renviron")
  }
  cache_files <- file.path(cache_dir, sprintf("%s-%d.rds", station, years))
  if (any(!file.exists(cache_files)) && !nzchar(Sys.getenv("AEMET_API_KEY"))) {
    stop("AEMET cache is incomplete. Set AEMET_API_KEY or add it to this folder's .Renviron.",
         call. = FALSE)
  }
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  annual <- do.call(rbind, lapply(years, function(year) summarise_year(year, read_station_year(year))))
  reference <- reference_years(annual)
  used <- annual$year %in% reference & annual$complete
  baseline <- if (any(used)) mean(annual$annual_mean_c[used]) else NA_real_
  annual$reference_start <- if (length(reference)) min(reference) else NA_integer_
  annual$reference_end <- if (length(reference)) max(reference) else NA_integer_
  annual$reference_years_used <- sum(used)
  annual$used_in_reference <- used
  annual$reference_mean_c <- baseline
  annual$anomaly_c <- annual$annual_mean_c - baseline
  utils::write.csv(annual, file.path("data", "cadiz-5973-annual-temperature.csv"), row.names = FALSE)
  if (!length(reference)) stop("No 30-year reference meets coverage criteria. See the annual CSV.")
  excluded <- annual$year[!annual$complete]
  message("Complete years span ", paste(range(annual$year[annual$complete]), collapse = "–"),
          ". Excluded: ", if (length(excluded)) paste(excluded, collapse = ", ") else "none",
          ". Reference: ", paste(range(reference), collapse = "–"), " (", sum(used), " years).")

  city <- city_geometry()
  stripes <- make_stripes(city, annual)
  sysfonts::font_add("Roboto", regular = file.path("data", "Roboto-Regular.ttf"),
                     bold = file.path("data", "Roboto-Bold.ttf"))
  dir.create("outputs", showWarnings = FALSE)
  for (extension in c("png", "pdf")) {
    file <- file.path("outputs", paste0("day28-cadiz-feeling-the-heat-halo-waves.", extension))
    export_map(file, city, stripes, reference)
  }
}

if (sys.nframe() == 0L) main()
