# Day 17 | Poland After Dark

Light & dark · 30DayMapChallenge 2026

Wrocław, where I studied during my Erasmus, was the starting point for this
map. The final view shows the distribution of nighttime radiance across
Poland in the 2024 VIIRS annual composite.

[Final map](outputs/day17-poland-after-dark.png) · [Preview](outputs/day17-poland-after-dark-preview.png)

## Tools

R 4.2 or newer, terra, sf, ggplot2, ggspatial, scales, ragg and systemfonts.
The bundled Roboto Regular and Bold fonts are used throughout the layout.

## Workflow

1. Crop the single-band VIIRS GeoTIFF to the map frame and project it to
   Poland's national grid (EPSG:2180). Nearest-neighbor sampling preserves
   radiance values on a 400 m grid.
2. Rasterize the Natural Earth country geometry on the same grid and retain
   cells whose centers fall inside Poland. The clipped radiance defines the
   silhouette. Missing observations within the country have their own swatch.
3. Apply a `log1p` display ramp from deep blue through amber to cream. Label
   the scale in the original nW/cm²/sr units and display values of 100 and
   above in the lightest color.
4. Compose the portrait map in ggplot2 with a centered legend, true north,
   a 100 km scale and the challenge footer. The background is `#0a0e21`.
   Lettering, north and the scale use `#f8daa2`.
5. Export the print PNG and preview from the same layout in
   [make_map.R](make_map.R).

## Local data

The [VIIRS crop](data/viirs-2024-poland.tif), [country geometry](data/poland.geojson)
and fonts are bundled in `data/`. Install the packages from CRAN in R.

```r
install.packages(c("terra", "sf", "ggplot2", "ggspatial", "scales", "ragg", "systemfonts"))
```

Run the script from the day 17 folder.

```sh
Rscript --vanilla make_map.R
```

If Windows reports a PROJ database layout mismatch and `PROJ_LIB` points to
another application, run `Remove-Item Env:PROJ_LIB` in the same PowerShell
session before running the script.

To recover the bundled raster, run the following from the day 17 folder
in R. GDAL reads the required region by HTTP byte ranges. The division
by ten converts the archive's scaled values to nW/cm²/sr after `terra`
applies the GeoTIFF scale metadata on reading.

```r
library(terra)
url <- paste0(
  "https://zenodo.org/records/17294744/files/",
  "nightlights.average_viirs.v21_m_500m_s_20240101_20241231_go_epsg4326_v20250904.tif"
)
archived <- rast(paste0("/vsicurl/", url))
stopifnot(scoff(archived)[1, 1] == 10)
poland <- crop(archived, ext(12.3, 25.9, 48, 56.4), snap = "out") / 10
names(poland) <- "average_masked"
units(poland) <- "nW/cm²/sr"
writeRaster(poland, "data/viirs-2024-poland.tif", datatype = "FLT4S",
            gdal = "COMPRESS=DEFLATE")
```

The script also accepts a local GeoTIFF in nW/cm²/sr and its observation year.

```sh
Rscript --vanilla make_map.R data/viirs-2023-poland.tif 2023
```

## Sources and inspiration

- **Nighttime lights.** The Earth Observation Group at the Payne Institute for
  Public Policy, Colorado School of Mines, produces the annual VIIRS Day/Night
  Band composite. This map uses the 2024 V2.2 `average_masked` band.
  [EOG VIIRS Nighttime Light](https://eogdata.mines.edu/products/vnl/) ·
  [Earth Engine catalog](https://developers.google.com/earth-engine/datasets/catalog/NOAA_VIIRS_DNB_ANNUAL_V22)
- **Raster archive.** The bundled crop comes from Tom Hengl's Open-Earth-Monitor
  copy of the observed 2024 EOG composite. It retains the precision of the
  archived copy. [Zenodo record](https://doi.org/10.5281/zenodo.17294744) ·
  [Processing notes](https://differ.blog/p/processing-large-rasters-using-terra-package-for-r-combining-tiling-69d47a) ·
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- **Country geometry.** Poland is the `POL` feature from Natural Earth's
  public-domain Admin 0 country layer at 1:50m, extracted from
  `rnaturalearthdata::countries50`.
  [Natural Earth](https://www.naturalearthdata.com/downloads/50m-cultural-vectors/50m-admin-0-countries-2/)
- **Tutorial.** Miloš Popović's *Nightlight in Ukraine (2021)* inspired the R
  workflow for processing and displaying VIIRS data in a static map.
  [Case study](https://milospopovic.net/case-studies/nightlight-ukraine/) ·
  [Video tutorial](https://www.youtube.com/watch?v=1wz3RrfGG-c)
- **Type.** Roboto Regular and Bold are bundled with their
  [license](data/Roboto-LICENSE.txt).

## Notes

- VIIRS shows nighttime radiance across urban and rural areas at a scale of
  hundreds of metres. The legend year identifies the satellite observations.
- The frame spans 752 × 680 km. Change `center` and `frame_km` in the script
  to adjust the frame, or `palette` and `no_data` to adjust the display colors.
  A frame outside the bundled crop requires a new GeoTIFF.
- **Print at actual size.** The final PNG is 260 × 290 mm with margins of at
  least 10 mm (3070 × 3425 px at 300 dpi). The 120 dpi preview uses the same
  layout (1228 × 1370 px). Both renders matched the approved PNGs byte for byte
  in a clean R session.

## Author

María Victoria León Parra
