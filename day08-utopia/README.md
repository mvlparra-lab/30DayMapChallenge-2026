# Day 08 - Utopia | Is Augsburg a 15-minute city?

Augsburg ranked second for life satisfaction among 40 major German cities in the 2026 SKL Glücksatlas. For the Utopia theme, I wanted to explore how easy it is to reach everyday services on foot in the city where I live.

## Tools

- R and `r5r` for the walking accessibility analysis
- QGIS for the final map

## Workflow

1. Run `01_prepare_inputs.R` to create a 100 m residential grid and identify five types of destinations: supermarkets, public park entrances, schools, pharmacies and public transport stops.
2. Run `02_test_routing.R` to check the walking routes on a sample of 20 cells.
3. Run `03_run_full_city.R` to calculate the walking time to the nearest mapped destination in each category and classify the cells using the 15-minute threshold.
4. Open `results/augsburg_walkability.gpkg` in QGIS to map the `walkability_grid` layer.

Run these commands from `day08-utopia/` with R, the `sf` and `r5r` packages, and Java 21 installed. The first routing run needs internet access to download R5 if it is not already cached.

```sh
Rscript 01_prepare_inputs.R
Rscript 02_test_routing.R
Rscript 03_run_full_city.R
```

## Local data

The scripts expect these inputs in `../augsburg_15_minute_city/data/`, relative to `day08-utopia/`:

- `Augsburg_boundary.geojson`
- `Augsburg.osm.pbf`
- `feature_extract/Augsburg-geopackage/Augsburg.gpkg`

The workflow generates the residential grid and saves the GeoPackage, cell-level travel times and summary counts in `results/`.

## Sources and inspiration

- [Nathaniel Henry’s 15-minute city tutorial](https://henryspatialanalysis.com/news/tutorial-15-minute-city-interactive-map.html)
- [Original `city_walkability` code](https://github.com/henryspatialanalysis/city_walkability), copyright © 2023 Henry Spatial Analysis, released under the [MIT License](./LICENSE)
- [OpenStreetMap contributors](https://www.openstreetmap.org/copyright)
- [SKL Glücksatlas 2026: Augsburg](https://www.skl-gluecksatlas.de/artikel/staedteranking-2026/augsburg.html)

## Notes

- All five services were within a 15-minute walk of 56.2% of the residential grid cells analysed. Each cell carries equal weight.
- The analysis includes mapped destinations up to 2.5 km outside Augsburg’s municipal boundary.
- If a usable route was unavailable for any category, the cell was classified as `Insufficient data`.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/portfolio) · [Back to challenge](../)
