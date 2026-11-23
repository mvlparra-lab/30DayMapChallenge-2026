# # Day 23 - Cadiz, a Meeting of Flavours
#
# **Author** María Victoria León Parra
# **Challenge** 30DayMapChallenge 2026, Day 23
# **Purpose** Explore traditional dishes and contemporary food cultures in Cádiz.
# **Data** Personal selection, published business and menu sources, cached WGS 84
# locations, and a cached OpenStreetMap vector basemap.
# **Inspiration** Miloš Popović, *Mapping Worlds with R*, Chapter 9.
# **Workflow** Read the verified place table, build popups and thematic controls,
# and save a standalone Leaflet widget with embedded fonts and optional photos.
# **Run** From this directory, run `Rscript --vanilla make_map.R`. See README.md
# for dependencies and Pandoc setup.

library(leaflet)
library(sf)
library(dplyr)
library(glue)
library(htmltools)
library(htmlwidgets)

# Edit the place table to update dishes, sources, memberships and coordinates.
# The palette and basemap can be changed here without editing the data.
title <- "Day 23 - Cadiz, a Meeting of Flavours"
footer <- paste("#30DayMapChallenge | 2026 | Day – 23 | Senses: Taste |",
                "Cádiz, a Meeting of Flavours | Map by María Victoria León Parra")
output <- file.path("outputs", "day23-cadiz-a-meeting-of-flavours.html")
basemap <- st_read(file.path("data", "cadiz-basemap.geojson"), quiet = TRUE)
basemap_credit <- '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>'
area_colours <- c(land = "#efe9dc", water = "#b9d5db", green = "#cbd8ba",
                  market = "#dac5a1")
groups <- c(traditional = "Traditional flavours", meeting = "Meeting of flavours",
            market = "Mercado Central")
palette <- c(traditional = "#9b412e", meeting = "#17656a", market = "#795311")

places <- read.csv(file.path("data", "places.csv"), encoding = "UTF-8",
                   na.strings = "", stringsAsFactors = FALSE) |>
  mutate(across(all_of(names(groups)), as.logical))
# Keep explicitly unmapped records in the CSV. Reject incomplete coordinate pairs.
has_point <- !is.na(places$latitude) & !is.na(places$longitude)
stopifnot(!anyDuplicated(places$id), any(has_point),
          identical(is.na(places$latitude), is.na(places$longitude)),
          all(rowSums(places[names(groups)]) > 0),
          all(places$latitude[has_point] > 36.52 & places$latitude[has_point] < 36.54),
          all(places$longitude[has_point] > -6.31 & places$longitude[has_point] < -6.28))
points <- places |>
  filter(has_point) |>
  mutate(style = case_when(meeting ~ "meeting", market ~ "market",
                           TRUE ~ "traditional")) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

# Build markup with HTML tags so names, notes and URLs are escaped.
external_link <- function(url, label) {
  tags$a(label, href = url, target = "_blank", rel = "noopener noreferrer")
}
popup_for <- function(place) {
  photo <- NULL
  if (!is.na(place$photo_file)) {
    file <- file.path("data", place$photo_file)
    if (file.exists(file)) {
      photo <- tags$figure(
        tags$img(src = base64enc::dataURI(file = file, mime = "image/jpeg"),
                 alt = paste("Photograph of", place$name)),
        tags$figcaption(external_link(place$photo_source, place$photo_author), " · ",
                        external_link(place$photo_license, "Photo licence"))
      )
    }
  }
  as.character(tags$article(
    class = "place-popup",
    tags$h2(place$name),
    tags$p(class = "dish", place$dishes),
    tags$p(place$description),
    tags$p(class = "address", place$address),
    if (!is.na(place$notes)) tags$p(class = "note", place$notes),
    tags$p(class = "sources", external_link(place$source_url, "Venue source"),
           if (!is.na(place$supporting_url)) tagList(
             " · ", external_link(place$supporting_url, "Supporting source")
           )),
    photo
  ))
}

