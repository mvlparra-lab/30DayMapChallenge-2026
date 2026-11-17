# # Day 17 | Poland After Dark
#
# **Author:** María Victoria León Parra
# **Day:** 17, Light & dark, #30DayMapChallenge 2026
# **Purpose:** Map nighttime radiance across Poland.
# **Source:** Earth Observation Group annual VIIRS DNB V2.2, average_masked.
# The bundled 2024 clip comes from the Open-Earth-Monitor copy on Zenodo.
# The country outline comes from Natural Earth Admin 0 at 1:50m.
# **Tutorial:** [Nightlight in Ukraine (2021)](https://milospopovic.net/case-studies/nightlight-ukraine/)
# **Workflow:** Crop and project the VIIRS grid, compose the map,
# and export the 300 dpi PNG and a smaller preview of the same layout.
# **Run:** From this directory, run `Rscript --vanilla make_map.R` after
# installing the packages in README.md. The default local GeoTIFF is bundled.

library(terra)
library(sf)
library(ggplot2)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 2L || (length(args) == 2L && !grepl("^[0-9]{4}$", args[2]))) {
  stop("Usage: Rscript --vanilla make_map.R [local-geotiff [data-year]]", call. = FALSE)
}
data_year <- if (length(args) == 2L) as.integer(args[2]) else 2024L
input <- if (length(args)) args[1] else
  file.path("data", sprintf("viirs-%s-poland.tif", data_year))
output <- file.path("outputs", "day17-poland-after-dark.png")
preview <- file.path("outputs", "day17-poland-after-dark-preview.png")
if (!file.exists(input)) {
  stop("Missing GeoTIFF: ", input, ". See the README export steps.", call. = FALSE)
}

font_family <- "Day 17 Roboto"
map_crs <- 2180
center <- c(longitude = 19.23962, latitude = 51.96234)
frame_km <- c(width = 752, height = 680)
cell_m <- 400
palette <- c("#080E21", "#25233D", "#6D403B", "#C7733D", "#F2B65C", "#FFF2CE")
no_data <- "#596477"
background <- "#0a0e21"
ink <- "#f8daa2"
maximum_radiance <- 100
breaks <- c(0, 1, 5, 20, 50, maximum_radiance)
title <- "Day 17 | Poland After Dark"
footer <- paste0(
  "#30DayMapChallenge | 2026 | Day – 17 | Light & dark | ",
  "Poland After Dark | Map by María Victoria León Parra"
)

# Use Poland's national grid for raster placement and the metric scale.
# Keep a small buffer when cropping the source grid.
center_xy <- st_sfc(st_point(unname(center)), crs = 4326) |>
  st_transform(map_crs) |> st_coordinates()
xlim <- center_xy[1, 1] + c(-1, 1) * frame_km["width"] * 500
ylim <- center_xy[1, 2] + c(-1, 1) * frame_km["height"] * 500
bbox <- st_bbox(setNames(c(xlim[1] - 1000, ylim[1] - 1000,
                          xlim[2] + 1000, ylim[2] + 1000),
                        c("xmin", "ymin", "xmax", "ymax")), crs = map_crs)
source <- rast(input)
if (nlyr(source) != 1L || !nzchar(crs(source))) {
  stop("Supply a georeferenced, single-band average_masked GeoTIFF.", call. = FALSE)
}
buffer <- st_as_sfc(bbox) |> st_segmentize(dfMaxLength = 500)
source_bbox <- st_bbox(st_transform(buffer, st_crs(crs(source))))
source <- crop(source, ext(source_bbox[c("xmin", "xmax", "ymin", "ymax")]), snap = "out")

# Native cells are 15 arc seconds (roughly 285 x 460 m near the map center).
# A 400 m grid with nearest-neighbor reprojection preserves sampled values
# and the distinction between valid dark cells and missing observations.
template <- rast(
  xmin = xlim[1], xmax = xlim[2], ymin = ylim[1], ymax = ylim[2],
  ncols = ceiling(diff(xlim) / cell_m), nrows = ceiling(diff(ylim) / cell_m),
  crs = paste0("EPSG:", map_crs)
)
radiance <- project(source, template, method = "near")
names(radiance) <- "radiance"

# Use cell centers to clip the display to Poland on the same 400 m grid.
# Keep missing observations inside the country for the NoData swatch.
poland <- st_read(file.path("data", "poland.geojson"), quiet = TRUE) |>
  st_transform(map_crs)
