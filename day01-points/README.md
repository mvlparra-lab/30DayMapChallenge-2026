# Day 01 · Points | Lighthouses of Spain 🔅

Revisiting my first map from the 2025 challenge, this time with
Python and animated lights.

The map combines OpenStreetMap lighthouse and navigation light
locations with a shaded relief background adapted from my
2025 QGIS project.

## Tools

Python, OSMnx, GeoPandas, Rasterio and Matplotlib.

## Workflow

1. Retrieve lighthouse and navigation light features from OpenStreetMap.
2. Convert geometries to points and remove exact coordinate duplicates.
3. Project the locations to EPSG:3035.
4. Load reduced versions of the elevation and hillshade rasters.
5. Recreate the background style and add a Canary Islands inset.
6. Export a static PNG and an animated GIF.

## Local data

The notebook requires these files in a `data/` folder:

- `dem_espana_3035_reproj.tif`
- `hillshade_espana.tif`

These large rasters are not included in this repository.
They were prepared for my 2025 QGIS project using Copernicus DEM
obtained via OpenTopography.

## Sources and inspiration

- Data: [OpenStreetMap contributors](https://www.openstreetmap.org/copyright).
- Elevation: Copernicus DEM via [OpenTopography](https://opentopography.org/).
- Tutorial: [Lighthouse animation by Miloš Popović](https://github.com/milos-agathon/lighthouse_animation).

## Notes

The light pulses are illustrative and do not represent actual
lighthouse flashing patterns. OpenStreetMap coverage may be incomplete.

The background is an approximate Python reconstruction of the
2025 QGIS style.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/) ·
[Back to the challenge](../README.md)