# Distinguish categories by shape as well as colour. Gadisushi uses the
# Meeting of flavours diamond, and the larger square identifies the market.
symbol <- function(style) tags$span(class = paste("symbol", style), `aria-hidden` = "true")
popups <- vapply(seq_len(nrow(points)), function(i) popup_for(points[i, ]), "")
# Draw the cached vector context below the markers. These layers are always
# visible and have no pointer handlers, so they cannot intercept marker clicks.
areas <- filter(basemap, kind %in% names(area_colours))
paths <- filter(basemap, kind == "path")
streets <- filter(basemap, kind == "street")
# Supply an embedded placeholder until onRender installs the category symbols.
placeholder <- "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
map <- leaflet(points, width = "100%", height = 550,
               options = leafletOptions(zoomSnap = 0.25, zoomDelta = 0.5,
                                        minZoom = 15, maxZoom = 20,
                                        zoomControl = TRUE, scrollWheelZoom = FALSE)) |>
  addPolygons(data = areas, stroke = FALSE, fillColor = ~unname(area_colours[kind]),
              fillOpacity = 1, options = pathOptions(interactive = FALSE)) |>
  addPolylines(data = paths, color = "#b6aa93", weight = 1, opacity = 0.65,
               options = pathOptions(interactive = FALSE)) |>
  addPolylines(data = streets, color = "#c6b8a2", weight = 3.2, opacity = 1,
               options = pathOptions(interactive = FALSE)) |>
  addPolylines(data = streets, color = "#fffcf5", weight = 1.8, opacity = 1,
               options = pathOptions(interactive = FALSE)) |>
  addMarkers(layerId = ~id, group = "Places",
             icon = makeIcon(iconUrl = placeholder, iconWidth = 1, iconHeight = 1),
             popup = popups, popupOptions = popupOptions(
               maxWidth = 310, minWidth = 0,
               autoPanPaddingTopLeft = c(12, 82), autoPanPaddingBottomRight = c(12, 28)),
             label = ~name, options = markerOptions(riseOnHover = TRUE)) |>
  addScaleBar(position = "bottomleft", options = scaleBarOptions(imperial = FALSE)) |>
  addControl(tags$div(class = "north", role = "img", `aria-label` = "North is up",
                      "N", tags$span("↑")), position = "topright", layerId = "north")
map$sizingPolicy$browser$fill <- FALSE

# One marker belongs to each record. Filter the physical Leaflet layers with
# OR logic so disabling either of Gadisushi's memberships cannot duplicate it.
memberships <- st_drop_geometry(points)[c("id", "name", "style", names(groups))]
bbox <- unname(st_bbox(points))
map <- onRender(map, "
function(el, x, data) {
  const map = this;
  const controls = document.getElementById('taste-groups');
  const toggles = Array.from(controls.querySelectorAll('input'));
  const places = data.places.map(place => ({
    ...place, marker: map.layerManager.getLayer('marker', place.id)
  }));
  places.forEach(place => {
    const glyph = document.createElement('span');
    glyph.className = 'symbol ' + place.style;
    glyph.setAttribute('aria-hidden', 'true');
    place.marker.setIcon(L.divIcon({
      html: glyph.outerHTML, className: 'place-marker', iconSize: [27, 27],
      iconAnchor: [13, 13], popupAnchor: [0, -12], tooltipAnchor: [10, 0]
    }));
  });
  const labelMarker = place => {
    const element = place.marker.getElement();
    if (element) {
      element.setAttribute('aria-label', place.name);
      element.setAttribute('role', 'button');
    }
  };
  function update() {
    const active = toggles.filter(toggle => toggle.checked).map(toggle => toggle.value);
    let count = 0;
    places.forEach(place => {
      const visible = active.some(group => place[group]);
      if (visible) {
        if (!map.hasLayer(place.marker)) map.addLayer(place.marker);
        labelMarker(place);
        count += 1;
      } else if (map.hasLayer(place.marker)) {
        place.marker.closePopup();
        map.removeLayer(place.marker);
      }
    });
    document.getElementById('taste-count').textContent =
      count + (count === 1 ? ' place shown' : ' places shown');
  }
  controls.addEventListener('change', update);
  // Reduce the glyphs at wider extents so the two market points stay distinct.
  const sizeMarkers = () => el.classList.toggle('compact-markers', map.getZoom() < 16.5);
  map.on('zoomend', sizeMarkers);
  const [west, south, east, north] = data.bbox;
  const [mapWest, mapSouth, mapEast, mapNorth] = data.basemapBounds;
  map.fitBounds([[south, west], [north, east]],
    {padding: [34, 45], maxZoom: 17.5, animate: false});
  map.setMaxBounds([[mapSouth, mapWest], [mapNorth, mapEast]]);
  map.attributionControl.addAttribution(data.attribution);
  sizeMarkers();
  update();
}", data = list(bbox = bbox, basemapBounds = unname(st_bbox(basemap)),
                 attribution = basemap_credit,
                 places = lapply(seq_len(nrow(memberships)),
                                             function(i) as.list(memberships[i, ]))))