country <- rasterize(vect(poland), template, field = 1, touches = FALSE)
pixels <- as.data.frame(c(radiance, country_mask = country), xy = TRUE, na.rm = FALSE)
pixels <- pixels[!is.na(pixels$country_mask), c("x", "y", "radiance")]
if (!any(is.finite(pixels$radiance))) {
  stop("The GeoTIFF contains no valid VIIRS radiance in the map frame.", call. = FALSE)
}

# A log(1 + x) display ramp separates dim radiance values while preserving
# zero. The color key uses the original nW/cm²/sr and caps the display at 100.
display_value <- function(x) log1p(pmin(pmax(x, 0), maximum_radiance)) /
  log1p(maximum_radiance)
pixels$light <- display_value(pixels$radiance)

map <- ggplot(pixels, aes(x, y)) +
  geom_raster(aes(fill = light), interpolate = FALSE) +
  scale_fill_gradientn(colours = palette, limits = c(0, 1),
                       na.value = no_data, guide = "none") +
  ggspatial::annotation_north_arrow(
    location = "tr", which_north = "true",
    pad_x = grid::unit(5, "mm"), pad_y = grid::unit(5, "mm"),
    width = grid::unit(10, "mm"), height = grid::unit(12, "mm"),
    style = ggspatial::north_arrow_orienteering(
      text_family = font_family, text_col = ink, line_col = ink,
      fill = c(ink, background)
    )
  ) +
  ggspatial::annotation_scale(
    location = "bl", width_hint = 0.2, unit_category = "metric",
    pad_x = grid::unit(5, "mm"), pad_y = grid::unit(5, "mm"),
    text_family = font_family, text_col = ink, line_col = ink,
    bar_cols = c(ink, background), text_cex = 0.9
  ) +
  coord_sf(crs = st_crs(map_crs), xlim = xlim, ylim = ylim,
           expand = FALSE, datum = NA) +
  theme_void() +
  theme(panel.background = element_rect(fill = background, colour = NA),
        plot.margin = margin(0, 0, 0, 0))

# Fit the metric panel in a portrait page with a 10 mm inset.
systemfonts::register_font(font_family, plain = "data/Roboto-Regular.ttf",
                           bold = "data/Roboto-Bold.ttf")
render <- function(path, dpi) {
  page_width <- 260
  page_height <- 290
  page_center <- page_width / 2
  panel_top <- page_height - 26
  mm <- function(x) grid::unit(x, "mm")
  text <- function(label, x, y, size, face = "plain", just = "centre") {
    grid::grid.text(label, x = mm(x), y = mm(y), just = just,
                    gp = grid::gpar(fontfamily = font_family, fontsize = size,
                                    fontface = face, col = ink))
  }
  rect <- function(x, y, w, h, colour) {
    grid::grid.rect(x = mm(x), y = mm(y), width = mm(w), height = mm(h),
                    gp = grid::gpar(fill = colour, col = NA))
  }

  dir.create(dirname(path), showWarnings = FALSE)
  ragg::agg_png(path, width = page_width, height = page_height, units = "mm",
                res = dpi, background = background)
  on.exit(grDevices::dev.off())
  grid::grid.newpage()

  text(title, page_center, page_height - 16, 30, face = "bold")
  ratio <- frame_km["width"] / frame_km["height"]
  panel_width <- min(page_width - 20, (panel_top - 46) * ratio)
  panel_height <- panel_width / ratio
  print(map, newpage = FALSE, vp = grid::viewport(
    x = mm(page_center), y = mm(panel_top - panel_height / 2),
    width = mm(panel_width), height = mm(panel_height)
  ))

  legend_y <- panel_top - panel_height - 15
  ramp_left <- page_center - 93
  ramp_width <- 152
  text(sprintf("VIIRS DNB · %s · nW/cm²/sr", data_year), page_center, legend_y + 8, 12)
  gradient <- scales::gradient_n_pal(palette)(seq(0, 1, length.out = 256))
  grid::grid.raster(matrix(gradient, nrow = 1),
                    x = mm(ramp_left + ramp_width / 2), y = mm(legend_y),
                    width = mm(ramp_width), height = mm(3.5), interpolate = FALSE)
  for (value in breaks) {
    label <- if (value == maximum_radiance) paste0(value, "+") else as.character(value)
    text(label, ramp_left + ramp_width * display_value(value), legend_y - 6.5, 9.5)
  }
  rect(page_center + 74, legend_y, 5, 3.5, no_data)
  text("No data", page_center + 79, legend_y, 10, just = "left")
  text(footer, page_center, 12.5, 10)
}

render(output, dpi = 300)
render(preview, dpi = 120)
message("Wrote ", output, " and ", preview)


