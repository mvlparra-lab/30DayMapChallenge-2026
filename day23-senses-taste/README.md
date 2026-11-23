# Day 23 - Cadiz, a Meeting of Flavours

#30DayMapChallenge 2026 · Senses: Taste · María Victoria León Parra

Cádiz’s Atlantic port linked Andalusia with the Americas and made the city a place of cultural exchange. This map takes that history as a starting point for exploring what people eat in the old town today, from fried fish and sweets to Arab cooking, Japanese sushi, Mexican dishes and contemporary fusion. Mercado Central brings fresh ingredients and prepared foods together under one roof. The 15 places form a personal curated selection for the Cádiz senses series. The map uses exchange as a historical theme and leaves the origins of individual dishes and businesses to their own evidence. The selection is illustrative and unranked. [Cádiz Tourism history](https://turismo.cadiz.es/es/cultura/edad-moderna) · [Mercado Central](https://turismo.cadiz.es/es/rutas-y-visitas-en-cadiz/mercado-central)

The centered title, warm paper background, Roboto typography and challenge footer carry the collection’s print layout into an interactive page. Days 20–22 supplied the layout and folder references.

[Open the interactive Leaflet map](outputs/day23-cadiz-a-meeting-of-flavours.html)

[LinkedIn cover PNG](outputs/day23-cadiz-a-meeting-of-flavours-cover.png) · [Looping GIF preview](outputs/day23-cadiz-a-meeting-of-flavours-preview.gif)

## Tools

R 4.6.2, Leaflet, sf, dplyr, glue, htmltools, htmlwidgets and Pandoc for the map. Node.js, Chrome or Chromium, and Python with Pillow for the social exports.

## Workflow

1. Adapt Chapter 9, “Interactive Maps with leaflet: Bringing Your Maps to Life!”, from Miloš Popović’s *Mapping Worlds with R*. The script uses the chapter’s marker, HTML popup, basemap, category control and HTML export patterns. This project adds an embedded photo and adapts the layer control so Gadisushi appears once whenever either of its categories is active. [Chapter 9 examples](https://github.com/milos-agathon/book-mapping-worlds-with-r-examples/tree/main/Ch%209)
2. Read the curated CSV and turn its cached WGS 84 longitude and latitude into `sf` points. Fit the starting view to the points. Use the Meeting of flavours diamond for Gadisushi and a larger square for the market.
3. Show all three categories initially. Toggle them above the map and select a marker for dishes, notes and sources. Casa Pepe and Casa Tino are across the street from one another. Zoom in to separate their markers or use Tab and Enter to open either.
4. Draw a local vector basemap and use Pandoc to embed it with the widget dependencies, fonts and licensed photograph in a single HTML file.

## Local data and reproduction

Install the following packages in R. The export was generated with R 4.6.2.

```r
install.packages(c("leaflet", "sf", "dplyr", "glue", "htmltools",
                   "htmlwidgets", "base64enc", "rmarkdown"))
```

Install Pandoc and make it available on `PATH`. If using a bundled Pandoc from outside the IDE, point `RSTUDIO_PANDOC` to the directory containing the executable. On Windows, if Pandoc cannot find a temporary template, set `TMPDIR`, `TMP` and `TEMP` to an existing writable directory without special characters before starting R.

From `day23-senses-taste/`, run:

```sh
Rscript --vanilla day23-senses-taste.R
```

The script reads `data/places.csv` and `data/cadiz-basemap.geojson` and writes `outputs/day23-cadiz-a-meeting-of-flavours.html`. Edit the CSV to update places or category membership. Edit the settings near the top of `day23-senses-taste.R` to change the basemap, attribution, category labels or palette. Routine runs reuse cached coordinates without geocoding. Open the exported HTML directly in a browser. The basemap, markers, popups, photograph and controls work offline. External source links require an internet connection when opened.

### LinkedIn export commands

Install Node.js 22 or newer, Google Chrome or Chromium, and Python 3.10 or newer with Pillow. From this directory, regenerate the Leaflet HTML if needed, then run:

```sh
python -m pip install Pillow
node export_social.mjs
```

Set `CHROME_PATH` and `PYTHON` to the executable paths if they differ from the defaults. The script writes both visuals to `outputs/`. Cover label offsets and GIF scene durations are near the top of `export_social.mjs`.

## Sources and inspiration

`data/places.csv` holds one record per place, stable IDs, the three membership flags, coordinates and provenance, addresses, menu status, business sources and optional photo credits. The source review is dated **19 November 2026**. “Listed as operating” reflects published business, municipal or directory information available at review. It does not reflect a phone call or field visit. Menus, schedules and product availability can change.

Coordinates come from an OpenStreetMap snapshot, venue-published map links and a published venue pin for Santa Catrina. The source column links to the underlying features or venue pages. For Puerta del Edén, the pin represents its mapped address building. Ettu is pinned at its host hotel, which provides restaurant access. The market marker is derived from the mapped market footprint. Gadisushi uses the pin linked from its own website, near the market’s southern side. Treat that pin as an approximate indoor stall location. Map review checked placement within the old town and the relationship of the two market markers. [OpenStreetMap data and licence](https://www.openstreetmap.org/copyright)

`data/cadiz-basemap.geojson` is an OpenStreetMap vector extract prepared for this map from a snapshot retrieved on 19 November 2026. The coastline divides the local frame into land and water. The other layers show streets, paths, selected green spaces and the market footprint. Coverage is limited to the old town and its immediate surroundings. © OpenStreetMap contributors, ODbL. [Source extract](https://api.openstreetmap.org/api/0.6/map?bbox=-6.311,36.523,-6.286,36.54) · [Data licence](https://www.openstreetmap.org/copyright)

### Photograph and typography

The Mercado Central popup includes a 2010 photograph of its exterior by **HombreDHojalata**, shared under **CC BY-SA 2.0**. The bundled 1024-pixel Flickr rendition is embedded in the exported map. The other popups use text. To add a permitted JPEG, put it in `data/` and fill in its file, author, source and licence in `data/places.csv`. The script falls back to text when the photo is absent. [Commons file and credit](https://commons.wikimedia.org/wiki/File:Mercado_central_de_abastos,_C%C3%A1diz.jpg) · [Original Flickr listing](https://www.flickr.com/photos/hombredhojalata/4910778526/) · [CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0/)

Roboto Regular and Bold are bundled with their [font licence](data/Roboto-LICENSE.txt).

## Notes and limitations

### Venue verification

| Place | Verification note |
| --- | --- |
| Salicornia | The restaurant lists the sea urchin scramble and describes its menu as seasonal. Availability varies. [Restaurant menu](https://www.restaurantesalicornia.com/carta) |
| Bar Casa Pepe | Local reporting documents the cuttlefish and potato stew. The bar serves a changing selection of stews. [Local food coverage](https://www.codigocarnaval.com/comer-en-cadiz/) |
| Taberna La Sorpresa | Sources confirm almadraba tuna and cured fish. The current availability of mojama remains unconfirmed. [Cádiz Tourism](https://turismo.cadiz.es/es/donde-comer-en-cadiz/taberna-la-sorpresa?language=es) · [Guía Repsol](https://www.guiarepsol.com/es/fichas/solete/taberna-la-sorpresa-15491/) |
| Casa Lazo | The proposed papas aliñás con melva remains unconfirmed. [Guía Repsol](https://www.guiarepsol.com/es/fichas/solete/casa-lazo-332582/) |
| La Dulcería de la Rondeña | The official branch locator gives Calle Ancha 18 bis at the corner of Sagasta. The CSV also retains the submitted Sagasta 11 address. Coconut sweets are reported for this shop. Branch availability of pan de Cádiz and tocino de cielo remains unconfirmed. [Official branch locator](https://www.ladulceriadelarondena.com/tiendas/) · [Branch report](https://tartapan.com/la-dulceria-de-la-rondena-cadiz-2/) |
| Puerta del Edén | The city confirms halal Arab cuisine and the address. A directory lists couscous and hummus. Tagine and the range of small plates remain unconfirmed. [Cádiz Tourism](https://turismo.cadiz.es/de/node/30227) · [Menu directory](https://www.sluurpy.es/c%C3%A1diz/restaurant/8543610/restaurante-puerta-del-ed%C3%A9n) |
| Ettu | A 2024 chef interview documents tuna with mole. The current restaurant website confirms its location and contemporary Cádiz focus. The dish’s current availability remains unconfirmed. [Ettu](https://www.etturestaurante.es/about) · [Chef interview](https://www.20minutos.es/gastronomia/recetas/que-es-mole-variedades-ingredientes-como-preparar-plato-mexicano-5208312/) |
| La Candela | Ceviche is documented. Current availability of bao remains unconfirmed. [Official menu](https://lacandelatapasbar.com/la-carta/) · [Guía Macarfi](https://macarfi.com/es/cdz/ficha-restaurante/la-candela-tapas-bar) |
| Gadisushi | The business lists stalls 63–64, which the market directory also identifies. Cádiz Tourism reports sourcing from the market. The fish’s catch origin remains unverified. [Business](https://gadisushi.com/) · [Market directory](https://mercadocentralcadiz.com/rincon-gastronomico/) · [Cádiz Tourism](https://turismo.cadiz.es/es/node/30381) |

## Outputs

- [Interactive Leaflet map](outputs/day23-cadiz-a-meeting-of-flavours.html), with an offline vector basemap.

The [square PNG cover](outputs/day23-cadiz-a-meeting-of-flavours-cover.png) is 2400 × 2400 px. It labels all 15 locations and preserves the Leaflet north indicator, metric scale and OpenStreetMap attribution. A few labels use shorter venue names to fit. The [looping GIF](outputs/day23-cadiz-a-meeting-of-flavours-preview.gif) is 1200 × 1000 px and runs for 14.85 seconds per loop. It starts with all three categories active, clears the checkboxes, then activates each category in turn. It opens the popups for Casa Manteca, La Candela Tapas Bar and Mercado Central. The final market frame includes the embedded photograph and its visible author and licence credit.

The export script opens the saved HTML in headless Chrome and applies a layout for each format in memory. It waits for the vector basemap, markers and Roboto fonts, and decodes the market photograph before capture. The labeled cover is captured at twice its layout resolution. Pillow encodes the GIF with timed holds and an indexed colour palette. The interactive HTML is unchanged by this workflow.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/portfolio) · [Back to challenge](../)