# Keep the title above the map and the credit below it. Embed both bundled
# Roboto faces so the page does not depend on an external font service.
font <- function(face) base64enc::dataURI(
  file = file.path("data", paste0("Roboto-", face, ".ttf")), mime = "font/ttf"
)
font_css <- glue("
@font-face {{font-family:Roboto;src:url('{font('Regular')}') format('truetype');font-weight:400}}
@font-face {{font-family:Roboto;src:url('{font('Bold')}') format('truetype');font-weight:700}}
")
marker_css <- paste(glue(".symbol.{names(palette)} {{background:{unname(palette)}}}"),
                    collapse = "\n")
css <- "
body { margin:0 !important; padding:0 !important; background:#f8f3e8; color:#3b322b;
       font-family:Roboto,Arial,sans-serif; }
.page-head,.page-foot { text-align:center; margin-inline:auto; }
.page-head { max-width:900px; padding:24px 16px 12px; }
.page-head h1 { margin:0; font-size:clamp(23px,4vw,36px); line-height:1.1; }
.page-head p { margin:10px auto 0; max-width:660px; line-height:1.45; font-size:15px; }
.map-toolbar { max-width:1200px; margin:0 auto; padding:0 16px 9px; }
#taste-groups { border:0; padding:0; margin:0; display:flex; align-items:center;
                justify-content:center; flex-wrap:wrap; gap:0 14px; }
#taste-groups label { display:inline-flex; align-items:center; min-height:38px;
                      gap:6px; font-size:14px; cursor:pointer; }
#taste-groups input { width:16px; height:16px; margin:0; accent-color:#3b322b; }
#taste-count { text-align:center; display:block; font-size:12px; margin-top:3px; }
.leaflet.html-widget { width:calc(100% - 32px) !important; max-width:1200px;
                       height:clamp(330px,60vh,680px) !important; margin:0 auto;
                       border:1px solid #bcb2a1; background:#eae6dd; }
.leaflet-container { font-family:Roboto,Arial,sans-serif; }
.symbol { display:inline-block; box-sizing:border-box; width:15px; height:15px;
          vertical-align:middle; border:2px solid #fff; box-shadow:0 0 0 1px #3b322b; }
.traditional { border-radius:50%; }
.meeting { transform:rotate(45deg) scale(.8); border-radius:2px; }
.market { border-radius:2px; }
.leaflet-marker-icon.place-marker { display:grid; place-items:center; pointer-events:none; }
.place-marker .symbol { width:18px; height:18px; pointer-events:auto; }
.place-marker .market { width:24px; height:24px; }
.compact-markers .place-marker .symbol { width:10px; height:10px; border-width:1px; }
.compact-markers .place-marker .market { width:13px; height:13px; }
.north { text-align:center; background:#f8f3e8; border:1px solid #bcb2a1;
         border-radius:4px; color:#3b322b; width:33px; font-weight:700; }
.north span { display:block; font:25px/24px Arial,sans-serif; padding-bottom:4px; }
.leaflet-popup-content { margin:13px 19px; max-width:calc(100vw - 108px); }
.place-popup { font-size:14px; max-height:min(42vh, 380px); overflow:auto; }
.place-popup h2 { font-size:17px; line-height:1.2; margin:0 0 8px; }
.leaflet-popup-content p { margin:0 0 7px; }
.dish { font-weight:700; }
.place-popup .note { padding:6px 8px; background:#f8f3e8; }
.place-popup figure { margin:8px 0; }
.place-popup img { display:block; max-width:100%; max-height:150px; object-fit:contain; }
.place-popup figcaption,.place-popup .sources { font-size:12px; }
.page-foot { max-width:1200px; padding:12px 16px; font-size:12px; line-height:1.5; }
.page-foot a { color:#453024; }
:focus-visible { outline:2px solid #173f6d; outline-offset:2px; }
@media (max-width:480px) {
  .page-head { padding-top:16px; }
  .page-head p { font-size:14px; }
  .leaflet.html-widget { width:calc(100% - 20px) !important; }
  .place-popup { max-height:min(35vh, 270px); }
  #taste-groups { gap:0 10px; }
}
"
header <- tags$header(class = "page-head", tags$h1(title),
  tags$p("Cádiz’s Atlantic port brought people, goods and food traditions into contact.",
         " This personal selection traces that spirit of exchange from La Viña’s tapas bars",
         " to contemporary kitchens and the stalls of Mercado Central."))
toolbar <- tags$section(class = "map-toolbar",
  tags$fieldset(id = "taste-groups", `aria-label` = "Map categories",
    lapply(names(groups), function(key) tags$label(
      tags$input(type = "checkbox", value = key, checked = "checked"),
      symbol(key), groups[[key]]
    ))
  ),
  tags$output(id = "taste-count", `aria-live` = "polite"))
credits <- tags$footer(class = "page-foot", footer)

map <- prependContent(map, tags$head(
  tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
  tags$style(HTML(paste(font_css, marker_css, css)))
), header, toolbar)
map <- appendContent(map, credits)
dir.create(dirname(output), showWarnings = FALSE, recursive = TRUE)
# Save from the output directory so htmlwidgets also removes the temporary
# dependency directory from the same location after Pandoc embeds it.
previous_directory <- setwd(dirname(output))
tryCatch(
  saveWidget(map, basename(output), selfcontained = TRUE, title = title,
             background = "#f8f3e8"),
  finally = setwd(previous_directory)
)
message("Exported ", output, " with ", nrow(points), " mapped places.")
