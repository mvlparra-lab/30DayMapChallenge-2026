# Augsburg through its streets
## Day 02 - Lines · #30DayMapChallenge 2026

A portrait of Augsburg through its OpenStreetMap roads, pedestrian
routes, paths and trails, created with Python and OSMnx.

**Map by Maria Victoria León Parra**

## Final map

![Augsburg through its streets](output/day02_lines_augsburg.png)

## Tools

Python · OSMnx · GeoPandas · Matplotlib

## How to run

1. Install the required packages:

   pip install osmnx matplotlib jupyter

2. Open `day02_lines_augsburg.ipynb`.
3. Run the cells in order.

No local input files are required for the first run.
The street network and municipal boundary are downloaded from
OpenStreetMap. An internet connection is required.

The notebook creates `data/` and `output/` directories.
The street network is cached locally as
`data/augsburg_all_streets.graphml`.

## Sources and limitations

- Street network and municipal boundary:
  © OpenStreetMap contributors, ODbL.
  https://www.openstreetmap.org/copyright
- Workflow inspiration:
  Milan Janosov's Visualizing Road Networks tutorial.
  https://milanjanosov.substack.com/p/milans-data-stories-016-visualizing

OpenStreetMap coverage may be incomplete. The network uses
`network_type="all"` and does not imply access for all transport modes.

All streets use the same color. They do not represent traffic levels,
travel times or road classifications. Some segments may extend
slightly beyond the municipal boundary.

Both layers are projected to EPSG:32632. The scale bar uses meters,
and the north arrow indicates grid north.

Local environments, cached data and IDE configuration files
are excluded from this repository.
