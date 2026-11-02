# Day 02 - Lines | Augsburg through its streets

Revisiting Augsburg after mapping driving times for Day 26 of
the 2025 challenge, this time exploring its street network with Python.

The map combines OpenStreetMap roads, pedestrian routes, paths
and trails with the municipal boundary.

## Tools

Python, OSMnx, GeoPandas and Matplotlib.

## Workflow

1. Retrieve the street network from OpenStreetMap.
2. Save a local GraphML copy for subsequent runs.
3. Retrieve the municipal boundary.
4. Project both layers to EPSG:32632.
5. Style the streets and boundary, then add a north arrow and scale bar.
6. Export a static PNG.

## Local data

No local input files are required for the first run.
An internet connection is needed to download the OpenStreetMap data.

The notebook saves the street network in a `data/` folder:

- `augsburg_all_streets.graphml`

Subsequent runs load this local copy instead of downloading
the network again. Cached data is not included in this repository.

## Sources and inspiration

- Data: [OpenStreetMap contributors](https://www.openstreetmap.org/copyright).
- Tutorial: [Visualizing Road Networks by Milan Janosov](https://milanjanosov.substack.com/p/milans-data-stories-016-visualizing).

## Notes

OpenStreetMap coverage may be incomplete. The network is retrieved
using `network_type="all"` and does not imply access for all
transport modes.

All streets use the same color and do not represent traffic levels,
travel times or road classifications. Some segments may extend
slightly beyond the municipal boundary.

Both layers are projected to EPSG:32632. The scale bar uses meters,
and the north arrow indicates grid north.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/) ·
[Back to the challenge](../README.md)
