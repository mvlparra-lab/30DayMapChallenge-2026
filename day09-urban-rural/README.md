# Day 09 - Urban-rural | Baena, Town & Countryside

For the Urban-rural theme, I wanted to see how Baena, in Córdoba, Spain, meets the countryside around it. The map shows the urban area, the buildings within and around it, and the surrounding agricultural land.

## Tools

- Python, GeoPandas and pyogrio for the building coverage analysis
- QGIS for the final map

## Workflow

1. Load the SIGPAC 2026 land-use data for Baena in QGIS and group it into urban areas, agricultural land and other uses.
2. Add the cadastral building footprints and project the data to ETRS89 / UTM zone 30N (EPSG:25830).
3. Run [`day09_baena.py`](./day09_baena.py) to calculate the percentage of each 100 × 100 m cell covered by buildings. Count overlapping footprints only once.
4. Load the resulting coverage layer in QGIS for the inset, then compose and export the main map and inset together.

Run these commands from `day09-urban-rural/`:

```sh
python -m pip install "geopandas>=1" pyogrio
python day09_baena.py
```

## Local data

The script expects `baena_catastro.gpkg` in the working directory, containing the INSPIRE BU **Building** footprints for Baena. If the GeoPackage contains several candidate layers, specify the footprint layer with `--layer LAYER_NAME`.

The script recreates the original grid by default. To reuse the grid from the QGIS project, run `python day09_baena.py --grid baena.gpkg`. The output is `baena_coverage_catastro.gpkg`, with the layer `building_coverage_catastro_100m`. The SIGPAC layer is used separately in QGIS for the main map.

## Sources and inspiration

- **Land use:** [SIGPAC 2026, Junta de Andalucía](https://www.juntadeandalucia.es/organismos/agriculturapescaaguaydesarrollorural/servicios/sigpac/visor/paginas/sigpac-descarga-informacion-geografica-shapes-provincias.html), © Junta de Andalucía.
- **Building footprints:** [INSPIRE Buildings (BU), Dirección General del Catastro](https://www.catastro.hacienda.gob.es/webinspire/).
- **Tutorial:** [How to Calculate Coverage and Floor Area Ratio in Python](https://www.spatialworkflow.io/building-coverage-far-python/) by Spatial Workflow.

## Notes

- Light terracotta marks the urban area, dark terracotta shows individual building footprints, and olive green shows all mapped agricultural land. Grey combines other uses and areas without data.
- The inset measures the share of each cell covered by building footprints, not population density or the extent of the urban area.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/portfolio) · [Back to challenge](../)
