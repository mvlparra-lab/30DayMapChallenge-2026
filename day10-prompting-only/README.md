# Day 10 - Prompting only | Augsburg, Where Water Runs

Tracing how water from the Lech enters Augsburg’s canals at Hochablass and reaches the historic Lechviertel. The map follows the Hauptstadtbach, Kaufbach and Schwallech to the Mittlerer Lech and Hinterer Lech branches.

[View the refined map](output/day10_prompting_only_augsburg_refined.png) · [View the original draft](output/day10_prompting_only_augsburg_draft.png)

## Tools

Python, Jupyter, Requests, GeoPandas, Shapely and Matplotlib.

## Workflow

1. Retrieve OpenStreetMap waterways for the corridor between Hochablass and the old town and save a local extract.
2. Use Augsburg’s heritage documentation to select the route. Follow shared OpenStreetMap nodes through named reaches and three unnamed connecting ways.
3. Verify that the selected ways connect in their mapped direction from the intake to the old-town confluence.
4. Separate the intake, Lech main stem, documented route and context waterways. Clip the river and context to the study area.
5. Project the layers to EPSG:32632, write a GeoPackage and reopen every layer to verify its feature count, CRS and geometry.
6. Draw the route and intake in blue, with the Lech and surrounding waterways in softer tones. Add flow arrows on two verified sections, labels, a legend, grid north and a 1 km scale bar.
7. Export a square PNG at 300 dpi.

## Local data

Install the dependencies, then open [day10_prompting_only_augsburg.ipynb](day10_prompting_only_augsburg.ipynb) from this day’s folder and use **Run All**.

```bash
pip install notebook requests "geopandas>=1" "shapely>=2" matplotlib
```

The notebook creates `data/`, which is excluded from Git. On a fresh checkout it downloads the source extract from OpenStreetMap, so the first run needs internet access. Later runs reuse the cached extract and rebuild the GeoPackage and PNG. Move the cached JSON out of `data/` before running again if you want a fresh OpenStreetMap download.

- `augsburg_osm_waterways.json` stores the filtered OpenStreetMap extract for subsequent runs.
- `augsburg_waterways.gpkg` contains four layers: `hochablass_intake`, `lech_river`, `documented_route` and `context_waterways`.
- `output/day10_prompting_only_augsburg_refined.png` is the exported 3000 × 3000 pixel map. The original draft is preserved separately.

The prompts for data preparation, the draft map and its refinement are saved in [prompt.md](prompt.md).

## Sources and inspiration

- Geometry © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), ODbL.
- The municipal profiles identify the diversion at Hochablass and the canals of the historic centre. [Hochablass](https://wassersystem-augsburg.de/de/objekte/hochablass-lechwehr) · [Lechkanäle](https://wassersystem-augsburg.de/de/objekte/lechkanaele)
- Augsburg’s World Heritage nomination dossier describes the route via Hauptstadtbach, Kaufbach and Schwallech to the Mittlerer and Hinterer Lech branches. [Nomination dossier, p. 139](https://wassersystem-augsburg.de/sites/default/files/2022-11/1_stadt_augsburg_nomination_dossier_0.pdf#page=139)
- The prompting workflow adapts Tyson Swetnam’s tutorial. [Vibe coding a Public Health Map](https://tyson-swetnam.github.io/intro-gpt/tutorials/publichealth/gis/)

## Notes

- Vorderer Lech remains in the context layer. The city identifies the Lochbach as its supply, with a separate diversion at Lech barrage 22.
- Context includes waterways outside the selected route, including some that also receive Hochablass water.
- The intake point uses the first mapped node of the Hauptstadtbach. The river centreline and the intake are separate geometries in OpenStreetMap.
- The route retains the original OpenStreetMap names and tunnel tags. The `route_reach` field uses the municipal spelling `Schwallech` for ways tagged `Schwalllech` in OpenStreetMap.
- The layers represent mapped centrelines and their connections within the study area. OpenStreetMap coverage may be incomplete.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/) · [Back to the challenge](../README.md)
