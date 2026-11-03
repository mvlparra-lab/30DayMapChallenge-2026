# Day 03 - Polygons | Olive Landscapes of Córdoba

Exploring Córdoba’s connection to olive growing, a landscape linked to my family, through a choropleth map showing olive-growing area as a percentage of each municipality’s total area.

![Olive Landscapes of Córdoba](outputs/day03_polygons_olive_cordoba.png)

## Tools

Python, GeoPandas, Pandas, Matplotlib, Requests and xlrd.

## Workflow

1. Download Córdoba’s municipal boundaries from the IGN API Features service.
2. Download the Junta de Andalucía’s municipal crop statistics for 2023.
3. Read the Córdoba workbook and select the Olivar category (1400).
4. Join agricultural records to the 77 municipalities using municipality codes.
5. Calculate municipal areas in EPSG:3035 and olive-growing coverage as a percentage.
6. Project the map to ETRS89 / UTM zone 30N (EPSG:25830).
7. Design the choropleth with a custom green gradient, grid north arrow and 20 km scale bar.
8. Export the map as a PNG at 300 dpi.

## Local data

The notebook downloads the source datasets into `data/` and reuses existing files when available.

Downloaded datasets are excluded from this repository. Run the notebook from top to bottom to download and process them.

Required packages:

```bash
pip install requests pandas geopandas matplotlib xlrd
```

## Sources and inspiration

- **Municipal boundaries:** [Instituto Geográfico Nacional, API Features](https://api-features.ign.es/collections/administrativeunit).
- **Crop statistics:** [Junta de Andalucía, municipal crop areas, 2023](https://www.juntadeandalucia.es/servicios/estadistica-cartografia/actividad/detalle/71175/473605.html). Córdoba workbook, GENERAL sheet, Olivar category (1400).
- **Tutorial:** [Let’s make a map! Using GeoPandas and Matplotlib](https://github.com/bendoesdata/make-a-map-geopandas) by Ben Dexter Cooley.

## Notes

- All 77 municipalities were matched to agricultural records.
- Calculated olive coverage ranges from approximately 0.1% to 93.6%, with the highest percentage in Nueva Carteya.
- Percentages refer to total municipal area, including non-agricultural land.
- Municipal colors show aggregate coverage, not the precise locations of olive groves.
- Agricultural statistics refer to 2023. IGN boundaries reflect the version available when downloaded.
- Municipal areas calculated from boundary geometries may differ slightly from published statistical areas.
- The arrow indicates grid north.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/) · [Back to the challenge](../README.md)
